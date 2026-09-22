import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/colors.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/core/theme/spacing.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_completed_today_card.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_rest_day_card.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_today_session_panel.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/performance/services/previous_strength_performance_service.dart';
import 'package:cohort_platform/features/performance/widgets/completed_session_result_view.dart';
import 'package:cohort_platform/features/performance/widgets/session_completion_pending_panel.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/presentation/daily_journey_integrity_preview_catalog.dart';
import 'package:cohort_platform/features/session/presentation/production_restore_athlete_copy.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/features/session/screens/block_timer_screen.dart';
import 'package:cohort_platform/features/session/screens/production_restore_blocked_screen.dart';
import 'package:cohort_platform/features/session/services/circuit_block_timer_bridge.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:flutter/material.dart';

/// Internal Daily Journey Integrity preview. Fixtures only. Not imported by
/// `lib/main.dart`.
///
///   flutter run -d chrome --web-port 4191 \
///     -t lib/main_daily_journey_integrity_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const DailyJourneyIntegrityPreviewApp(
      initialState: DailyJourneyIntegrityPreviewState.noDraft,
      accessibilityReview: true,
    ),
  );
}

class DailyJourneyIntegrityPreviewApp extends StatelessWidget {
  const DailyJourneyIntegrityPreviewApp({
    super.key,
    this.initialState = DailyJourneyIntegrityPreviewState.noDraft,
    this.accessibilityReview = false,
  });

  final DailyJourneyIntegrityPreviewState initialState;
  final bool accessibilityReview;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: DailyJourneyIntegrityPreviewScreen(
        initialState: initialState,
        accessibilityReview: accessibilityReview,
      ),
    );
  }
}

class DailyJourneyIntegrityPreviewScreen extends StatefulWidget {
  const DailyJourneyIntegrityPreviewScreen({
    super.key,
    this.initialState = DailyJourneyIntegrityPreviewState.noDraft,
    this.accessibilityReview = false,
  });

  final DailyJourneyIntegrityPreviewState initialState;
  final bool accessibilityReview;

  @override
  State<DailyJourneyIntegrityPreviewScreen> createState() =>
      _DailyJourneyIntegrityPreviewScreenState();
}

