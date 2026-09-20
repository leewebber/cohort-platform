import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/models/active_performance_draft.dart';
import '../../performance/models/circuit_station_actual.dart';
import '../../performance/models/performance_result_data.dart';
import '../../performance/models/performance_result_type.dart';
import '../../performance/models/performance_snapshot.dart';
import '../../performance/models/training_session_record_status.dart';
import '../../plans/models/programmed_session_key.dart';
import '../../workout_player/models/workout_session_brief.dart';
import '../../../core/persistence/models/execution_result_models.dart';
import '../../../models/block_performance_capture_mode.dart';
import '../../../models/circuit_capture_strategy.dart';
import '../../../models/session_block_type.dart';
import '../../../models/strength_exercise_prescription.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import '../models/prepared_execution_package.dart';
import '../models/production_restore_outcome.dart';
import '../models/production_session_draft.dart';
import '../models/session_execution_plan.dart';
import '../services/block_timer_controller.dart';
import '../services/production_restore_resolver.dart';
import '../services/workout_progress_snapshot_policy.dart';

const previewAthleteId = 'preview-athlete';
const previewAssignmentId = 'preview-assignment';
const previewVersionId = 'preview-version';
const previewOccurrenceId = 'preview-occ';
const previewSessionKey = 'preview-key';
const previewHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

enum DailyJourneyIntegrityPreviewState {
  noDraft,
  resumeDraft,
  strengthResume,
  intervalResume,
  emomResume,
  circuitResume,
  forTimeResume,
  amrapResume,
  legacyPartial,
  unsafeLegacy,
  staleOccurrence,
  staleVersion,
  foreignAthlete,
  corruptDraft,
  unsupportedDraft,
  completionPending,
  structuredRecovery,
  guidanceRest,
}

enum DailyJourneyIntegrityPreviewKind {
  homeBegin,
  homeResume,
  activeSession,
  blocked,
  completionPending,
  restDay,
}

class DailyJourneyIntegrityPreviewScenario {
  const DailyJourneyIntegrityPreviewScenario({
    required this.state,
    required this.label,
    required this.expectedOutcome,
    required this.kind,
    required this.plan,
    this.format,
    this.unsafeLegacy = false,
    this.openRestoredTimer = false,
    this.restoredTimerOverride,
  });

  final DailyJourneyIntegrityPreviewState state;
  final String label;
  final ProductionRestoreOutcome expectedOutcome;
  final DailyJourneyIntegrityPreviewKind kind;
  final SessionExecutionPlan plan;
  final WorkoutFormat? format;
  final bool unsafeLegacy;
  final bool openRestoredTimer;
  final BlockTimerState? restoredTimerOverride;

  ProductionRestoreDecision decision() {
    if (unsafeLegacy) {
      return const ProductionRestoreDecision(
        outcome: ProductionRestoreOutcome.corrupt,
        athleteMessage: 'Draft cannot be safely restored',
      );
    }
    return const ProductionRestoreResolver().resolve(restoreRequest(state));
  }

  void assertConsistent() {
    if (unsafeLegacy) {
      final action = const WorkoutProgressSnapshotPolicy().bootAction(
        snapshot: WorkoutProgressSnapshot(
          sessionId: 'legacy',
          athleteId: previewAthleteId,
          currentExerciseIndex: 0,
          currentSet: 1,
          completedExerciseIndexes: const [],
          startedAt: DateTime.utc(2026, 1, 1),
          lastUpdatedAt: DateTime.utc(2026, 1, 1),
          enteredResults: const [
            {'reps': 5},
          ],
        ),
        currentAthleteId: previewAthleteId,
      );
      if (action != WorkoutProgressSnapshotBootAction.showCannotRestore) {
        throw StateError('unsafe legacy must fail closed');
      }
      return;
    }
    final resolved = decision().outcome;
    if (resolved != expectedOutcome) {
      throw StateError(
        '${state.name} expected ${expectedOutcome.name} but resolved $resolved',
      );
    }
    if (ProductionRestoreAthleteCopyGuards.staleMayNotResume(resolved) &&
        resolved == ProductionRestoreOutcome.resumable) {
      throw StateError('${state.name} cannot report resumable');
    }
  }
}

