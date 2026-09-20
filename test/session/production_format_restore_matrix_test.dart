import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/models/circuit_station_actual.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/production_restore_envelope.dart';
import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/models/production_session_draft.dart';
import 'package:cohort_platform/features/session/models/production_session_ui_cursor.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/production_recovery_session_policy.dart';
import 'package:cohort_platform/features/session/services/production_restore_envelope_store.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/models/circuit_capture_strategy.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

const _hash = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

void main() {
  const resolver = ProductionRestoreResolver();

  group('production-route format restore matrix', () {
    test('strength sets, load, reps, RPE and cursor survive restart', () async {
      final harness = await _captureAndRestart(
        _plan(
          blockId: 'strength',
          format: WorkoutFormat.none,
          blockType: SessionBlockType.strength,
          capture: BlockPerformanceCaptureMode.strength,
          withExercise: true,
        ),
        mutate: (controller) {
          final exercise = controller.draft.blockDrafts.first.exerciseResults.first;
          final set = exercise.sets.first;
          controller.updateSet(
            'strength',
            exercise.sourceExerciseId,
            set.setResultId,
            (current) => current.copyWith(
              reps: 5,
              load: 60,
              rpe: 7,
              completed: true,
            ),
          );
          controller.setActiveBlock('strength');
        },
      );
      final set = harness.restored.blockDrafts.first.exerciseResults.first.sets.first;
      expect(set.reps, 5);
      expect(set.load, 60);
      expect(set.rpe, 7);
      expect(set.completed, isTrue);
      expect(harness.decision.outcome, ProductionRestoreOutcome.resumable);
      expect(harness.decision.cursor?.activeBlockId, 'strength');
    });

    test('interval actuals survive restart', () async {
      final harness = await _captureAndRestart(
        _plan(
          blockId: 'intervals',
          format: WorkoutFormat.intervals,
          capture: BlockPerformanceCaptureMode.intervals,
        ),
        mutate: (controller) {
          controller.updateBlockResultData(
            'intervals',
            const IntervalResultData(
              intervalsCompleted: 3,
              totalIntervals: 8,
              entered: true,
              note: 'held pace',
            ),
          );
        },
      );
      final result =
          harness.restored.blockDrafts.first.resultData as IntervalResultData;
      expect(result.intervalsCompleted, 3);
      expect(result.note, 'held pace');
    });

    test('steady-state endurance fields survive restart', () async {
      final harness = await _captureAndRestart(
        _plan(
          blockId: 'endurance',
          format: WorkoutFormat.steadyState,
          capture: BlockPerformanceCaptureMode.endurance,
        ),
        mutate: (controller) {
          controller.updateBlockResultData(
            'endurance',
            const EnduranceResultData(
              distance: 5.2,
              durationSeconds: 1500,
              averageHeartRate: 148,
              note: 'easy',
              completed: false,
            ),
          );
        },
      );
      final result =
          harness.restored.blockDrafts.first.resultData as EnduranceResultData;
      expect(result.distance, 5.2);
      expect(result.durationSeconds, 1500);
      expect(result.averageHeartRate, 148);
      expect(result.completed, isFalse);
    });

    test('EMOM score and timer cursor survive restart', () async {
      final harness = await _captureAndRestart(
        _plan(
          blockId: 'emom',
          format: WorkoutFormat.emom,
          capture: BlockPerformanceCaptureMode.rounds,
        ),
        mutate: (controller) {
          controller.updateBlockResultData(
            'emom',
            CircuitResultData(
              format: 'emom',
              comparisonFamily: 'emom',
              stations: const [],
              recordedCompletedRounds: 6,
              scoreEntered: true,
              prescribedTargetsUsed: true,
              timerCursor: const CircuitTimerCursor(
                currentRound: 6,
                currentOrdinal: 6,
                remainingSeconds: 12,
                phase: 'work',
                isPaused: true,
              ),
            ),
          );
        },
      );
      final result =
          harness.restored.blockDrafts.first.resultData as CircuitResultData;
      expect(result.recordedCompletedRounds, 6);
      expect(result.timerCursor?.isPaused, isTrue);
      expect(result.timerCursor?.remainingSeconds, 12);
    });

    test('circuit ended-early truth survives restart', () async {
      final harness = await _captureAndRestart(
        _plan(
          blockId: 'circuit',
          format: WorkoutFormat.rounds,
          capture: BlockPerformanceCaptureMode.rounds,
        ),
        mutate: (controller) {
          controller.updateBlockResultData(
            'circuit',
            const CircuitResultData(
              format: 'rounds',
              comparisonFamily: 'rounds',
              stations: [],
              captureStrategy: CircuitCaptureStrategy.fixedWork,
              endedEarly: true,
              earlyEndReason: 'knee',
              recordedCompletedRounds: 2,
            ),
          );
        },
      );
      final result =
          harness.restored.blockDrafts.first.resultData as CircuitResultData;
      expect(result.endedEarly, isTrue);
      expect(result.earlyEndReason, 'knee');
    });

    test('for-time cap and elapsed time survive restart', () async {
      final harness = await _captureAndRestart(
        _plan(
          blockId: 'fortime',
          format: WorkoutFormat.forTime,
          capture: BlockPerformanceCaptureMode.forTime,
        ),
        mutate: (controller) {
          controller.updateBlockResultData(
            'fortime',
            const ForTimeResultData(
              elapsedSeconds: 412,
              completed: false,
              timeCapped: true,
              remainingWorkNote: '2 reps left',
            ),
          );
        },
      );
      final result =
          harness.restored.blockDrafts.first.resultData as ForTimeResultData;
      expect(result.elapsedSeconds, 412);
      expect(result.timeCapped, isTrue);
      expect(result.completed, isFalse);
    });

    test('AMRAP rounds and reps survive restart', () async {
      final harness = await _captureAndRestart(
        _plan(
          blockId: 'amrap',
          format: WorkoutFormat.amrap,
          capture: BlockPerformanceCaptureMode.amrap,
        ),
        mutate: (controller) {
          controller.updateBlockResultData(
            'amrap',
            const AmrapResultData(rounds: 7, extraReps: 4, entered: true),
          );
        },
      );
      final result =
          harness.restored.blockDrafts.first.resultData as AmrapResultData;
      expect(result.rounds, 7);
      expect(result.extraReps, 4);
    });

    test('structured recovery uses executable blocks on production route', () {
      final plan = _plan(
        blockId: 'mobility',
        format: WorkoutFormat.none,
        blockType: SessionBlockType.coolDown,
        capture: BlockPerformanceCaptureMode.completion,
        content: '90/90 breathing',
      );
      expect(
        const ProductionRecoverySessionPolicy().decide(
          plan: plan,
          authoredAsRecoveryOrRest: true,
        ),
        ProductionRecoveryTreatment.executableBlocks,
      );
    });

    test('guidance-only recovery has no fake capture path', () {
      const plan = SessionExecutionPlan(
        sessionId: 'rest',
        sessionTitle: 'Rest',
        blocks: [],
      );
      expect(
        const ProductionRecoverySessionPolicy().decide(
          plan: plan,
          authoredAsRecoveryOrRest: true,
        ),
        ProductionRecoveryTreatment.guidanceOnly,
      );
    });

    test('unsupported format stays fail-closed', () {
      expect(
        resolver
            .resolve(
              ProductionRestoreRequest(
                athleteId: 'athlete-1',
                assignmentId: 'assign-1',
                programmeVersionId: 'ver-1',
                programmedSessionKey: 'key-1',
                packageContentHash: _hash,
                unavailable: true,
              ),
            )
            .outcome,
        ProductionRestoreOutcome.unavailable,
      );
    });

    test('completion failure retains draft; success clears envelope', () async {
      final store = InMemoryPerformanceRecordStore();
      final coordinator = PerformanceRecordSaveCoordinator(store: store);
      final envelopeStore = ProductionRestoreEnvelopeStore();
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _plan(
          blockId: 'amrap',
          format: WorkoutFormat.amrap,
          capture: BlockPerformanceCaptureMode.amrap,
        ),
        athleteId: 'athlete-1',
        trainingSessionId: 4,
        programmeContext: _context(),
      );
      controller.updateBlockResultData(
        'amrap',
        const AmrapResultData(rounds: 3, extraReps: 1, entered: true),
      );
      controller.markBlockComplete('amrap');
      await coordinator.saveDraft(controller: controller);
      envelopeStore.write(
        ProductionRestoreEnvelope(
          identity: _identity(),
          cursor: const ProductionSessionUiCursor(
            schemaVersion: 1,
            athleteId: 'athlete-1',
            assignmentId: 'assign-1',
            trainingSessionId: 4,
            activeBlockId: 'amrap',
          ),
        ),
      );

      final retained = await coordinator.loadInProgressDraftAsRecord(
        athleteId: 'athlete-1',
        trainingSessionId: 4,
      );
      expect(retained, isNotNull);
      expect(envelopeStore.read(athleteId: 'athlete-1', trainingSessionId: 4), isNotNull);

      await store.completeRecord(
        controller.draft.copyWith(status: TrainingSessionRecordStatus.completed),
      );
      envelopeStore.clear(athleteId: 'athlete-1', trainingSessionId: 4);
      expect(envelopeStore.read(athleteId: 'athlete-1', trainingSessionId: 4), isNull);
      final terminal = await store.getTerminalForTrainingSession(
        athleteId: 'athlete-1',
        trainingSessionId: 4,
      );
      expect(terminal?.status, TrainingSessionRecordStatus.completed);
    });

    test('memory store cannot overwrite newer durable actuals', () async {
      final harness = await _captureAndRestart(
        _plan(
          blockId: 'amrap',
          format: WorkoutFormat.amrap,
          capture: BlockPerformanceCaptureMode.amrap,
        ),
        mutate: (controller) {
          controller.updateBlockResultData(
            'amrap',
            const AmrapResultData(rounds: 5, extraReps: 0, entered: true),
          );
        },
        poisonMemory: true,
      );
      final result =
          harness.restored.blockDrafts.first.resultData as AmrapResultData;
      expect(result.rounds, 5);
      expect(AthleteSessionMemoryStore.instance.read('4:amrap-session'), isNull);
    });
  });
}

