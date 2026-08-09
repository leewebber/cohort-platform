import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../adaptive_progression/models/capability_timeline.dart';
import '../../athlete_profile/services/athlete_profile_session.dart';
import '../../auth/services/current_user_session.dart';
import '../models/progress_summary.dart';
import '../services/athlete_progress_summary_builder.dart';
import '../services/capability_radar_projection_service.dart';
import '../services/progress_summary_service.dart';
import '../widgets/capability_radar_chart.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({
    super.key,
    this.summary,
    this.summaryService = const ProgressSummaryService(),
    this.progressBuilder,
    this.radarService = const CapabilityRadarProjectionService(),
    this.embeddedInShell = false,
    this.athleteIdOverride,
    this.onChoosePlan,
    this.onStartToday,
  });

  /// Sync override for tests / precomputed summaries.
  final ProgressSummary? summary;

  /// Legacy Plan Library summary service (pure-legacy compatibility only).
  final ProgressSummaryService summaryService;

  /// Canonical authority-aware builder (Phase 2.7). When null and [summary] is
  /// null, a default builder is constructed.
  final AthleteProgressSummaryBuilder? progressBuilder;

  final CapabilityRadarProjectionService radarService;
  final bool embeddedInShell;
  final String? athleteIdOverride;
  final VoidCallback? onChoosePlan;
  final VoidCallback? onStartToday;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  ProgressSummary? _resolved;
  bool _loading = false;

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
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ProgressScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.summary != oldWidget.summary) {
      _bootstrap();
    }
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
    final builder = widget.progressBuilder ??
        AthleteProgressSummaryBuilder(
          legacySummaryService: widget.summaryService,
        );
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

  @override
  Widget build(BuildContext context) {
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
        body: const SafeArea(
          child: Center(
            child: Text('Loading progress…', style: CohortTextStyles.muted),
          ),
        ),
      );
    }

    final resolved = _resolved!;
    final radar = widget.radarService.project(
      timeline: resolved.timeline,
      compliance: resolved.compliance,
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
        child: resolved.hasActivePlan && resolved.sessionsCompleted > 0
            ? _ProgressBody(
                summary: resolved,
                radar: radar,
                metrics: metrics,
              )
            : _EmptyProgress(
                radar: radar,
                hasPlan: resolved.hasActivePlan,
                onChoosePlan: widget.onChoosePlan,
                onStartToday: widget.onStartToday,
              ),
      ),
    );
  }
}

class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress({
    required this.radar,
    required this.hasPlan,
    this.onChoosePlan,
    this.onStartToday,
  });

  final CapabilityRadarModel radar;
  final bool hasPlan;
  final VoidCallback? onChoosePlan;
  final VoidCallback? onStartToday;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CohortSpacing.xl,
        CohortSpacing.md,
        CohortSpacing.xl,
        CohortSpacing.xxl,
      ),
      children: [
        Text('PROGRESS', style: CohortTextStyles.eyebrow),
        const SizedBox(height: CohortSpacing.md),
        Text('Am I getting better?', style: CohortTextStyles.h1),
        const SizedBox(height: CohortSpacing.md),
        Text(
          'Complete your first sessions and Cohort will begin building '
          'your capability profile.',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: CohortSpacing.xl),
        if (hasPlan)
          CohortButton(
            label: "START TODAY'S TRAINING",
            showTrailingArrow: true,
            onPressed: onStartToday ?? () {},
          )
        else
          CohortButton(
            label: 'CHOOSE A PLAN',
            showTrailingArrow: true,
            onPressed: onChoosePlan ?? () {},
          ),
        const SizedBox(height: CohortSpacing.xl),
        Text('CAPABILITY OVERVIEW', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.md),
        Center(child: CapabilityRadarChart(model: radar)),
        const SizedBox(height: CohortSpacing.xl),
        const _PlaceholderModule(title: 'Lower Body Strength'),
        const _PlaceholderModule(title: 'Threshold Pace'),
        const _PlaceholderModule(title: 'Training Discipline'),
        const _PlaceholderModule(title: 'Current Plan Progress'),
      ],
    );
  }
}

class _PlaceholderModule extends StatelessWidget {
  const _PlaceholderModule({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(CohortSpacing.lg),
        decoration: BoxDecoration(
          color: CohortColors.surfaceRaised.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CohortColors.border.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: CohortTextStyles.cardTitle),
            const SizedBox(height: 4),
            Text(
              'Awaiting evidence',
              style: CohortTextStyles.small.copyWith(
                color: CohortColors.textMuted,
              ),
            ),
          ],
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
  });

  final ProgressSummary summary;
  final CapabilityRadarModel radar;
  final List<ProgressMetricCardModel> metrics;

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
          Text('PROGRESS', style: CohortTextStyles.eyebrow),
          const SizedBox(height: CohortSpacing.md),
          Text('Am I getting better?', style: CohortTextStyles.h1),
          const SizedBox(height: CohortSpacing.sm),
          Text(
            'Capability development, recent improvements, and plan progress.',
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.xl),
          _Section(
            title: 'Capability Overview',
            child: Center(child: CapabilityRadarChart(model: radar)),
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
          _Section(
            title: 'Recent Improvements',
            child: summary.recentImprovements.isEmpty
                ? Text(
                    'Complete a session to see your first improvements.',
                    style: CohortTextStyles.body,
                  )
                : Column(
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
            title: 'Current Plan Progress',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.planName ?? 'Plan', style: CohortTextStyles.h2),
                const SizedBox(height: CohortSpacing.xs),
                Text(
                  '${summary.phaseLabel ?? '—'} · ${summary.weekLabel ?? '—'}',
                  style: CohortTextStyles.body,
                ),
                const SizedBox(height: CohortSpacing.md),
                Text(
                  '${summary.sessionsCompleted} sessions completed',
                  style: CohortTextStyles.small,
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
            title: 'Discipline',
            child: Text(
              '${summary.compliance.completed} of ${summary.compliance.planned} '
              'planned sessions · ${summary.compliance.percentage}% · '
              'streak ${summary.compliance.currentStreak} days',
              style: CohortTextStyles.body,
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