abstract final class ProductionRestoreAthleteCopyGuards {
  static bool staleMayNotResume(ProductionRestoreOutcome outcome) {
    return outcome == ProductionRestoreOutcome.staleOccurrence ||
        outcome == ProductionRestoreOutcome.staleProgrammeVersion;
  }
}

ProductionRestoreRequest restoreRequest(
  DailyJourneyIntegrityPreviewState state,
) {
  return switch (state) {
    DailyJourneyIntegrityPreviewState.noDraft => _request(),
    DailyJourneyIntegrityPreviewState.resumeDraft ||
    DailyJourneyIntegrityPreviewState.strengthResume ||
    DailyJourneyIntegrityPreviewState.intervalResume ||
    DailyJourneyIntegrityPreviewState.emomResume ||
    DailyJourneyIntegrityPreviewState.circuitResume ||
    DailyJourneyIntegrityPreviewState.forTimeResume ||
    DailyJourneyIntegrityPreviewState.amrapResume ||
    DailyJourneyIntegrityPreviewState.completionPending =>
      _request(identity: _identity(), actuals: _actuals()),
    DailyJourneyIntegrityPreviewState.structuredRecovery => _request(),
    DailyJourneyIntegrityPreviewState.legacyPartial => _request(
      identity: _identity(schemaVersion: 0, trainingSessionId: 0),
      actuals: _actuals(),
    ),
    DailyJourneyIntegrityPreviewState.unsafeLegacy => _request(
      jsonCorrupt: true,
    ),
    DailyJourneyIntegrityPreviewState.staleOccurrence => _request(
      identity: _identity(occurrenceId: 'other-occ'),
      actuals: _actuals(),
    ),
    DailyJourneyIntegrityPreviewState.staleVersion => _request(
      identity: _identity(programmeVersionId: 'old-version'),
      actuals: _actuals(),
    ),
    DailyJourneyIntegrityPreviewState.foreignAthlete => _request(
      identity: _identity(athleteId: 'other-athlete'),
      actuals: _actuals(athleteId: 'other-athlete'),
    ),
    DailyJourneyIntegrityPreviewState.corruptDraft => _request(
      jsonCorrupt: true,
    ),
    DailyJourneyIntegrityPreviewState.unsupportedDraft => _request(
      identity: _identity(schemaVersion: 99),
      actuals: _actuals(),
    ),
    DailyJourneyIntegrityPreviewState.guidanceRest => _request(),
  };
}

