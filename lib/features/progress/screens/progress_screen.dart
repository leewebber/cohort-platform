import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_brand_lockup.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../adaptive_progression/models/capability_timeline.dart';
import '../../app_shell/presentation/athlete_time_aware_greeting.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../auth/services/current_user_session.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../models/progress_summary.dart';
import '../services/athlete_progress_summary_builder.dart';
import '../services/capability_radar_projection_service.dart';
import '../widgets/capability_radar_chart.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    this.summary,
    this.progressBuilder,
    this.radarService = const CapabilityRadarProjectionService(),
    this.embeddedInShell = false,
    this.athleteIdOverride,
    this.onChoosePlan,
    this.onStartToday,
  });

  /// Sync override for tests / precomputed summaries.
  final ProgressSummary? summary;

  /// Canonical authority-aware builder (Phase 2.7 / 2.8). When null and
  /// [summary] is null, a default builder is constructed.
  final AthleteProgressSummaryBuilder? progressBuilder;

  final CapabilityRadarProjectionService radarService;
  final bool embeddedInShell;
  final String? athleteIdOverride;
  final VoidCallback? onChoosePlan;
  final VoidCallback? onStartToday;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with WidgetsBindingObserver {
  ProgressSummary? _resolved;
  bool _loading = false;
  HomeTodaySessionRefreshController? _attachedController;

  String get _athleteId {
    final override = widget.athleteIdOverride?.trim();
    if (override != null && override.isNotEmpty) return override;
    return AthleteProfileSession.profile?.athleteId ??
        CurrentUserSession.maybeInstance?.athleteId ??
        'athlete.local';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attachSurfaceReload();
  }

  @override
  void dispose() {
    _detachSurfaceReload();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _bootstrap();
    }
  }

  @override
  void didUpdateWidget(covariant ProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.summary != oldWidget.summary ||
        widget.progressBuilder != oldWidget.progressBuilder) {
      _bootstrap();
    }
  }

  void _attachSurfaceReload() {
    final controller = AthleteProgrammeSurfaceRefreshScope.maybeOf(context);
    if (identical(_attachedController, controller)) return;
    _attachedController?.detachSurface(this);
    _attachedController = controller;
    controller?.attachSurface(this, ({required source}) async {
      await _bootstrap();
    });
  }

  void _detachSurfaceReload() {
    _attachedController?.detachSurface(this);
    _attachedController = null;
  }

  Future<void> _bootstrap() async {
    final injected = widget.summary;
    if (injected != null) {
      setState(() {
        _resolved = injected;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    final builder = widget.progressBuilder ?? AthleteProgressSummaryBuilder();
    try {
      final summary = await builder.build(athleteId: _athleteId);
      if (!mounted) return;
      setState(() {
        _resolved = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _resolved = AthleteProgressSummaryBuilder.emptySummary();
        _loading = false;
      });
    }
  }

  void _invalidateIfLocalDateMoved() {
    if (widget.summary != null) return;
    final compliance = _resolved?.compliance;
    final asOf = compliance?.asOfDate;
    final timezone = compliance?.timezone;
    if (asOf == null || asOf.isEmpty) return;
    final today = AthleteIanaClock.dateOnly(timezone);
    if (today == asOf) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    _invalidateIfLocalDateMoved();
    if (_loading || _resolved == null) {
      return Scaffold(
        backgroundColor: CohortColors.background,
        appBar: widget.embeddedInShell
            ? null
            : AppBar(
                backgroundColor: CohortColors.background,
                elevation: 0,
                title: const Text('PROGRESS', style: CohortTextStyles.eyebrow),
                centerTitle: false,
              ),
        body: SafeArea(
          child: _ProgressBody(
            summary: AthleteProgressSummaryBuilder.emptySummary(),
            radar: CapabilityRadarModel.emptyScaffold,
            metrics: const [],
            loading: true,
          ),
        ),
      );
    }

    final resolved = _resolved!;
    final radar = widget.radarService.project(
      timeline: resolved.timeline,
      compliance: resolved.compliance,
      strengthSessionCount: resolved.strengthSessionCount,
      enduranceSessionCount: resolved.enduranceSessionCount,
    );
    final metrics = widget.radarService.metricCards(
      timeline: resolved.timeline,
      compliance: resolved.compliance,
    );

    return Scaffold(
      backgroundColor: CohortColors.background,
      appBar: widget.embeddedInShell
          ? null
          : AppBar(
              backgroundColor: CohortColors.background,
              elevation: 0,
              title: const Text('PROGRESS', style: CohortTextStyles.eyebrow),
              centerTitle: false,
            ),
      body: SafeArea(
        child: _ProgressBody(
          summary: resolved,
          radar: radar,
          metrics: metrics,
          onChoosePlan: widget.onChoosePlan,
          onStartToday: widget.onStartToday,
        ),
      ),
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({
    required this.summary,
    required this.radar,
    required this.metrics,
    this.onChoosePlan,
    this.onStartToday,
    this.loading = false,
  });

  final ProgressSummary summary;
  final CapabilityRadarModel radar;
  final List<ProgressMetricCardModel> metrics;
  final VoidCallback? onChoosePlan;
  final VoidCallback? onStartToday;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        CohortSpacing.xl,
        CohortSpacing.md,
        CohortSpacing.xl,
        CohortSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CohortBrandLockup(),
          const SizedBox(height: CohortSpacing.md),
          Text('PROGRESS', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.md),
          Text('Am I getting better?', style: CohortTextStyles.h1),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            loading
                ? 'Loading recorded sessions…'
                : summary.sessionsCompleted == 0
                ? 'Complete your first session to begin'
                : 'Recorded sessions and exercise bests from completed work.',
            style: CohortTextStyles.body,
          ),
          if (!summary.hasActivePlan) ...[
            const SizedBox(height: CohortSpacing.lg),
            CohortButton(
              label: 'CHOOSE A PLAN',
              showTrailingArrow: true,
              onPressed: onChoosePlan ?? () {},
            ),
          ],
          if (summary.hasActivePlan &&
              summary.sessionsCompleted == 0 &&
              onStartToday != null) ...[
            const SizedBox(height: CohortSpacing.lg),
            CohortButton(
              label: "START TODAY'S TRAINING",
              showTrailingArrow: true,
              onPressed: onStartToday,
            ),
          ],
          const SizedBox(height: CohortSpacing.xl),
          _Section(
            title: 'Capability Overview',
            child: Center(child: CapabilityRadarChart(model: radar)),
          ),
          _Section(
            title: 'Sessions completed',
            child: Text(
              '${summary.sessionsCompleted} sessions completed',
              style: CohortTextStyles.h2,
            ),
          ),
          _Section(
            title: 'Programme consistency so far',
            child: Semantics(
              container: true,
              label: summary.compliance.semanticLabel,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.compliance.athleteHeadline,
                      style: CohortTextStyles.body,
                    ),
                    if (summary.compliance.hasScore) ...[
                      const SizedBox(height: CohortSpacing.xs),
                      Text(
                        summary.compliance.supportingLabel,
                        style: CohortTextStyles.small,
                      ),
                    ],
                    if (summary.compliance.partialCompletedCount > 0) ...[
                      const SizedBox(height: CohortSpacing.xs),
                      Text(
                        '${summary.compliance.partialCompletedCount} '
                        'partially completed (counted as complete)',
                        style: CohortTextStyles.small,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _Section(
            title: 'Exercise performances',
            child: summary.exerciseBests.isEmpty
                ? const Text('Awaiting evidence', style: CohortTextStyles.body)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final best in summary.exerciseBests) ...[
                        Text(
                          best.displayName,
                          style: CohortTextStyles.cardTitle,
                        ),
                        Text(best.bestSetLabel, style: CohortTextStyles.h2),
                        Text(
                          best.comparisonLabel,
                          style: CohortTextStyles.small,
                        ),
                        if (best.personalBestLabel != null)
                          Text(
                            best.personalBestLabel!,
                            style: CohortTextStyles.small,
                          ),
                        const SizedBox(height: CohortSpacing.md),
                      ],
                    ],
                  ),
          ),
          if (metrics.isNotEmpty)
            _Section(
              title: 'Evidence',
              child: Column(
                children: [
                  for (final card in metrics) _EvidenceCard(card: card),
                ],
              ),
            ),
          if (summary.recentImprovements.isNotEmpty)
            _Section(
              title: 'Recent improvements',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final line in summary.recentImprovements) ...[
                    Text(line, style: CohortTextStyles.cardTitle),
                    const SizedBox(height: CohortSpacing.sm),
                  ],
                ],
              ),
            ),
          _Section(
            title: 'Recent notable performances',
            child: summary.exerciseBests.isEmpty
                ? const Text(
                    'Complete your first session to begin',
                    style: CohortTextStyles.body,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final best in summary.exerciseBests)
                        if (best.comparisonImproved ||
                            best.isFirstRecorded) ...[
                          Text(
                            best.displayName,
                            style: CohortTextStyles.cardTitle,
                          ),
                          Text(
                            best.comparisonLabel,
                            style: CohortTextStyles.small,
                          ),
                          const SizedBox(height: CohortSpacing.sm),
                        ],
                    ],
                  ),
          ),
          _Section(
            title: 'Current programme',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.planName ?? 'No active programme',
                  style: CohortTextStyles.h2,
                ),
                const SizedBox(height: CohortSpacing.xs),
                Text(
                  '${summary.phaseLabel ?? '—'} · ${summary.weekLabel ?? '—'}',
                  style: CohortTextStyles.body,
                ),
              ],
            ),
          ),
          if (summary.upcoming != null)
            _Section(
              title: 'Assessments',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Line(
                    label: 'Next',
                    value: summary.upcoming!.nextAssessmentLabel,
                  ),
                  _Line(
                    label: 'Milestone',
                    value: summary.upcoming!.nextMilestoneLabel,
                  ),
                ],
              ),
            ),
          _Section(
            title: 'Training Discipline',
            child: Semantics(
              container: true,
              label: summary.compliance.semanticLabel,
              child: ExcludeSemantics(
                child: Text(
                  summary.compliance.hasScore
                      ? '${summary.compliance.percentage}% · '
                            '${summary.compliance.supportingLabel}'
                      : summary.compliance.athleteHeadline,
                  style: CohortTextStyles.body,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidenceCard extends StatelessWidget {
  const _EvidenceCard({required this.card});

  final ProgressMetricCardModel card;

  @override
  Widget build(BuildContext context) {
    final direction = switch (card.direction) {
      CapabilityChangeDirection.up => '↑',
      CapabilityChangeDirection.down => '↓',
      CapabilityChangeDirection.steady => '→',
      null => null,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(CohortSpacing.lg),
        decoration: BoxDecoration(
          color: CohortColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CohortColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title, style: CohortTextStyles.cardTitle),
            const SizedBox(height: CohortSpacing.sm),
            Row(
              children: [
                Text('Current', style: CohortTextStyles.small),
                const SizedBox(width: 8),
                Text(card.currentLabel, style: CohortTextStyles.h2),
                if (direction != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    direction,
                    style: CohortTextStyles.cardTitle.copyWith(
                      color: CohortColors.phosphor,
                    ),
                  ),
                ],
              ],
            ),
            if (card.previousLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                'Previous ${card.previousLabel}',
                style: CohortTextStyles.small,
              ),
            ],
            if (card.lastUpdated != null) ...[
              const SizedBox(height: 4),
              Text(
                'Updated ${_formatDate(card.lastUpdated!)}',
                style: CohortTextStyles.small.copyWith(
                  color: CohortColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: CohortTextStyles.small),
          ),
          Expanded(child: Text(value, style: CohortTextStyles.body)),
        ],
      ),
    );
  }
}
