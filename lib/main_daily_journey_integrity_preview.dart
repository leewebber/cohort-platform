import 'package:cohort_platform/app/theme.dart';
import 'package:cohort_platform/core/theme/colors.dart';
import 'package:cohort_platform/core/theme/text_styles.dart';
import 'package:cohort_platform/core/widgets/cohort_button.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_today_session_panel.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/circuit_station_actual.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/production_session_draft.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/features/session/services/production_recovery_session_policy.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:cohort_platform/features/session/services/workout_progress_snapshot_policy.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/core/persistence/models/execution_result_models.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';

/// Internal Daily Journey Integrity preview. Fixtures only. Not imported by
/// `lib/main.dart`.
///
///   flutter run -t lib/main_daily_journey_integrity_preview.dart
///
/// Chrome (optional):
///   flutter run -d chrome --web-port 4191 -t lib/main_daily_journey_integrity_preview.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyJourneyIntegrityPreviewApp());
}

enum _PreviewState {
  noDraft,
  resumeDraft,
  strengthResume,
  emomResume,
  amrapResume,
  legacyPartial,
  unsafeLegacy,
  staleOccurrence,
  staleVersion,
  foreignAthlete,
  corruptDraft,
  completionPending,
  structuredRecovery,
  guidanceRest,
}

const _previewLabels = {
  _PreviewState.noDraft: '1 No draft — Begin session',
  _PreviewState.resumeDraft: '2 Valid durable draft — Resume',
  _PreviewState.strengthResume: '3 Resumed strength at exercise/set',
  _PreviewState.emomResume: '4 Resumed interval/EMOM timer',
  _PreviewState.amrapResume: '5 Resumed circuit/for-time/AMRAP',
  _PreviewState.legacyPartial: '6 Legacy partially recoverable',
  _PreviewState.unsafeLegacy: '7 Unsafe legacy — cannot restore',
  _PreviewState.staleOccurrence: '8 Stale occurrence',
  _PreviewState.staleVersion: '9 Stale programme version',
  _PreviewState.foreignAthlete: '10 Foreign-athlete draft',
  _PreviewState.corruptDraft: '11 Corrupt or unsupported draft',
  _PreviewState.completionPending: '12 Completion pending / retry',
  _PreviewState.structuredRecovery: '13 Structured recovery session',
  _PreviewState.guidanceRest: '14 Guidance-only rest day',
};

class DailyJourneyIntegrityPreviewApp extends StatelessWidget {
  const DailyJourneyIntegrityPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: cohortTheme,
      home: const DailyJourneyIntegrityPreviewScreen(),
    );
  }
}

class DailyJourneyIntegrityPreviewScreen extends StatefulWidget {
  const DailyJourneyIntegrityPreviewScreen({super.key});

  @override
  State<DailyJourneyIntegrityPreviewScreen> createState() =>
      _DailyJourneyIntegrityPreviewScreenState();
}