List<DailyJourneyIntegrityPreviewScenario> dailyJourneyIntegrityPreviewScenarios() {
  return [
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.noDraft,
      label: '1 No draft — Begin',
      expectedOutcome: ProductionRestoreOutcome.noDraft,
      kind: DailyJourneyIntegrityPreviewKind.homeBegin,
      plan: previewStrengthPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.resumeDraft,
      label: '2 Valid durable draft — Resume',
      expectedOutcome: ProductionRestoreOutcome.resumable,
      kind: DailyJourneyIntegrityPreviewKind.homeResume,
      plan: previewStrengthPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.strengthResume,
      label: '3 Resumed strength at exact set',
      expectedOutcome: ProductionRestoreOutcome.resumable,
      kind: DailyJourneyIntegrityPreviewKind.activeSession,
      plan: previewStrengthPlan(),
      format: WorkoutFormat.none,
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.intervalResume,
      label: '4 Resumed interval timer',
      expectedOutcome: ProductionRestoreOutcome.resumable,
      kind: DailyJourneyIntegrityPreviewKind.activeSession,
      plan: previewIntervalPlan(),
      format: WorkoutFormat.intervals,
      openRestoredTimer: true,
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.emomResume,
      label: '5 Resumed EMOM timer',
      expectedOutcome: ProductionRestoreOutcome.resumable,
      kind: DailyJourneyIntegrityPreviewKind.activeSession,
      plan: previewEmomPlan(),
      format: WorkoutFormat.emom,
      openRestoredTimer: true,
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.circuitResume,
      label: '6 Resumed circuit',
      expectedOutcome: ProductionRestoreOutcome.resumable,
      kind: DailyJourneyIntegrityPreviewKind.activeSession,
      plan: previewCircuitPlan(),
      format: WorkoutFormat.rounds,
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.forTimeResume,
      label: '7 Resumed for-time',
      expectedOutcome: ProductionRestoreOutcome.resumable,
      kind: DailyJourneyIntegrityPreviewKind.activeSession,
      plan: previewForTimePlan(),
      format: WorkoutFormat.forTime,
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.amrapResume,
      label: '8 Resumed AMRAP',
      expectedOutcome: ProductionRestoreOutcome.resumable,
      kind: DailyJourneyIntegrityPreviewKind.activeSession,
      plan: previewAmrapPlan(),
      format: WorkoutFormat.amrap,
      openRestoredTimer: true,
      restoredTimerOverride: const BlockTimerState(
        format: WorkoutFormat.amrap,
        phase: BlockTimerPhase.countdown,
        isRunning: false,
        isPaused: true,
        isFinished: false,
        primarySeconds: 270,
        phaseLabel: 'AMRAP',
      ),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.legacyPartial,
      label: '9 Legacy partially recoverable',
      expectedOutcome: ProductionRestoreOutcome.legacyPartiallyRecoverable,
      kind: DailyJourneyIntegrityPreviewKind.blocked,
      plan: previewStrengthPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.unsafeLegacy,
      label: '10 Unsafe legacy',
      expectedOutcome: ProductionRestoreOutcome.corrupt,
      kind: DailyJourneyIntegrityPreviewKind.blocked,
      plan: previewStrengthPlan(),
      unsafeLegacy: true,
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.staleOccurrence,
      label: '11 Stale occurrence',
      expectedOutcome: ProductionRestoreOutcome.staleOccurrence,
      kind: DailyJourneyIntegrityPreviewKind.blocked,
      plan: previewStrengthPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.staleVersion,
      label: '12 Stale programme version',
      expectedOutcome: ProductionRestoreOutcome.staleProgrammeVersion,
      kind: DailyJourneyIntegrityPreviewKind.blocked,
      plan: previewStrengthPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.foreignAthlete,
      label: '13 Foreign-athlete draft',
      expectedOutcome: ProductionRestoreOutcome.foreignAthlete,
      kind: DailyJourneyIntegrityPreviewKind.blocked,
      plan: previewStrengthPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.corruptDraft,
      label: '14 Corrupt draft',
      expectedOutcome: ProductionRestoreOutcome.corrupt,
      kind: DailyJourneyIntegrityPreviewKind.blocked,
      plan: previewStrengthPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.unsupportedDraft,
      label: '15 Unsupported-version draft',
      expectedOutcome: ProductionRestoreOutcome.unsupportedVersion,
      kind: DailyJourneyIntegrityPreviewKind.blocked,
      plan: previewStrengthPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.completionPending,
      label: '16 Completion pending/retry',
      expectedOutcome: ProductionRestoreOutcome.resumable,
      kind: DailyJourneyIntegrityPreviewKind.completionPending,
      plan: previewStrengthPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.structuredRecovery,
      label: '17 Structured recovery',
      expectedOutcome: ProductionRestoreOutcome.noDraft,
      kind: DailyJourneyIntegrityPreviewKind.homeBegin,
      plan: previewRecoveryPlan(),
    ),
    DailyJourneyIntegrityPreviewScenario(
      state: DailyJourneyIntegrityPreviewState.guidanceRest,
      label: '18 Guidance-only rest',
      expectedOutcome: ProductionRestoreOutcome.noDraft,
      kind: DailyJourneyIntegrityPreviewKind.restDay,
      plan: const SessionExecutionPlan(
        sessionId: 'rest',
        sessionTitle: 'Rest day',
        blocks: [],
      ),
    ),
  ];
}

