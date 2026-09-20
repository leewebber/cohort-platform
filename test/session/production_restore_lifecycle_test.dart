import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/production_restore_envelope.dart';
import 'package:cohort_platform/features/session/models/production_restore_outcome.dart';
import 'package:cohort_platform/features/session/models/production_session_draft.dart';
import 'package:cohort_platform/features/session/models/production_session_ui_cursor.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/production_restore_envelope_store.dart';
import 'package:cohort_platform/features/session/services/production_restore_resolver.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('save-order race prefers durable actuals over later memory writes', () async {
    final store = InMemoryPerformanceRecordStore();
    final coordinator = PerformanceRecordSaveCoordinator(store: store);
    final envelopeStore = ProductionRestoreEnvelopeStore();
    const plan = SessionExecutionPlan(
      sessionId: 'protocol-1',
      sessionTitle: 'Session',
      blocks: [
        SessionExecutionBlock(
          blockId: 'amrap',
          title: 'AMRAP',
          blockType: SessionBlockType.conditioning,
          content: '20:00',
          workoutFormat: WorkoutFormat.amrap,
          position: 1,
          performanceCaptureMode: BlockPerformanceCaptureMode.amrap,
        ),
      ],
    );
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'athlete-1',
      trainingSessionId: 8,
    );
    controller.updateBlockResultData(
      'amrap',
      const AmrapResultData(rounds: 4, extraReps: 2, entered: true),
    );
    await coordinator.saveDraft(controller: controller);
    envelopeStore.write(
      const ProductionRestoreEnvelope(
        identity: ProductionSessionDraft(
          schemaVersion: 1,
          athleteId: 'athlete-1',
          assignmentId: 'assign-1',
          programmeVersionId: 'ver-1',
          programmedSessionKey: 'key-1',
          packageContentHash:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          trainingSessionId: 8,
          entryMode: 'live',
          occurrenceId: 'occ-1',
        ),
        cursor: ProductionSessionUiCursor(
          schemaVersion: 1,
          athleteId: 'athlete-1',
          assignmentId: 'assign-1',
          trainingSessionId: 8,
          activeBlockId: 'amrap',
        ),
      ),
    );

    final memory = SessionExecutionController(
      plan: plan,
      sessionKey: AthleteSessionMemoryStore.sessionKey(
        protocolId: 'protocol-1',
        trainingSessionId: 8,
      ),
    );
    memory.goToBlock(0);
    AthleteSessionMemoryStore.instance.write(
      memory.state.copyWith(activeBlockIndex: 99),
    );

    final record = await coordinator.loadInProgressDraftAsRecord(
      athleteId: 'athlete-1',
      trainingSessionId: 8,
    );
    final restored = coordinator.restoreControllerFromRecord(record!).draft;
    final decision = const ProductionRestoreResolver().resolve(
      ProductionRestoreRequest(
        athleteId: 'athlete-1',
        assignmentId: 'assign-1',
        programmeVersionId: 'ver-1',
        programmedSessionKey: 'key-1',
        packageContentHash:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        occurrenceId: 'occ-1',
        trainingSessionId: 8,
        persistedIdentity: envelopeStore
            .read(athleteId: 'athlete-1', trainingSessionId: 8)
            ?.identity,
        actuals: restored,
        cursor: envelopeStore
            .read(athleteId: 'athlete-1', trainingSessionId: 8)
            ?.cursor,
        memoryState: AthleteSessionMemoryStore.instance.read(
          AthleteSessionMemoryStore.sessionKey(
            protocolId: 'protocol-1',
            trainingSessionId: 8,
          ),
        ),
      ),
    );

    expect(decision.outcome, ProductionRestoreOutcome.resumable);
    expect(
      (decision.actuals!.blockDrafts.first.resultData as AmrapResultData).rounds,
      4,
    );
    expect(decision.cursor?.activeBlockId, 'amrap');
    expect(decision.cursor?.activeBlockIndex, isNot(99));
  });

  test('sign-out clears in-process memory and envelopes for that athlete', () {
    final store = ProductionRestoreEnvelopeStore();
    store.write(
      const ProductionRestoreEnvelope(
        identity: ProductionSessionDraft(
          schemaVersion: 1,
          athleteId: 'athlete-1',
          assignmentId: 'assign-1',
          programmeVersionId: 'ver-1',
          programmedSessionKey: 'key-1',
          packageContentHash:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          trainingSessionId: 1,
          entryMode: 'live',
        ),
      ),
    );
    store.write(
      const ProductionRestoreEnvelope(
        identity: ProductionSessionDraft(
          schemaVersion: 1,
          athleteId: 'athlete-2',
          assignmentId: 'assign-2',
          programmeVersionId: 'ver-1',
          programmedSessionKey: 'key-2',
          packageContentHash:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
          trainingSessionId: 2,
          entryMode: 'live',
        ),
      ),
    );
    AthleteSessionMemoryStore.instance.write(
      SessionExecutionController(
        plan: const SessionExecutionPlan(
          sessionId: 'p',
          sessionTitle: 'S',
          blocks: [],
        ),
        sessionKey: '1:p',
      ).state,
    );

    store.clearForAthlete('athlete-1');
    AthleteSessionMemoryStore.instance.clearAll();

    expect(store.read(athleteId: 'athlete-1', trainingSessionId: 1), isNull);
    expect(store.read(athleteId: 'athlete-2', trainingSessionId: 2), isNotNull);
    expect(AthleteSessionMemoryStore.instance.read('1:p'), isNull);
  });
}
