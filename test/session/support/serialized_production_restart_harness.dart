import 'dart:convert';

import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/models/production_restore_envelope.dart';
import 'package:cohort_platform/features/session/models/production_session_draft.dart';
import 'package:cohort_platform/features/session/models/production_session_ui_cursor.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/production_restore_envelope_store.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';

const serializedRestartHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

/// Production-path restart: persist JSON, dispose live objects, rebuild stores.
class SerializedProductionRestartHarness {
  SerializedProductionRestartHarness({
    this.athleteId = 'athlete-1',
    this.trainingSessionId = 4,
  });

  final String athleteId;
  final int trainingSessionId;

  Future<SerializedRestartResult> captureAndRestart({
    required SessionExecutionPlan plan,
    required void Function(PerformanceCaptureController controller) mutate,
    ProductionSessionDraft? identity,
    bool hostedCompletedAfterRestart = false,
    String? foreignAthleteId,
  }) async {
    final liveStore = InMemoryPerformanceRecordStore();
    final liveCoordinator = PerformanceRecordSaveCoordinator(store: liveStore);
    final liveEnvelope = ProductionRestoreEnvelopeStore();
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: athleteId,
      trainingSessionId: trainingSessionId,
      programmeContext: context(),
    );
    mutate(controller);
    await liveCoordinator.saveDraft(controller: controller);
    final envelope = ProductionRestoreEnvelope(
      identity: identity ?? this.identity(),
      cursor: ProductionSessionUiCursor(
        schemaVersion: 1,
        athleteId: athleteId,
        assignmentId: 'assign-1',
        trainingSessionId: trainingSessionId,
        occurrenceId: 'occ-1',
        activeBlockId: plan.blocks.first.blockId,
        expandedBlockIds: {plan.blocks.first.blockId},
      ),
    );
    liveEnvelope.write(envelope);

    final recordJson = jsonEncode(liveStore.exportCompletionTrees());
    final envelopeJson = jsonEncode(envelope.toJson());

    final freshStore = InMemoryPerformanceRecordStore();
    final trees = (jsonDecode(recordJson) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    if (hostedCompletedAfterRestart) {
      final completed = liveStore.exportCompletionTrees().first;
      completed['status'] = TrainingSessionRecordStatus.completed.dbValue;
      trees
        ..clear()
        ..add(completed);
    }
    freshStore.seedFromCompletionTrees(trees);
    final freshCoordinator = PerformanceRecordSaveCoordinator(store: freshStore);
    final freshEnvelope = ProductionRestoreEnvelopeStore();
    final decodedEnvelope = ProductionRestoreEnvelope.fromJson(
      Map<String, dynamic>.from(jsonDecode(envelopeJson) as Map),
    );
    freshEnvelope.write(decodedEnvelope);

    final requestAthlete = foreignAthleteId ?? athleteId;
    final record = hostedCompletedAfterRestart
        ? await freshStore.getTerminalForTrainingSession(
            athleteId: athleteId,
            trainingSessionId: trainingSessionId,
          )
        : await freshCoordinator.loadInProgressDraftAsRecord(
            athleteId: athleteId,
            trainingSessionId: trainingSessionId,
          );
    final restored = record == null
        ? null
        : freshCoordinator.restoreControllerFromRecord(record).draft;
    final decision = const ProductionRestoreResolver().resolve(
      ProductionRestoreRequest(
        athleteId: requestAthlete,
        assignmentId: 'assign-1',
        programmeVersionId: 'ver-1',
        programmedSessionKey: 'key-1',
        packageContentHash: serializedRestartHash,
        occurrenceId: 'occ-1',
        trainingSessionId: trainingSessionId,
        hostedCompleted: hostedCompletedAfterRestart,
        persistedIdentity: decodedEnvelope.identity,
        actuals: restored,
        cursor: decodedEnvelope.cursor,
      ),
    );
    return SerializedRestartResult(
      restored: restored,
      decision: decision,
      serializedRecord: recordJson,
      serializedEnvelope: envelopeJson,
      trainingSessionId: trainingSessionId,
    );
  }

  ProgrammeExecutionContext context() {
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
      packageContentHash: serializedRestartHash,
      programmedSessionKey: 'key-1',
      occurrenceId: 'occ-1',
    );
  }

  ProductionSessionDraft identity({
    int schemaVersion = 1,
    int? sessionId,
    String? athlete,
  }) {
    return ProductionSessionDraft(
      schemaVersion: schemaVersion,
      athleteId: athlete ?? athleteId,
      assignmentId: 'assign-1',
      programmeVersionId: 'ver-1',
      programmedSessionKey: 'key-1',
      packageContentHash: serializedRestartHash,
      trainingSessionId: sessionId ?? trainingSessionId,
      entryMode: 'live',
      occurrenceId: 'occ-1',
    );
  }
}

class SerializedRestartResult {
  const SerializedRestartResult({
    required this.restored,
    required this.decision,
    required this.serializedRecord,
    required this.serializedEnvelope,
    required this.trainingSessionId,
  });

  final ActivePerformanceDraft? restored;
  final ProductionRestoreDecision decision;
  final String serializedRecord;
  final String serializedEnvelope;
  final int trainingSessionId;
}

SessionExecutionPlan serializedPlan({
  required String blockId,
  required WorkoutFormat format,
  required BlockPerformanceCaptureMode capture,
  SessionBlockType blockType = SessionBlockType.conditioning,
  bool withExercise = false,
  TimerConfiguration? timer,
}) {
  return SessionExecutionPlan(
    sessionId: '$blockId-session',
    sessionTitle: blockId,
    blocks: [
      SessionExecutionBlock(
        blockId: blockId,
        title: blockId,
        blockType: blockType,
        content: 'Authored work',
        workoutFormat: format,
        position: 1,
        performanceCaptureMode: capture,
        timerConfiguration: timer,
        linkedExercises: withExercise
            ? [
                const SessionExecutionExerciseSummary(
                  exerciseId: 'ex-1',
                  displayName: 'Movement',
                  prescription: StrengthExercisePrescription(
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