ProductionRestoreRequest _request({
  ProductionSessionDraft? identity,
  ActivePerformanceDraft? actuals,
  bool jsonCorrupt = false,
}) {
  return ProductionRestoreRequest(
    athleteId: previewAthleteId,
    assignmentId: previewAssignmentId,
    programmeVersionId: previewVersionId,
    programmedSessionKey: previewSessionKey,
    packageContentHash: previewHash,
    occurrenceId: previewOccurrenceId,
    trainingSessionId: 4,
    jsonCorrupt: jsonCorrupt,
    persistedIdentity: identity,
    actuals: actuals,
  );
}

ProductionSessionDraft _identity({
  String athleteId = previewAthleteId,
  String programmeVersionId = previewVersionId,
  String occurrenceId = previewOccurrenceId,
  int schemaVersion = 1,
  int trainingSessionId = 4,
}) {
  return ProductionSessionDraft(
    schemaVersion: schemaVersion,
    athleteId: athleteId,
    assignmentId: previewAssignmentId,
    programmeVersionId: programmeVersionId,
    programmedSessionKey: previewSessionKey,
    packageContentHash: previewHash,
    trainingSessionId: trainingSessionId,
    entryMode: 'live',
    occurrenceId: occurrenceId,
  );
}

ActivePerformanceDraft _actuals({String athleteId = previewAthleteId}) {
  return ActivePerformanceDraft(
    recordId: 'preview-record',
    athleteId: athleteId,
    trainingSessionId: 4,
    sourceProtocolId: 'preview-protocol',
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'preview-protocol',
      sessionTitle: 'Preview',
    ),
    status: TrainingSessionRecordStatus.inProgress,
    startedAt: DateTime.utc(2026, 9, 20),
    assignmentId: previewAssignmentId,
    programmeId: previewVersionId,
  );
}

PreparedExecutionPackage previewPackage(SessionExecutionPlan plan) {
  const key = ProgrammedSessionKey(
    planId: 'preview-lineage',
    planVersion: previewVersionId,
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: 'preview-protocol',
    programmeAssignmentId: previewAssignmentId,
    packageContentHash: previewHash,
  );
  return PreparedExecutionPackage(
    programmedSessionKey: key,
    plan: plan,
    brief: WorkoutSessionBrief(sessionName: plan.sessionTitle),
    preparedAt: DateTime.utc(2026, 9, 20),
    assignmentId: previewAssignmentId,
    programmeVersionId: previewVersionId,
    packageContentHash: previewHash,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: 'preview-protocol',
  );
}

