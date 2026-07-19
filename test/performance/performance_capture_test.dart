import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/performance/services/performance_validation_service.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PerformanceResultData', () {
    test('round trips through JSON codec', () {
      const original = AmrapResultData(rounds: 12, extraReps: 7, note: 'Hard');
      final decoded = PerformanceResultData.fromJson(original.toJson());
      expect(decoded, isA<AmrapResultData>());
      expect((decoded as AmrapResultData).rounds, 12);
      expect(decoded.extraReps, 7);
    });
  });

  group('PerformanceCaptureController', () {
    test('initialises block drafts from execution plan', () {
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _samplePlan(),
        athleteId: 'lee',
        trainingSessionId: 42,
      );

      expect(controller.draft.blockDrafts, hasLength(2));
      expect(controller.draft.blockDrafts.first.resultData, isA<CompletionResultData>());
    });

    test('markBlockComplete preserves entered set data on reopen', () {
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _strengthPlan(),
        athleteId: 'lee',
        trainingSessionId: 43,
      );
      final blockId = controller.draft.blockDrafts.first.sourceBlockId;
      final exerciseId =
          controller.draft.blockDrafts.first.exerciseResults.first.sourceExerciseId;

      controller
        ..addSet(blockId, exerciseId)
        ..updateSet(
          blockId,
          exerciseId,
          controller.draft.blockDrafts.first.exerciseResults.first.sets.first.setResultId,
          (set) => set.copyWith(reps: 5, load: 100, completed: true),
        )
        ..markBlockComplete(blockId)
        ..reopenBlock(blockId);

      final set = controller.draft.blockDrafts.first.exerciseResults.first.sets.first;
      expect(set.reps, 5);
      expect(set.load, 100);
      expect(
        controller.draft.blockDrafts.first.status,
        TrainingBlockResultStatus.inProgress,
      );
    });

    test('partial completion when a block is skipped', () {
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _samplePlan(),
        athleteId: 'lee',
        trainingSessionId: 44,
      );

      final first = controller.draft.blockDrafts.first.sourceBlockId;
      controller
        ..markBlockComplete(first)
        ..markBlockSkipped(controller.draft.blockDrafts.last.sourceBlockId);

      expect(
        controller.resolveCompletionStatus(),
        TrainingSessionRecordStatus.partiallyCompleted,
      );
    });
  });

  group('PerformanceRecordSaveCoordinator', () {
    test('createOrResume prevents duplicate in-progress records', () async {
      final store = InMemoryPerformanceRecordStore();
      final coordinator = PerformanceRecordSaveCoordinator(store: store);
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _samplePlan(),
        athleteId: 'lee',
        trainingSessionId: 100,
      );

      final first = await coordinator.createOrResumeInProgress(controller: controller);
      final second = await coordinator.createOrResumeInProgress(controller: controller);

      expect(first.recordId, second.recordId);
      final history = await store.listHistory(athleteId: 'lee');
      expect(history, isEmpty);
    });

    test('store completeRecord is idempotent', () async {
      final store = InMemoryPerformanceRecordStore();
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _samplePlan(),
        athleteId: 'lee',
        trainingSessionId: 101,
      );

      for (final block in controller.draft.blockDrafts) {
        controller.markBlockComplete(block.sourceBlockId);
      }

      final draft = controller.buildPersistableDraft(
        status: TrainingSessionRecordStatus.completed,
      );
      final first = await store.completeRecord(draft);
      final second = await store.completeRecord(draft);

      expect(first.recordId, second.recordId);
      final history = await store.listHistory(athleteId: 'lee');
      expect(history, hasLength(1));
    });
  });

  group('PerformanceValidationService', () {
    test('rejects invalid session RPE', () {
      final controller = PerformanceCaptureController.initializeFromExecutionPlan(
        plan: _samplePlan(),
        athleteId: 'lee',
        trainingSessionId: 102,
      )..updateSessionRpe(11);

      final result = const PerformanceValidationService().validateForCompletion(
        controller.draft,
      );
      expect(result.isValid, isFalse);
      expect(result.fieldErrors.containsKey('overallRpe'), isTrue);
    });
  });
}

SessionExecutionPlan _samplePlan() {
  return SessionExecutionPlan(
    sessionId: 'session-1',
    sessionTitle: 'Morning Session',
    blocks: const [
      SessionExecutionBlock(
        blockId: 'block-1',
        title: 'Warm-up',
        blockType: SessionBlockType.warmUp,
        content: 'Row 500 m',
        workoutFormat: WorkoutFormat.none,
        position: 1,
      ),
      SessionExecutionBlock(
        blockId: 'block-2',
        title: 'Conditioning',
        blockType: SessionBlockType.conditioning,
        content: '12 min AMRAP burpees',
        workoutFormat: WorkoutFormat.amrap,
        position: 2,
      ),
    ],
  );
}

SessionExecutionPlan _strengthPlan() {
  return SessionExecutionPlan(
    sessionId: 'session-2',
    sessionTitle: 'Strength Session',
    blocks: [
      SessionExecutionBlock(
        blockId: 'block-strength',
        title: 'Strength',
        blockType: SessionBlockType.strength,
        content: 'Back squat 5 x 5',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: const [
          SessionExecutionExerciseSummary(
            exerciseId: 'SQ-001',
            displayName: 'Back Squat',
          ),
        ],
      ),
    ],
  );
}
