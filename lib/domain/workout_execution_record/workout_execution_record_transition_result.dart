import 'workout_execution_record.dart';

enum WorkoutExecutionRecordTransitionIssueCode {
  invalidRecordId,
  invalidOccurrenceId,
  invalidLifecycleStatus,
  terminalState,
  invalidTimestamp,
  unknownExercise,
  duplicateExerciseEntry,
  playerNotTerminal,
  playerMissingStartedAt,
  snapshotPlayerMismatch,
}

class WorkoutExecutionRecordTransitionIssue {
  const WorkoutExecutionRecordTransitionIssue({
    required this.code,
    this.detail,
  });

  final WorkoutExecutionRecordTransitionIssueCode code;
  final String? detail;
}

class WorkoutExecutionRecordTransitionResult {
  const WorkoutExecutionRecordTransitionResult._({
    required this.isSuccess,
    this.record,
    this.issues = const [],
  });

  final bool isSuccess;
  final WorkoutExecutionRecord? record;
  final List<WorkoutExecutionRecordTransitionIssue> issues;

  factory WorkoutExecutionRecordTransitionResult.success(
    WorkoutExecutionRecord record,
  ) {
    return WorkoutExecutionRecordTransitionResult._(
      isSuccess: true,
      record: record,
    );
  }

  factory WorkoutExecutionRecordTransitionResult.failure(
    List<WorkoutExecutionRecordTransitionIssue> issues,
  ) {
    return WorkoutExecutionRecordTransitionResult._(
      isSuccess: false,
      issues: List.unmodifiable(issues),
    );
  }

  factory WorkoutExecutionRecordTransitionResult.singleFailure(
    WorkoutExecutionRecordTransitionIssueCode code, {
    String? detail,
  }) {
    return WorkoutExecutionRecordTransitionResult.failure([
      WorkoutExecutionRecordTransitionIssue(code: code, detail: detail),
    ]);
  }
}