class _DailyJourneyIntegrityPreviewScreenState
    extends State<DailyJourneyIntegrityPreviewScreen> {
  _PreviewState _state = _PreviewState.noDraft;

  @override
  Widget build(BuildContext context) {
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
                        DropdownButton<_PreviewState>(
                          isExpanded: true,
                          dropdownColor: const Color(0xFF3E2A22),
                          value: _state,
                          items: [
                            for (final entry in _previewLabels.entries)
                              DropdownMenuItem(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _state = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _bodyFor(_state)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bodyFor(_PreviewState state) {
    return switch (state) {
      _PreviewState.noDraft => _HomePreview(
        label: 'Begin',
        status: 'Not started',
        plan: _strengthPlan(),
      ),
      _PreviewState.resumeDraft => _HomePreview(
        label: 'Resume',
        status: 'In progress',
        plan: _strengthPlan(),
      ),
      _PreviewState.strengthResume => _ActivePreview(plan: _strengthPlan()),
      _PreviewState.emomResume => _ActivePreview(plan: _emomPlan(), emom: true),
      _PreviewState.amrapResume => _ActivePreview(plan: _amrapPlan(), amrap: true),
      _PreviewState.legacyPartial => _MessagePreview(
        title: 'Restoring your session',
        body:
            'Some older details can be recovered. Your captured results are kept. '
            'Position may start at the first incomplete movement.',
        outcome: _restoreOutcome(legacy: true),
      ),
      _PreviewState.unsafeLegacy => _MessagePreview(
        title: 'Draft cannot be safely restored',
        body:
            'An older in-progress snapshot cannot be opened as a workout. '
            'Use Home to begin or resume today’s session.',
        outcome: WorkoutProgressSnapshotPolicy()
            .bootAction(
              snapshot: WorkoutProgressSnapshot(
                sessionId: 'legacy',
                athleteId: 'preview-athlete',
                currentExerciseIndex: 0,
                currentSet: 1,
                completedExerciseIndexes: const [],
                startedAt: DateTime.utc(2026, 1, 1),
                lastUpdatedAt: DateTime.utc(2026, 1, 1),
                enteredResults: const [
                  {'reps': 5},
                ],
              ),
              currentAthleteId: 'preview-athlete',
            )
            .name,
      ),
      _PreviewState.staleOccurrence => _MessagePreview(
        title: 'Draft cannot be safely restored',
        body: 'This draft belongs to a different scheduled session.',
        outcome: _restoreOutcome(occurrenceId: 'other-occ'),
      ),
      _PreviewState.staleVersion => _MessagePreview(
        title: 'Draft cannot be safely restored',
        body: 'This draft was started on a previous programme version.',
        outcome: _restoreOutcome(programmeVersionId: 'old-version'),
      ),
      _PreviewState.foreignAthlete => _MessagePreview(
        title: 'Sign in required',
        body: 'This draft belongs to another athlete and cannot be opened.',
        outcome: _restoreOutcome(athleteId: 'other-athlete'),
      ),
      _PreviewState.corruptDraft => _MessagePreview(
        title: 'Draft cannot be safely restored',
        body: 'This draft is damaged or from a newer app version.',
        outcome: _restoreOutcome(corrupt: true),
      ),
      _PreviewState.completionPending => _PendingPreview(),
      _PreviewState.structuredRecovery => _HomePreview(
        label: 'Begin',
        status: 'Not started',
        plan: _recoveryPlan(),
      ),
      _PreviewState.guidanceRest => _RestPreview(),
    };
  }
}

String _restoreOutcome({
  bool legacy = false,
  bool corrupt = false,
  String athleteId = 'preview-athlete',
  String occurrenceId = 'preview-occ',
  String programmeVersionId = 'preview-version',
}) {
  const resolver = ProductionRestoreResolver();
  final decision = resolver.resolve(
    ProductionRestoreRequest(
      athleteId: 'preview-athlete',
      assignmentId: 'preview-assignment',
      programmeVersionId: programmeVersionId,
      programmedSessionKey: 'preview-key',
      packageContentHash: 'a' * 64,
      occurrenceId: occurrenceId,
      trainingSessionId: 1,
      jsonCorrupt: corrupt,
      persistedIdentity: ProductionSessionDraft(
        schemaVersion: legacy ? 0 : 1,
        athleteId: athleteId,
        assignmentId: 'preview-assignment',
        programmeVersionId: programmeVersionId,
        programmedSessionKey: 'preview-key',
        packageContentHash: 'a' * 64,
        trainingSessionId: legacy ? 0 : 1,
        entryMode: 'live',
        occurrenceId: occurrenceId,
      ),
    ),
  );
  return decision.outcome.name;
}

class _HomePreview extends StatelessWidget {
  const _HomePreview({
    required this.label,
    required this.status,
    required this.plan,
  });

  final String label;
  final String status;
  final SessionExecutionPlan plan;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AthleteHomeTodaySessionPanel(
          package: _package(plan),
          primaryLabel: label,
          status: status,
          dateLabel: 'Sunday 20 September',
          programmeName: 'Preview programme',
          weekDayLabel: 'Week 1 · Day 1',
          onPrimary: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text(plan.sessionTitle)),
                  body: _ActivePreview(plan: plan),
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
  const _ActivePreview({
    required this.plan,
    this.emom = false,
    this.amrap = false,
  });

  final SessionExecutionPlan plan;
  final bool emom;
  final bool amrap;

  @override
  Widget build(BuildContext context) {
    final execution = SessionExecutionController(
      plan: plan,
      sessionKey: 'preview:${plan.sessionId}',
    )..startSession();
    final performance = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'preview-athlete',
      trainingSessionId: 4,
    );
    if (emom) {
      performance.updateBlockResultData(
        plan.blocks.first.blockId,
        const CircuitResultData(
          format: 'emom',
          comparisonFamily: 'emom',
          stations: [],
          recordedCompletedRounds: 4,
          scoreEntered: true,
          timerCursor: CircuitTimerCursor(
            currentRound: 4,
            currentOrdinal: 4,
            remainingSeconds: 18,
            phase: 'work',
            isPaused: true,
          ),
        ),
      );
    }
    if (amrap) {
      performance.updateBlockResultData(
        plan.blocks.first.blockId,
        const AmrapResultData(rounds: 6, extraReps: 3, entered: true),
      );
    }
    if (plan.blocks.first.linkedExercises.isNotEmpty) {
      final exercise = performance.draft.blockDrafts.first.exerciseResults.first;
      if (exercise.sets.isNotEmpty) {
        performance.updateSet(
          plan.blocks.first.blockId,
          exercise.sourceExerciseId,
          exercise.sets.first.setResultId,
          (current) => current.copyWith(reps: 5, load: 60, completed: true),
        );
      }
    }
    execution.restoreFromDurableDraft(
      completedBlockIds: const {},
      activeBlockId: plan.blocks.first.blockId,
      expandedBlockIds: {plan.blocks.first.blockId},
    );
    return ActiveSessionScreen(
      controller: execution,
      performanceController: performance,
      athleteId: 'preview-athlete',
      trainingSessionId: 4,
      saveCoordinator: PerformanceRecordSaveCoordinator(
        store: InMemoryPerformanceRecordStore(),
      ),
    );
  }
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({
    required this.title,
    required this.body,
    required this.outcome,
  });

  final String title;
  final String body;
  final String outcome;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: CohortTextStyles.h2),
        const SizedBox(height: 8),
        Text(body, style: CohortTextStyles.body),
        const SizedBox(height: 16),
        Text(
          'Preview resolver: $outcome',
          style: CohortTextStyles.eyebrow,
        ),
      ],
    );
  }
}