class _DailyJourneyIntegrityPreviewScreenState
    extends State<DailyJourneyIntegrityPreviewScreen> {
  final _scenarios = dailyJourneyIntegrityPreviewScenarios();
  late DailyJourneyIntegrityPreviewScenario _scenario;
  var _a11yReview = false;
  var _previewWidth = 390.0;
  var _textScale = 1.0;
  var _reduceMotion = false;
  var _semanticsDebug = false;

  @override
  void initState() {
    super.initState();
    _a11yReview = widget.accessibilityReview;
    _scenario = _scenarios.firstWhere(
      (item) => item.state == widget.initialState,
    );
  }

  @override
  Widget build(BuildContext context) {
    _scenario.assertConsistent();
    final decision = _scenario.decision();
    return Scaffold(
      backgroundColor: CohortColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _previewWidth),
            child: Column(
              children: [
                Material(
                  color: const Color(0xFF5C4033),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREVIEW ONLY',
                          style: CohortTextStyles.eyebrow.copyWith(
                            color: Colors.white,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          'Local fixtures. No hosted data. Not production.',
                          style: CohortTextStyles.body.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButton<DailyJourneyIntegrityPreviewState>(
                          key: const ValueKey('preview-state-selector'),
                          isExpanded: true,
                          dropdownColor: const Color(0xFF3E2A22),
                          value: _scenario.state,
                          items: [
                            for (final scenario in _scenarios)
                              DropdownMenuItem(
                                value: scenario.state,
                                child: Text(
                                  scenario.label,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _scenario = _scenarios.firstWhere(
                                (item) => item.state == value,
                              );
                            });
                          },
                        ),
                        Text(
                          'Preview resolver: ${decision.outcome.name}',
                          key: const ValueKey('preview-resolver-outcome'),
                          style: CohortTextStyles.eyebrow.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        SwitchListTile(
                          key: const ValueKey('preview-a11y-review'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Accessibility review',
                            style: CohortTextStyles.small.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          value: _a11yReview,
                          onChanged: (value) =>
                              setState(() => _a11yReview = value),
                        ),
                        if (_a11yReview) ...[
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final width in [320.0, 390.0])
                                ChoiceChip(
                                  key: ValueKey('preview-width-$width'),
                                  label: Text('${width.toInt()}px'),
                                  selected: _previewWidth == width,
                                  onSelected: (_) =>
                                      setState(() => _previewWidth = width),
                                ),
                              for (final scale in [1.0, 1.3, 1.6, 2.0])
                                ChoiceChip(
                                  key: ValueKey('preview-scale-$scale'),
                                  label: Text('$scale×'),
                                  selected: _textScale == scale,
                                  onSelected: (_) =>
                                      setState(() => _textScale = scale),
                                ),
                            ],
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Reduced motion',
                              style: CohortTextStyles.small.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            value: _reduceMotion,
                            onChanged: (value) =>
                                setState(() => _reduceMotion = value),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Semantics debugger',
                              style: CohortTextStyles.small.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            value: _semanticsDebug,
                            onChanged: (value) =>
                                setState(() => _semanticsDebug = value),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(
                        _a11yReview ? _textScale : 1.0,
                      ),
                      disableAnimations: _a11yReview && _reduceMotion,
                      size: Size(
                        _previewWidth,
                        MediaQuery.sizeOf(context).height,
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        Widget body = KeyedSubtree(
                          key: ValueKey(_scenario.state),
                          child: _bodyFor(_scenario, decision),
                        );
                        if (_a11yReview && _semanticsDebug) {
                          body = SemanticsDebugger(child: body);
                        }
                        return body;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bodyFor(
    DailyJourneyIntegrityPreviewScenario scenario,
    dynamic decision,
  ) {
    return switch (scenario.kind) {
      DailyJourneyIntegrityPreviewKind.homeBegin ||
      DailyJourneyIntegrityPreviewKind.homeResume => _HomePreview(
        scenario: scenario,
      ),
      DailyJourneyIntegrityPreviewKind.activeSession => _ActivePreview(
        key: ValueKey(scenario.state),
        scenario: scenario,
      ),
      DailyJourneyIntegrityPreviewKind.blocked => ProductionRestoreBlockedScreen(
        decision: decision,
        unsafeLegacy: scenario.unsafeLegacy,
        onReturnHome: () => _select(DailyJourneyIntegrityPreviewState.noDraft),
        onOpenCalendar: scenario.expectedOutcome ==
                    ProductionRestoreOutcome.staleOccurrence ||
                scenario.expectedOutcome ==
                    ProductionRestoreOutcome.staleProgrammeVersion
            ? () => _select(DailyJourneyIntegrityPreviewState.noDraft)
            : null,
        onSwitchAccount: scenario.expectedOutcome ==
                ProductionRestoreOutcome.foreignAthlete
            ? () => _select(DailyJourneyIntegrityPreviewState.noDraft)
            : null,
        onContinueSafely:
            scenario.expectedOutcome ==
                ProductionRestoreOutcome.legacyPartiallyRecoverable
            ? () => _openRestoredSession(scenario)
            : null,
        onDiscardDraft: () async {
          _select(DailyJourneyIntegrityPreviewState.noDraft);
        },
      ),
      DailyJourneyIntegrityPreviewKind.completionPending => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SessionCompletionPendingPanel(
            idempotencyKey: previewCompletionIdempotencyKey,
            onRetry: () => _select(
              DailyJourneyIntegrityPreviewState.completionReconciled,
            ),
            onReturnToSession: () => _openRestoredSession(scenario),
          ),
        ],
      ),
      DailyJourneyIntegrityPreviewKind.completionReconciled =>
        _ReconciledCompletionPreview(scenario: scenario),
      DailyJourneyIntegrityPreviewKind.restDay => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('TODAY', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: 4),
          Text('Sunday 20 September', style: CohortTextStyles.muted),
          const SizedBox(height: 12),
          AthleteHomeRestDayCard(
            programmeName: 'Preview programme',
            dateLabel: 'Sunday 20 September',
            guidance:
                'Walk if you want. Keep food and sleep regular. No workout to begin.',
            nextSessionHint: 'Next: Strength · tomorrow',
            onOpenCalendar: () {},
          ),
        ],
      ),
      DailyJourneyIntegrityPreviewKind.discardConfirm => _DiscardConfirmPreview(
        decision: decision,
        onReturnHome: () => _select(DailyJourneyIntegrityPreviewState.noDraft),
      ),
    };
  }

  void _select(DailyJourneyIntegrityPreviewState state) {
    setState(() {
      _scenario = _scenarios.firstWhere((item) => item.state == state);
    });
  }

  void _openRestoredSession(DailyJourneyIntegrityPreviewScenario scenario) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: _ActivePreview(
            scenario: DailyJourneyIntegrityPreviewScenario(
              state: DailyJourneyIntegrityPreviewState.strengthResume,
              label: scenario.label,
              expectedOutcome: ProductionRestoreOutcome.resumable,
              kind: DailyJourneyIntegrityPreviewKind.activeSession,
              plan: scenario.plan,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReconciledCompletionPreview extends StatelessWidget {
  const _ReconciledCompletionPreview({required this.scenario});

  final DailyJourneyIntegrityPreviewScenario scenario;

  @override
  Widget build(BuildContext context) {
    final record = previewCommittedStrengthRecord();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(
          liveRegion: true,
          label: ProductionRestoreAthleteCopy.completionReconciledTitle,
          child: Text(
            ProductionRestoreAthleteCopy.completionReconciledTitle,
            style: CohortTextStyles.body,
          ),
        ),
        const SizedBox(height: CohortSpacing.sm),
        Text(
          ProductionRestoreAthleteCopy.completionReconciledBody,
          style: CohortTextStyles.small,
        ),
        const SizedBox(height: CohortSpacing.md),
        AthleteHomeCompletedTodayCard(
          occurrence: previewCompletedOccurrence(),
          dateLabel: 'Sunday 20 September',
          programmeName: 'Preview programme',
          weekDayLabel: scenario.plan.programmeContextLabel ?? 'Week 1 · Day 1',
          record: record,
          onViewResults: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: const Text('Results')),
                  body: CompletedSessionResultView(
                    record: record,
                    programmePosition: scenario.plan.programmeContextLabel,
                    statusMessage:
                        ProductionRestoreAthleteCopy.completionReconciledTitle,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HomePreview extends StatelessWidget {
  const _HomePreview({required this.scenario});

  final DailyJourneyIntegrityPreviewScenario scenario;

  @override
  Widget build(BuildContext context) {
    final begin = scenario.kind == DailyJourneyIntegrityPreviewKind.homeBegin;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AthleteHomeTodaySessionPanel(
          package: previewPackage(scenario.plan),
          primaryLabel: begin ? 'Begin' : 'Resume',
          status: begin ? 'Not started' : 'In progress',
          dateLabel: 'Sunday 20 September',
          programmeName: 'Preview programme',
          weekDayLabel: scenario.plan.programmeContextLabel,
          onPrimary: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: _ActivePreview(scenario: scenario),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ActivePreview extends StatelessWidget {
  const _ActivePreview({super.key, required this.scenario});

  final DailyJourneyIntegrityPreviewScenario scenario;

  @override
  Widget build(BuildContext context) {
    final plan = scenario.plan;
    final execution = SessionExecutionController(
      plan: plan,
      sessionKey: 'preview:${plan.sessionId}',
    )..startSession();
    final performance = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: previewAthleteId,
      trainingSessionId: 4,
    );
    applyPreviewActuals(
      state: scenario.state,
      performance: performance,
      plan: plan,
    );
    execution.restoreFromDurableDraft(
      completedBlockIds: const {},
      activeBlockId: plan.blocks.isEmpty ? null : plan.blocks.first.blockId,
      expandedBlockIds: plan.blocks.isEmpty
          ? const {}
          : {plan.blocks.first.blockId},
    );
    final session = ActiveSessionScreen(
      key: ValueKey('session-${plan.sessionId}'),
      controller: execution,
      performanceController: performance,
      athleteId: previewAthleteId,
      trainingSessionId: 4,
      previousStrengthService: PreviousStrengthPerformanceService(
        store: const EmptyPreviousStrengthPerformanceStore(),
      ),
      saveCoordinator: PerformanceRecordSaveCoordinator(
        store: InMemoryPerformanceRecordStore(),
      ),
    );
    if (!scenario.openRestoredTimer || plan.blocks.isEmpty) {
      return session;
    }
    final block = plan.blocks.first;
    final labels = {
      for (final exercise in block.linkedExercises)
        exercise.exerciseId: exercise.displayName,
    };
    final result = performance.draft.blockDrafts.first.resultData;
    return Navigator(
      pages: [
        MaterialPage<void>(child: session),
        MaterialPage<void>(
          child: BlockTimerScreen(
            blockTitle: plan.sessionTitle,
            format: block.workoutFormat,
            configuration: block.timerConfiguration!,
            prescriptionLines: block.content
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .toList(),
            restoredWorkNote: result is ForTimeResultData
                ? result.remainingWorkNote
                : null,
            initialState: scenario.restoredTimerOverride ??
                CircuitBlockTimerBridge.restoredState(
                  block: block,
                  result: result,
                  stationLabels: labels,
                ),
          ),
        ),
      ],
      onDidRemovePage: (_) {},
    );
  }
}

class _DiscardConfirmPreview extends StatefulWidget {
  const _DiscardConfirmPreview({
    required this.decision,
    required this.onReturnHome,
  });

  final ProductionRestoreDecision decision;
  final VoidCallback onReturnHome;

  @override
  State<_DiscardConfirmPreview> createState() => _DiscardConfirmPreviewState();
}

class _DiscardConfirmPreviewState extends State<_DiscardConfirmPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<bool>(
        context: context,
        builder: (_) => const ProductionRestoreDiscardDialog(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProductionRestoreBlockedScreen(
      decision: widget.decision,
      unsafeLegacy: true,
      onReturnHome: widget.onReturnHome,
      onDiscardDraft: () async {},
    );
  }
}
