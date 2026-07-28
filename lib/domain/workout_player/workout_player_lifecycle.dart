import 'vocabulary/workout_player_execution_status.dart';
import 'workout_player.dart';
import 'workout_player_transition_result.dart';

/// Pure execution-status transition rules (no side effects).
class WorkoutPlayerLifecycle {
  const WorkoutPlayerLifecycle._();

  static const allowedTransitions = {
    WorkoutPlayerExecutionStatus.ready: {
      WorkoutPlayerExecutionStatus.active,
      WorkoutPlayerExecutionStatus.abandoned,
    },
    WorkoutPlayerExecutionStatus.active: {
      WorkoutPlayerExecutionStatus.paused,
      WorkoutPlayerExecutionStatus.completed,
      WorkoutPlayerExecutionStatus.abandoned,
    },
    WorkoutPlayerExecutionStatus.paused: {
      WorkoutPlayerExecutionStatus.active,
      WorkoutPlayerExecutionStatus.completed,
      WorkoutPlayerExecutionStatus.abandoned,
    },
  };

  static bool canTransition({
    required WorkoutPlayerExecutionStatus from,
    required WorkoutPlayerExecutionStatus to,
  }) {
    if (from.isTerminal) return false;
    final allowed = allowedTransitions[from];
    return allowed?.contains(to) ?? false;
  }

  static WorkoutPlayerTransitionResult requireTransition({
    required WorkoutPlayer player,
    required WorkoutPlayerExecutionStatus target,
  }) {
    if (!canTransition(from: player.executionStatus, to: target)) {
      return WorkoutPlayerTransitionResult.singleFailure(
        WorkoutPlayerTransitionIssueCode.invalidExecutionStatus,
        detail: '${player.executionStatus.name}->${target.name}',
      );
    }
    return WorkoutPlayerTransitionResult.success(player);
  }
}
