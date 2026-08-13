import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/mappers/performance_record_mapper.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/performance_record_store.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'strength, circuit, and interval actuals persist athlete-entered values',
    () {
      final controller =
          PerformanceCaptureController.initializeFromExecutionPlan(
            plan: _multiBlockPlan(),
            athleteId: 'athlete-1',
            trainingSessionId: 42,
          );

      controller.addSet('strength', 'exercise-1');
      final setId = controller
          .draft
          .blockDrafts
          .first
          .exerciseResults
          .first
          .sets
          .single
          .setResultId;
      controller.updateSet(
        'strength',
        'exercise-1',
        setId,
        (set) => set.copyWith(reps: 5, load: 100, completed: true),
      );
      controller
        ..updateBlockResultData(
          'circuit',
          const RoundsResultData(
            roundsCompleted: 4,
            extraReps: 2,
            entered: true,
          ),
        )
        ..updateBlockResultData(
          'interval',
          const IntervalResultData(
            intervalsCompleted: 8,
            totalIntervals: 8,
            entered: true,
          ),
        )
        ..markBlockComplete('strength')
        ..markBlockComplete('circuit')
        ..markBlockComplete('interval');

      expect(controller.validateForCompletion().isValid, isTrue);

      final record = const PerformanceRecordMapper().fromDraft(
        controller.buildPersistableDraft(
          status: TrainingSessionRecordStatus.completed,
        ),
      );
      final strengthSet =
          record.blockResults[0].exerciseResults.single.setResults.single;
      final circuit = record.blockResults[1].resultData! as RoundsResultData;
      final interval = record.blockResults[2].resultData! as IntervalResultData;

      expect(strengthSet.reps, 5);
      expect(strengthSet.load, 100);
      expect(strengthSet.completed, isTrue);
      expect(circuit.roundsCompleted, 4);
      expect(circuit.extraReps, 2);
      expect(interval.intervalsCompleted, 8);

      // Authored prescription remains a snapshot, never copied into actuals.
      expect(record.blockResults.first.blockSnapshot.content, contains('10'));
      expect(strengthSet.reps, isNot(10));
      expect(strengthSet.load, isNot(80));
    },
  );

  test('completed strength block without entered performed set is invalid', () {
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _multiBlockPlan(),
      athleteId: 'athlete-1',
      trainingSessionId: 42,
    )..markBlockComplete('strength');

    final validation = controller.validateForCompletion();

    expect(validation.isValid, isFalse);
    expect(
      validation.fieldErrors.values,
      contains(
        'Enter and complete at least one performed set with actual reps.',
      ),
    );
  });

  test('completed endurance block requires entered distance or duration', () {
    const plan = SessionExecutionPlan(
      sessionId: 'protocol-endurance',
      sessionTitle: 'Endurance',
      blocks: [
        SessionExecutionBlock(
          blockId: 'endurance',
          title: 'Run',
          blockType: SessionBlockType.conditioning,
          content: 'Distance: authored',
          workoutFormat: WorkoutFormat.none,
          position: 1,
        ),
      ],
    );
    final controller = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: plan,
      athleteId: 'athlete-1',
      trainingSessionId: 43,
    )..markBlockComplete('endurance');

    expect(controller.validateForCompletion().isValid, isFalse);
    expect(
      controller.validateForCompletion().fieldErrors.values,
      contains(
        'Enter performed distance or duration before completing this block.',
      ),
    );
  });

  test('untouched circuit and interval defaults are not athlete actuals', () {
    final controller =
        PerformanceCaptureController.initializeFromExecutionPlan(
            plan: _multiBlockPlan(),
            athleteId: 'athlete-1',
            trainingSessionId: 45,
          )
          ..markBlockComplete('circuit')
          ..markBlockComplete('interval');

    final validation = controller.validateForCompletion();

    expect(validation.isValid, isFalse);
    expect(
      validation.fieldErrors.values,
      contains('Enter performed rounds or reps before completing this block.'),
    );
    expect(
      validation.fieldErrors.values,
      contains('Enter completed intervals before completing this block.'),
    );
  });

  test(
    'incomplete programme evidence cannot reach completion authority',
    () async {
      final controller =
          PerformanceCaptureController.initializeFromExecutionPlan(
            plan: _multiBlockPlan(),
            athleteId: 'athlete-1',
            trainingSessionId: 44,
          );

      await expectLater(
        PerformanceRecordSaveCoordinator().completeSession(
          controller: controller,
          trainingSessionId: 44,
          athleteId: 'athlete-1',
          programmeContext: const ProgrammeExecutionContext(
            assignmentId: 'assignment-1',
            programmeVersionId: 'version-1',
            sessionSlotId: 'slot-1',
            weekNumber: 1,
            dayKey: 'day_1',
            sessionOrder: 1,
            plannedProtocolId: 'protocol-1',
            effectiveProtocolId: 'protocol-1',
            packageContentHash: 'hash-1',
            programmedSessionKey:
                'prog:assignment-1@version-1:w1:day_1:s1:protocol-1',
          ),
        ),
        throwsA(
          isA<PerformanceRecordStoreException>().having(
            (error) => error.message,
            'message',
            contains('Complete every required programme block'),
          ),
        ),
      );
    },
  );
}

SessionExecutionPlan _multiBlockPlan() {
  return const SessionExecutionPlan(
    sessionId: 'protocol-1',
    sessionTitle: 'Authored session',
    blocks: [
      SessionExecutionBlock(
        blockId: 'strength',
        title: 'Strength',
        blockType: SessionBlockType.strength,
        content: 'Sets: 3\nReps: 10\nLoad: 80 kg',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'exercise-1',
            displayName: 'Movement',
          ),
        ],
      ),
      SessionExecutionBlock(
        blockId: 'circuit',
        title: 'Circuit',
        blockType: SessionBlockType.conditioning,
        content: 'Complete the authored circuit.',
        workoutFormat: WorkoutFormat.rounds,
        position: 2,
      ),
      SessionExecutionBlock(
        blockId: 'interval',
        title: 'Intervals',
        blockType: SessionBlockType.conditioning,
        content: 'Complete the authored intervals.',
        workoutFormat: WorkoutFormat.intervals,
        position: 3,
      ),
    ],
  );
}