class _Harness {
  const _Harness({required this.restored, required this.decision});

  final ActivePerformanceDraft restored;
  final ProductionRestoreDecision decision;
}

Future<_Harness> _captureAndRestart(
  SessionExecutionPlan plan, {
  required void Function(PerformanceCaptureController controller) mutate,
  bool poisonMemory = false,
}) async {
  final store = InMemoryPerformanceRecordStore();
  final coordinator = PerformanceRecordSaveCoordinator(store: store);
  final envelopeStore = ProductionRestoreEnvelopeStore();
  final controller = PerformanceCaptureController.initializeFromExecutionPlan(
    plan: plan,
    athleteId: 'athlete-1',
    trainingSessionId: 4,
    programmeContext: _context(),
  );
  mutate(controller);
  await coordinator.saveDraft(controller: controller);
  envelopeStore.write(
    ProductionRestoreEnvelope(
      identity: _identity(),
      cursor: ProductionSessionUiCursor(
        schemaVersion: 1,
        athleteId: 'athlete-1',
        assignmentId: 'assign-1',
        trainingSessionId: 4,
        occurrenceId: 'occ-1',
        activeBlockId: plan.blocks.first.blockId,
        expandedBlockIds: {plan.blocks.first.blockId},
      ),
    ),
  );
  if (poisonMemory) {
    AthleteSessionMemoryStore.instance.write(
      SessionExecutionController(
        plan: plan,
        sessionKey: '4:${plan.sessionId}',
      ).state.copyWith(activeBlockIndex: 99),
    );
  }

  AthleteSessionMemoryStore.instance.clear('4:${plan.sessionId}');
  final record = await coordinator.loadInProgressDraftAsRecord(
    athleteId: 'athlete-1',
    trainingSessionId: 4,
  );
  final restored = coordinator.restoreControllerFromRecord(record!).draft;
  final envelope = envelopeStore.read(
    athleteId: 'athlete-1',
    trainingSessionId: 4,
  );
  final decision = const ProductionRestoreResolver().resolve(
    ProductionRestoreRequest(
      athleteId: 'athlete-1',
      assignmentId: 'assign-1',
      programmeVersionId: 'ver-1',
      programmedSessionKey: 'key-1',
      packageContentHash: _hash,
      occurrenceId: 'occ-1',
      trainingSessionId: 4,
      persistedIdentity: envelope?.identity,
      actuals: restored,
      cursor: envelope?.cursor,
    ),
  );
  return _Harness(restored: restored, decision: decision);
}