SessionExecutionPlan previewStrengthPlan() {
  return const SessionExecutionPlan(
    sessionId: 'strength',
    sessionTitle: 'Strength',
    programmeContextLabel: 'Week 1 · Day 1',
    durationMin: 45,
    blocks: [
      SessionExecutionBlock(
        blockId: 'strength',
        title: 'Squat',
        blockType: SessionBlockType.strength,
        content: '3 sets × 5',
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

SessionExecutionPlan previewIntervalPlan() {
  return const SessionExecutionPlan(
    sessionId: 'intervals',
    sessionTitle: 'Intervals',
    programmeContextLabel: 'Week 1 · Day 2',
    durationMin: 20,
    blocks: [
      SessionExecutionBlock(
        blockId: 'intervals',
        title: 'Row intervals',
        blockType: SessionBlockType.conditioning,
        content: '8 × 40s work / 20s rest',
        workoutFormat: WorkoutFormat.intervals,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.intervals,
        timerConfiguration: TimerConfiguration(
          workSeconds: 40,
          restSeconds: 20,
          rounds: 8,
        ),
        timerSummary: '8 rounds · 40s work / 20s rest',
      ),
    ],
  );
}

SessionExecutionPlan previewEmomPlan() {
  return const SessionExecutionPlan(
    sessionId: 'emom',
    sessionTitle: 'EMOM',
    programmeContextLabel: 'Week 1 · Day 3',
    durationMin: 10,
    blocks: [
      SessionExecutionBlock(
        blockId: 'emom',
        title: 'EMOM 10',
        blockType: SessionBlockType.conditioning,
        content: 'Alternate bike and burpees',
        workoutFormat: WorkoutFormat.emom,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.rounds,
        timerConfiguration: TimerConfiguration(
          totalDurationSeconds: 600,
          durationSeconds: 600,
          intervalSeconds: 60,
          stations: [
            TimerStationSpec(exerciseId: 'ex-bike', position: 1, calories: 12),
            TimerStationSpec(exerciseId: 'ex-burpee', position: 2, reps: 8),
          ],
        ),
        timerSummary: '10 min · 60s intervals',
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'ex-bike',
            displayName: 'Assault bike',
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'ex-burpee',
            displayName: 'Burpee',
          ),
        ],
      ),
    ],
  );
}

SessionExecutionPlan previewCircuitPlan() {
  return const SessionExecutionPlan(
    sessionId: 'circuit',
    sessionTitle: 'Circuit',
    programmeContextLabel: 'Week 1 · Day 4',
    durationMin: 18,
    blocks: [
      SessionExecutionBlock(
        blockId: 'circuit',
        title: 'Three-station circuit',
        blockType: SessionBlockType.conditioning,
        content: 'Row, swing, walk',
        workoutFormat: WorkoutFormat.rounds,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.rounds,
        timerConfiguration: TimerConfiguration(
          targetRounds: 3,
          rounds: 3,
          captureStrategy: CircuitCaptureStrategy.variableOutput,
          stations: [
            TimerStationSpec(exerciseId: 'ex-row', position: 1, calories: 15),
            TimerStationSpec(exerciseId: 'ex-swing', position: 2, reps: 12),
            TimerStationSpec(
              exerciseId: 'ex-walk',
              position: 3,
              distanceMeters: 100,
            ),
          ],
        ),
        timerSummary: '3 rounds',
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'ex-row',
            displayName: 'Row',
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'ex-swing',
            displayName: 'Kettlebell swing',
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'ex-walk',
            displayName: 'Farmer carry',
          ),
        ],
      ),
    ],
  );
}

SessionExecutionPlan previewForTimePlan() {
  return const SessionExecutionPlan(
    sessionId: 'fortime',
    sessionTitle: 'For time',
    programmeContextLabel: 'Week 1 · Day 5',
    durationMin: 12,
    blocks: [
      SessionExecutionBlock(
        blockId: 'fortime',
        title: '21-15-9',
        blockType: SessionBlockType.conditioning,
        content: 'Thruster and pull-up',
        workoutFormat: WorkoutFormat.forTime,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.forTime,
        timerConfiguration: TimerConfiguration(
          timeCapSeconds: 720,
          stopwatchEnabled: true,
        ),
        timerSummary: 'For Time · 12 min cap',
      ),
    ],
  );
}

SessionExecutionPlan previewAmrapPlan() {
  return const SessionExecutionPlan(
    sessionId: 'amrap',
    sessionTitle: 'AMRAP',
    programmeContextLabel: 'Week 1 · Day 6',
    durationMin: 12,
    blocks: [
      SessionExecutionBlock(
        blockId: 'amrap',
        title: 'AMRAP 12',
        blockType: SessionBlockType.conditioning,
        content: 'Row, squat, press',
        workoutFormat: WorkoutFormat.amrap,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.amrap,
        timerConfiguration: TimerConfiguration(durationSeconds: 720),
        timerSummary: '12 min AMRAP',
      ),
    ],
  );
}

