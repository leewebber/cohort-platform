import 'training_session_record.dart';

enum TrainingSessionRecordTransitionIssueCode {
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

class TrainingSessionRecordTransitionIssue {
  const TrainingSessionRecordTransitionIssue({
    required this.code,
    this.detail,
  });

  final TrainingSessionRecordTransitionIssueCode code;
  final String? detail;
}

class TrainingSessionRecordTransitionResult {
  const TrainingSessionRecordTransitionResult._({
    required this.isSuccess,
    this.record,
    this.issues = const [],
  });

  final bool isSuccess;
  final TrainingSessionRecord? record;
  final List<TrainingSessionRecordTransitionIssue> issues;

  factory TrainingSessionRecordTransitionResult.success(
    TrainingSessionRecord record,
  ) {
    return TrainingSessionRecordTransitionResult._(
      isSuccess: true,
      record: record,
    );
  }

  factory TrainingSessionRecordTransitionResult.failure(
    List<TrainingSessionRecordTransitionIssue> issues,
  ) {
    return TrainingSessionRecordTransitionResult._(
      isSuccess: false,
      issues: List.unmodifiable(issues),
    );
  }

  factory TrainingSessionRecordTransitionResult.singleFailure(
    TrainingSessionRecordTransitionIssueCode code, {
    String? detail,
  }) {
    return TrainingSessionRecordTransitionResult.failure([
      TrainingSessionRecordTransitionIssue(code: code, detail: detail),
    ]);
  }
}
