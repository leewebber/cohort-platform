import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/colors.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_rest_day_card.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_today_session_panel.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/performance/services/previous_strength_performance_service.dart';
import 'package:cohort_platform/features/performance/widgets/session_completion_pending_panel.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/presentation/daily_journey_integrity_preview_catalog.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/features/session/screens/block_timer_screen.dart';
import 'package:cohort_platform/features/session/screens/production_restore_blocked_screen.dart';
import 'package:cohort_platform/features/session/services/circuit_block_timer_bridge.dart';
import 'package:flutter/material.dart';

/// Internal Daily Journey Integrity preview. Fixtures only. Not imported by
/// `lib/main.dart`.
///
///   flutter run -d chrome --web-port 4191 \
///     -t lib/main_daily_journey_integrity_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyJourneyIntegrityPreviewApp());
}

class DailyJourneyIntegrityPreviewApp extends StatelessWidget {
  const DailyJourneyIntegrityPreviewApp({
    super.key,
    this.initialState = DailyJourneyIntegrityPreviewState.noDraft,
  });

  final DailyJourneyIntegrityPreviewState initialState;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: DailyJourneyIntegrityPreviewScreen(initialState: initialState),
    );
  }
}

class DailyJourneyIntegrityPreviewScreen extends StatefulWidget {
  const DailyJourneyIntegrityPreviewScreen({
    super.key,
    this.initialState = DailyJourneyIntegrityPreviewState.noDraft,
  });

  final DailyJourneyIntegrityPreviewState initialState;

  @override
  State<DailyJourneyIntegrityPreviewScreen> createState() =>
      _DailyJourneyIntegrityPreviewScreenState();
}

class _DailyJourneyIntegrityPreviewScreenState
    extends State<DailyJourneyIntegrityPreviewScreen> {
  final _scenarios = dailyJourneyIntegrityPreviewScenarios();
  late DailyJourneyIntegrityPreviewScenario _scenario;

  @override
  void initState() {
    super.initState();
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
            constraints: const BoxConstraints(maxWidth: 390),
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
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: KeyedSubtree(
                    key: ValueKey(_scenario.state),
                    child: _bodyFor(_scenario, decision),
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
            idempotencyKey: 'finish-4-preview-frozen',
            onRetry: () {},
            onReturnToSession: () => _openRestoredSession(scenario),
          ),
        ],
      ),
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
