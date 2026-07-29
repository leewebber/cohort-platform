import '../../session/models/session_execution_plan.dart';
import '../models/workout_player_exercise_step.dart';

/// Flattens [SessionExecutionPlan] blocks into ordered athlete exercise steps.
class WorkoutPlayerPlanFlattener {
  const WorkoutPlayerPlanFlattener();

  List<WorkoutPlayerExerciseStep> flatten(SessionExecutionPlan plan) {
    final steps = <WorkoutPlayerExerciseStep>[];
    for (final block in plan.blocks) {
      for (final exercise in block.linkedExercises) {
        final sets = exercise.prescription?.sets;
        steps.add(
          WorkoutPlayerExerciseStep(
            stepIndex: steps.length,
            blockId: block.blockId,
            blockTitle: block.title,
            exercise: exercise,
            totalSets: (sets == null || sets <= 0) ? 1 : sets,
          ),
        );
      }
    }
    return steps;
  }
}
