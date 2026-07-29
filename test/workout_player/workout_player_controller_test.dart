import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/controllers/workout_player_controller.dart';
import 'package:cohort_platform/features/workout_player/models/workout_player_state.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/features/workout_player/services/workout_player_plan_flattener.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter_test/flutter_test.dart';

SessionExecutionPlan _samplePlan() {
  return SessionExecutionPlan(
    sessionId: 'plan.test',
    sessionTitle: 'Engine Session',
    durationMin: 45,
    coachNotes: 'Stay tall.',
    blocks: [
      SessionExecutionBlock(
        blockId: 'block_1',
        title: 'Primary work',
        blockType: SessionBlockType.strength,
        content: 'Squat work',
        workoutFormat: WorkoutFormat.none,
        position: 1,
        linkedExercises: [
          SessionExecutionExerciseSummary(
            exerciseId: 'ex.squat',
            displayName: 'Back Squat',
            prescription: StrengthExercisePrescription(
              sets: 3,
              reps: StrengthRepPrescription.exact(5),
              restSeconds: 90,
              coachCue: 'Brace before you descend.',
              load: const StrengthLoadPrescription(
                type: StrengthLoadType.rpe,
                rpe: 7,
              ),
            ),
          ),
          SessionExecutionExerciseSummary(
            exerciseId: 'ex.hinge',
            displayName: 'Romanian Deadlift',
            prescription: StrengthExercisePrescription(
              sets: 2,
              reps: StrengthRepPrescription.range(min: 8, max: 10),
              restSeconds: 75,
            ),
          ),
        ],
      ),
    ],
  );
}

void main() {
  test('flattener expands linked exercises without inventing content', () {
    final steps = const WorkoutPlayerPlanFlattener().flatten(_samplePlan());
    expect(steps, hasLength(2));
    expect(steps[0].name, 'Back Squat');
    expect(steps[0].totalSets, 3);
    expect(steps[0].coachingCues, 'Brace before you descend.');
    expect(steps[1].name, 'Romanian Deadlift');
    expect(steps[1].totalSets, 2);
  });

  test('controller advances sets and completes session', () {
    final controller = WorkoutPlayerController(
      plan: _samplePlan(),
      brief: const WorkoutSessionBrief(
        sessionName: 'Engine Session',
        objective: 'Build lower-body strength',
        estimatedDurationMinutes: 45,
        primaryFocus: 'Squat strength',
        trainingIntent: 'Strength',
      ),
    );

    controller.startSession();
    expect(controller.state.phase, WorkoutPlayerPhase.active);
    expect(controller.state.currentSet, 1);

    controller.completeSet();
    controller.completeSet();
    controller.completeSet();
    expect(controller.state.currentExerciseIndex, 1);
    expect(controller.state.currentSet, 1);

    controller.completeSet();
    controller.completeSet();
    expect(controller.state.phase, WorkoutPlayerPhase.complete);
    expect(controller.state.completedExerciseCount, 2);
    expect(controller.state.toPersistenceMap()['phase'], 'complete');

    controller.dispose();
  });
}
