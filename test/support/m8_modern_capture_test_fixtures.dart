import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/active_performance_draft.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';

class M8ModernCaptureTestFixtures {
  const M8ModernCaptureTestFixtures._();

  static SessionExecutionPlan singleBlockPlan() {
    return SessionExecutionPlan(
      sessionId: 'm8-modern-capture-test',
      sessionTitle: 'M8 Modern Capture Test',
      blocks: const [
        SessionExecutionBlock(
          blockId: 'block-warmup',
          title: 'Warm-up',
          blockType: SessionBlockType.warmUp,
          content: 'Easy row and mobility',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          performanceCaptureMode: BlockPerformanceCaptureMode.completion,
        ),
      ],
    );
  }

  static SessionExecutionPlan fullCapturePlan() {
    return SessionExecutionPlan(
      sessionId: 'm8-modern-capture-test',
      sessionTitle: 'M8 Modern Capture Test',
      blocks: const [
        SessionExecutionBlock(
          blockId: 'block-warmup',
          title: 'Warm-up',
          blockType: SessionBlockType.warmUp,
          content: 'Easy row and mobility',
          workoutFormat: WorkoutFormat.none,
          position: 1,
          performanceCaptureMode: BlockPerformanceCaptureMode.completion,
        ),
        SessionExecutionBlock(
          blockId: 'block-strength',
          title: 'Strength',
          blockType: SessionBlockType.strength,
          content: 'Back squat and bench press',
          workoutFormat: WorkoutFormat.none,
          position: 2,
          performanceCaptureMode: BlockPerformanceCaptureMode.strength,
          linkedExercises: [
            SessionExecutionExerciseSummary(
              exerciseId: 'SQ-001',
              displayName: 'Back Squat',
            ),
            SessionExecutionExerciseSummary(
              exerciseId: 'BP-001',
              displayName: 'Bench Press',
            ),
          ],
        ),
        SessionExecutionBlock(
          blockId: 'block-run',
          title: 'Threshold Run',
          blockType: SessionBlockType.conditioning,
          content: '30 min threshold pace',
          workoutFormat: WorkoutFormat.none,
          position: 3,
          performanceCaptureMode: BlockPerformanceCaptureMode.endurance,
        ),
        SessionExecutionBlock(
          blockId: 'block-amrap',
          title: 'AMRAP',
          blockType: SessionBlockType.conditioning,
          content: '12 min AMRAP burpees',
          workoutFormat: WorkoutFormat.amrap,
          position: 4,
          performanceCaptureMode: BlockPerformanceCaptureMode.amrap,
        ),
        SessionExecutionBlock(
          blockId: 'block-cooldown',
          title: 'Cool-down',
          blockType: SessionBlockType.coolDown,
          content: 'Easy spin',
          workoutFormat: WorkoutFormat.none,
          position: 5,
          performanceCaptureMode: BlockPerformanceCaptureMode.completion,
        ),
      ],
    );
  }

  static SessionExecutionController executionController(
    SessionExecutionPlan plan,
  ) {
    return SessionExecutionController(
      plan: plan,
      sessionKey: 'm8-fixture:${plan.sessionId}',
      memoryStore: AthleteSessionMemoryStore.instance,
    );
  }

  static PerformanceCaptureController performanceController(
    SessionExecutionPlan plan,
  ) {
    return PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'founder-test-athlete',
      trainingSessionId: 9001,
    );
  }

  static BlockPerformanceDraft completionBlockDraft() {
    final controller = performanceController(singleBlockPlan());
    return controller.draft.blockDrafts.first;
  }
}
