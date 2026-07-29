import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/workout_execution_record/workout_execution_record_domain.dart';
import 'package:cohort_platform/domain/workout_player/workout_player_domain.dart';

import '../models/active_performance_draft.dart';
import '../models/training_block_result_status.dart';
import '../models/training_session_record_status.dart';

/// Maps M8 capture drafts into domain [WorkoutExerciseExecutionEntry] lists.
class WorkoutExecutionOutcomeMapper {
  const WorkoutExecutionOutcomeMapper._();

  static List<WorkoutExerciseExecutionEntry> fromDraft({
    required ActivePerformanceDraft draft,
    required AdaptedSessionExecutionSnapshot snapshot,
    required TrainingSessionRecordStatus sessionStatus,
  }) {
    final blockById = {
      for (final block in draft.blockDrafts) block.sourceBlockId: block,
    };

    final steps = WorkoutPlayerNavigation.navigableSteps(snapshot);
    final entries = <WorkoutExerciseExecutionEntry>[];

    for (final step in steps) {
      final blockSnapshot = snapshot.retainedBlocks.firstWhere(
        (block) => block.sourceBlockLocalId == step.sourceBlockLocalId,
      );
      final exerciseSnapshot = blockSnapshot.exercises.firstWhere(
        (exercise) => exercise.exerciseLinkLocalId == step.exerciseLinkLocalId,
      );
      final blockDraft = blockById[step.sourceBlockLocalId];

      entries.add(
        WorkoutExerciseExecutionEntry(
          sourceBlockLocalId: step.sourceBlockLocalId,
          exerciseLinkLocalId: step.exerciseLinkLocalId,
          exerciseId: exerciseSnapshot.exerciseId,
          stepIndex: step.stepIndex,
          outcome: _outcomeForBlock(
            blockStatus: blockDraft?.status,
            sessionStatus: sessionStatus,
          ),
        ),
      );
    }

    return entries;
  }

  static WorkoutExerciseExecutionOutcome _outcomeForBlock({
    required TrainingBlockResultStatus? blockStatus,
    required TrainingSessionRecordStatus sessionStatus,
  }) {
    if (blockStatus == TrainingBlockResultStatus.completed) {
      return WorkoutExerciseExecutionOutcome.completed;
    }
    if (blockStatus == TrainingBlockResultStatus.skipped) {
      return WorkoutExerciseExecutionOutcome.skipped;
    }
    if (sessionStatus == TrainingSessionRecordStatus.completed) {
      return WorkoutExerciseExecutionOutcome.completed;
    }
    return WorkoutExerciseExecutionOutcome.skipped;
  }
}
