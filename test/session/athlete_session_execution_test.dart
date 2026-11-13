import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/models/session_execution_status.dart';
import 'package:cohort_platform/features/session/services/block_timer_controller.dart';
import 'package:cohort_platform/features/session/services/protocol_step_to_block_converter.dart';
import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/services/session_finish_eligibility.dart';
import 'package:cohort_platform/models/protocol_step.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/timer_configuration.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProtocolStepToBlockConverter', () {
    test('legacy steps become one executable block plan shape', () {
      const converter = ProtocolStepToBlockConverter();
      final blocks = converter.convertStepsToBlocks(const [
        ProtocolStep(
          id: 1,
          protocolId: 'session-1',
          stepOrder: 1,
          section: 'Main',
          stepType: 'Exercise',
          displayStyle: 'exercise',
          title: 'Warm-up row',
          metadata: {},
          notes: 'Easy pace',
        ),
      ]);

      expect(blocks, hasLength(1));
      final execution = SessionExecutionBlock.fromSessionBlock(
        blocks.first,
        exercisesById: const {},
      );
      expect(execution.title, 'Session');
      expect(execution.content, contains('Warm-up row'));
      expect(execution.blockId, isNotEmpty);
    });
  });

  group('SessionExecutionController', () {
    test('start selects first block and marks in progress', () {
      final controller = SessionExecutionController(
        plan: _samplePlan(),
        sessionKey: 'test-1:session-1',
        memoryStore: AthleteSessionMemoryStore.instance,
      );

      controller.startSession();

      expect(controller.state.sessionStatus, SessionExecutionStatus.inProgress);
      expect(controller.state.activeBlockIndex, 0);
      expect(controller.state.startedAt, isNotNull);
    });

    test('mark complete advances without auto-completing skipped blocks', () {
      final controller = SessionExecutionController(
        plan: _samplePlan(),
        sessionKey: 'test-2:session-1',
        memoryStore: AthleteSessionMemoryStore.instance,
      )..startSession();

      final firstId = controller.state.plan.blocks.first.blockId;
      controller.markBlockComplete(firstId);

      expect(controller.state.completedBlockIds, contains(firstId));
      expect(controller.state.activeBlockIndex, 1);
    });

    test('skip forward does not mark previous blocks complete', () {
      final controller = SessionExecutionController(
        plan: _samplePlan(),
        sessionKey: 'test-3:session-1',
        memoryStore: AthleteSessionMemoryStore.instance,
      )..startSession();

      controller.goToNextBlock();

      expect(controller.state.completedBlockIds, isEmpty);
      expect(controller.state.activeBlockIndex, 1);
    });

    test('cold restore reconciles durable completed and active blocks', () {
      final controller = SessionExecutionController(
        plan: _samplePlan(),
        sessionKey: 'test-restore:session-1',
        memoryStore: AthleteSessionMemoryStore.instance,
      );

      controller.restoreFromDurableDraft(
        completedBlockIds: {'block-1'},
        activeBlockId: 'block-2',
      );

      expect(controller.state.sessionStatus, SessionExecutionStatus.inProgress);
      expect(controller.state.completedBlockIds, {'block-1'});
      expect(controller.state.activeBlock?.blockId, 'block-2');
      expect(controller.state.expandedBlockIds, {'block-2'});
    });
  });

  group('SessionFinishEligibilityEvaluator', () {
    test('disables finish at zero of two blocks with a useful reason', () {
      final plan = _samplePlan();
      final performance =
          PerformanceCaptureController.initializeFromExecutionPlan(
            plan: plan,
            athleteId: 'athlete',
            trainingSessionId: 1,
          );

      final result = const SessionFinishEligibilityEvaluator().evaluate(
        incompleteBlockCount: 2,
        performanceDraft: performance.draft,
      );

      expect(result.canFinish, isFalse);
      expect(result.reason, 'Complete 2 remaining blocks');
    });

    test('finish early keeps the authored running review gate separate', () {
      final controller =
          PerformanceCaptureController.initializeFromExecutionPlan(
            plan: _samplePlan(),
            athleteId: 'athlete',
            trainingSessionId: 1,
          )..markBlockComplete('block-1');
      const programmeContext = ProgrammeExecutionContext(
        assignmentId: 'assignment-1',
        programmeVersionId: 'version-1',
        sessionSlotId: 'slot-1',
        weekNumber: 1,
        dayKey: 'day_1',
        sessionOrder: 1,
        plannedProtocolId: 'session-1',
        effectiveProtocolId: 'session-1',
        occurrenceId: 'occurrence-1',
        packageSchemaVersion: 2,
      );
      const evaluator = SessionFinishEligibilityEvaluator();
      expect(
        evaluator
            .evaluateEarly(
              controller: controller,
              programmeContext: programmeContext,
            )
            .canFinish,
        isTrue,
      );

      final draft = controller.draft;
      final unfinished = draft.blockDrafts.last;
      final running = PerformanceCaptureController(
        draft: draft.copyWith(
          blockDrafts: [
            draft.blockDrafts.first,
            unfinished.copyWith(
              blockSnapshot: BlockPerformanceSnapshot.fromJson({
                ...unfinished.blockSnapshot.toJson(),
                'timedRunningWorkoutV1': {'steps': []},
              }),
            ),
          ],
        ),
      );
      expect(
        evaluator
            .evaluateEarly(
              controller: running,
              programmeContext: programmeContext,
            )
            .canFinish,
        isFalse,
      );
    });
  });

  group('BlockTimerController', () {
    test('AMRAP counts down', () async {
      BlockTimerState? latest;
      final controller = BlockTimerController(
        format: WorkoutFormat.amrap,
        configuration: const TimerConfiguration(durationSeconds: 3),
        onStateChanged: (state) => latest = state,
      );

      controller.start();
      expect(latest?.primarySeconds, 3);

      await Future<void>.delayed(const Duration(seconds: 2));
      expect(latest?.primarySeconds, lessThan(3));
      controller.dispose();
    });

    test('invalid config handled safely for EMOM', () {
      BlockTimerState? latest;
      final controller = BlockTimerController(
        format: WorkoutFormat.emom,
        configuration: const TimerConfiguration(),
        onStateChanged: (state) => latest = state,
      );

      controller.start();
      expect(latest, isNotNull);
      controller.dispose();
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
        title: 'Strength',
        blockType: SessionBlockType.strength,
        content: 'Back squat 5 x 5',
        workoutFormat: WorkoutFormat.none,
        position: 2,
      ),
    ],
  );
}