SessionExecutionPlan previewRecoveryPlan() {
  return const SessionExecutionPlan(
    sessionId: 'recovery',
    sessionTitle: 'Recovery',
    programmeContextLabel: 'Week 1 · Day 7',
    durationMin: 25,
    coachNotes: 'Keep breathing easy. Stop if anything feels sharp.',
    blocks: [
      SessionExecutionBlock(
        blockId: 'mobility',
        title: 'Full-body mobility',
        blockType: SessionBlockType.coolDown,
        content: 'Easy joint range, 8–10 minutes',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        performanceCaptureMode: BlockPerformanceCaptureMode.completion,
        coachNotes: 'Focus: hips and thoracic spine',
      ),
      SessionExecutionBlock(
        blockId: 'breathing',
        title: 'Nasal breathing',
        blockType: SessionBlockType.coolDown,
        content: 'Quiet nasal breathing, about 5 minutes',
        workoutFormat: WorkoutFormat.none,
        position: 2,
        performanceCaptureMode: BlockPerformanceCaptureMode.completion,
      ),
    ],
  );
}

void applyPreviewActuals({
  required DailyJourneyIntegrityPreviewState state,
  required PerformanceCaptureController performance,
  required SessionExecutionPlan plan,
}) {
  switch (state) {
    case DailyJourneyIntegrityPreviewState.strengthResume:
    case DailyJourneyIntegrityPreviewState.resumeDraft:
    case DailyJourneyIntegrityPreviewState.legacyPartial:
      if (plan.blocks.first.linkedExercises.isEmpty) return;
      final exercise = performance.draft.blockDrafts.first.exerciseResults.first;
      if (exercise.sets.isEmpty) return;
      performance.updateSet(
        plan.blocks.first.blockId,
        exercise.sourceExerciseId,
        exercise.sets.first.setResultId,
        (current) => current.copyWith(reps: 5, load: 60, completed: true),
      );
    case DailyJourneyIntegrityPreviewState.intervalResume:
      performance.updateBlockResultData(
        plan.blocks.first.blockId,
        const IntervalResultData(
          intervalsCompleted: 3,
          totalIntervals: 8,
          entered: true,
          workSeconds: 40,
          note: 'held pace',
        ),
      );
    case DailyJourneyIntegrityPreviewState.emomResume:
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
    case DailyJourneyIntegrityPreviewState.circuitResume:
      performance.setBlockCaptureMode(
        plan.blocks.first.blockId,
        BlockCaptureMode.circuit,
      );
      performance.updateBlockResultData(
        plan.blocks.first.blockId,
        const CircuitResultData(
          format: 'rounds',
          comparisonFamily: 'rounds',
          endedEarly: true,
          earlyEndReason: 'stopped after two stations',
          targetRounds: 3,
          stations: [
            CircuitStationActual(
              ordinal: 1,
              round: 1,
              stationIndex: 1,
              stationId: 'ex-row',
              displayName: 'Row',
              primaryMetric: CircuitStationMetric.calories,
              prescribedCalories: 15,
              calories: 15,
              state: CircuitOccurrenceState.recorded,
            ),
            CircuitStationActual(
              ordinal: 2,
              round: 1,
              stationIndex: 2,
              stationId: 'ex-swing',
              displayName: 'Kettlebell swing',
              primaryMetric: CircuitStationMetric.reps,
              prescribedReps: 12,
              reps: 12,
              state: CircuitOccurrenceState.recorded,
            ),
            CircuitStationActual(
              ordinal: 3,
              round: 1,
              stationIndex: 3,
              stationId: 'ex-walk',
              displayName: 'Farmer carry',
              primaryMetric: CircuitStationMetric.distance,
              prescribedDistanceMeters: 100,
              state: CircuitOccurrenceState.pending,
            ),
          ],
        ),
      );
    case DailyJourneyIntegrityPreviewState.forTimeResume:
      performance.updateBlockResultData(
        plan.blocks.first.blockId,
        const ForTimeResultData(
          elapsedSeconds: 412,
          completed: false,
          timeCapped: false,
          remainingWorkNote: '2 reps left',
        ),
      );
    case DailyJourneyIntegrityPreviewState.amrapResume:
      performance.updateBlockResultData(
        plan.blocks.first.blockId,
        const AmrapResultData(rounds: 6, extraReps: 3, entered: true),
      );
    default:
      break;
  }
}