class _PendingPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Completion pending', style: CohortTextStyles.h2),
        const SizedBox(height: 8),
        Text(
          'Your results are saved on this device. Cohort could not confirm '
          'the hosted record. Retry uses the same completion request.',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: 16),
        CohortButton(label: 'Retry', onPressed: () {}),
      ],
    );
  }
}

class _RestPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const recovery = ProductionRecoverySessionPolicy();
    const plan = SessionExecutionPlan(
      sessionId: 'rest',
      sessionTitle: 'Rest day',
      blocks: [],
    );
    final treatment = recovery.decide(
      plan: plan,
      authoredAsRecoveryOrRest: true,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Rest day', style: CohortTextStyles.h2),
        const SizedBox(height: 8),
        Text(
          'This is a rest or recovery day. There is no workout to begin.',
          style: CohortTextStyles.body,
        ),
        const SizedBox(height: 16),
        Text(
          'Preview recovery policy: ${treatment.name}',
          style: CohortTextStyles.eyebrow,
        ),
      ],
    );
  }
}

PreparedExecutionPackage _package(SessionExecutionPlan plan) {
  const key = ProgrammedSessionKey(
    planId: 'preview-lineage',
    planVersion: 'preview-version',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: 'preview-protocol',
    programmeAssignmentId: 'preview-assignment',
    packageContentHash:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );
  return PreparedExecutionPackage(
    programmedSessionKey: key,
    plan: plan,
    brief: WorkoutSessionBrief(sessionName: plan.sessionTitle),
    preparedAt: DateTime.utc(2026, 9, 20),
    assignmentId: 'preview-assignment',
    programmeVersionId: 'preview-version',
    packageContentHash: key.packageContentHash,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: 'preview-protocol',
  );
}

SessionExecutionPlan _strengthPlan() {
  return const SessionExecutionPlan(
    sessionId: 'strength',
    sessionTitle: 'Strength',
    blocks: [
      SessionExecutionBlock(
        blockId: 'strength',
        title: 'Squat',
        blockType: SessionBlockType.strength,
        content: 'Sets: 3\nReps: 5',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.strength,
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'ex-1',
            displayName: 'Back squat',
            prescription: StrengthExercisePrescription(
              sets: 3,
              reps: StrengthRepPrescription(
                type: StrengthRepType.exact,
                exactReps: 5,
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

SessionExecutionPlan _emomPlan() {
  return const SessionExecutionPlan(
    sessionId: 'emom',
    sessionTitle: 'EMOM',
    blocks: [
      SessionExecutionBlock(
        blockId: 'emom',
        title: 'EMOM 10',
        blockType: SessionBlockType.conditioning,
        content: 'Every minute on the minute',
        workoutFormat: WorkoutFormat.emom,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.rounds,
      ),
    ],
  );
}

SessionExecutionPlan _amrapPlan() {
  return const SessionExecutionPlan(
    sessionId: 'amrap',
    sessionTitle: 'AMRAP',
    blocks: [
      SessionExecutionBlock(
        blockId: 'amrap',
        title: 'AMRAP 12',
        blockType: SessionBlockType.conditioning,
        content: 'As many rounds as possible',
        workoutFormat: WorkoutFormat.amrap,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.amrap,
      ),
    ],
  );
}

SessionExecutionPlan _recoveryPlan() {
  return const SessionExecutionPlan(
    sessionId: 'recovery',
    sessionTitle: 'Mobility',
    blocks: [
      SessionExecutionBlock(
        blockId: 'mobility',
        title: '90/90 breathing',
        blockType: SessionBlockType.coolDown,
        content: 'Guided mobility block',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.completion,
      ),
    ],
  );
}