SessionExecutionPlan _plan({
  required String blockId,
  required WorkoutFormat format,
  required BlockPerformanceCaptureMode capture,
  SessionBlockType blockType = SessionBlockType.conditioning,
  bool withExercise = false,
  String content = 'Authored work',
}) {
  return SessionExecutionPlan(
    sessionId: '$blockId-session',
    sessionTitle: blockId,
    blocks: [
      SessionExecutionBlock(
        blockId: blockId,
        title: blockId,
        blockType: blockType,
        content: content,
        workoutFormat: format,
        position: 1,
        performanceCaptureMode: capture,
        linkedExercises: withExercise
            ? [
                SessionExecutionExerciseSummary(
                  exerciseId: 'ex-1',
                  displayName: 'Movement',
                  prescription: const StrengthExercisePrescription(
                    sets: 3,
                    reps: StrengthRepPrescription(
                      type: StrengthRepType.exact,
                      exactReps: 5,
                    ),
                  ),
                ),
              ]
            : const [],
      ),
    ],
  );
}

ProgrammeExecutionContext _context() {
  return const ProgrammeExecutionContext(
    assignmentId: 'assign-1',
    programmeVersionId: 'ver-1',
    sessionSlotId: 'slot-1',
    weekNumber: 1,
    dayKey: 'day_1',
    sessionOrder: 1,
    plannedProtocolId: 'protocol-1',
    effectiveProtocolId: 'protocol-1',
    lineageCode: 'lineage-1',
    packageContentHash: _hash,
    programmedSessionKey: 'key-1',
    occurrenceId: 'occ-1',
  );
}

ProductionSessionDraft _identity() {
  return ProductionSessionDraft(
    schemaVersion: 1,
    athleteId: 'athlete-1',
    assignmentId: 'assign-1',
    programmeVersionId: 'ver-1',
    programmedSessionKey: 'key-1',
    packageContentHash: _hash,
    trainingSessionId: 4,
    entryMode: 'live',
    occurrenceId: 'occ-1',
  );
}
