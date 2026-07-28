import 'workout_player.dart';

enum WorkoutPlayerTransitionIssueCode {
  invalidPlayerId,
  invalidOccurrenceId,
  invalidExecutionStatus,
  terminalState,
  snapshotRequired,
  emptyWorkout,
  invalidPosition,
  navigationBoundary,
  occurrenceNotInProgress,
  snapshotOccurrenceMismatch,
}

class WorkoutPlayerTransitionIssue {
  const WorkoutPlayerTransitionIssue({
    required this.code,
    this.detail,
  });

  final WorkoutPlayerTransitionIssueCode code;
  final String? detail;
}

class WorkoutPlayerTransitionResult {
  const WorkoutPlayerTransitionResult._({
    required this.isSuccess,
    this.player,
    this.issues = const [],
  });

  final bool isSuccess;
  final WorkoutPlayer? player;
  final List<WorkoutPlayerTransitionIssue> issues;

  factory WorkoutPlayerTransitionResult.success(WorkoutPlayer player) {
    return WorkoutPlayerTransitionResult._(
      isSuccess: true,
      player: player,
    );
  }

  factory WorkoutPlayerTransitionResult.failure(
    List<WorkoutPlayerTransitionIssue> issues,
  ) {
    return WorkoutPlayerTransitionResult._(
      isSuccess: false,
      issues: List.unmodifiable(issues),
    );
  }

  factory WorkoutPlayerTransitionResult.singleFailure(
    WorkoutPlayerTransitionIssueCode code, {
    String? detail,
  }) {
    return WorkoutPlayerTransitionResult.failure([
      WorkoutPlayerTransitionIssue(code: code, detail: detail),
    ]);
  }
}
