import 'session_occurrence.dart';

enum SessionOccurrenceTransitionIssueCode {
  invalidOccurrenceId,
  invalidSourceSessionId,
  invalidLifecycleState,
  terminalState,
  snapshotRequired,
  snapshotSourceMismatch,
  snapshotNotAllowed,
  invalidPlannedDate,
  invalidRescheduleTarget,
  completionTimestampRequired,
}

class SessionOccurrenceTransitionIssue {
  const SessionOccurrenceTransitionIssue({required this.code, this.detail});

  final SessionOccurrenceTransitionIssueCode code;
  final String? detail;
}

class SessionOccurrenceTransitionResult {
  const SessionOccurrenceTransitionResult._({
    required this.isSuccess,
    this.occurrence,
    this.issues = const [],
  });

  final bool isSuccess;
  final SessionOccurrence? occurrence;
  final List<SessionOccurrenceTransitionIssue> issues;

  factory SessionOccurrenceTransitionResult.success(
    SessionOccurrence occurrence,
  ) {
    return SessionOccurrenceTransitionResult._(
      isSuccess: true,
      occurrence: occurrence,
    );
  }

  factory SessionOccurrenceTransitionResult.failure(
    List<SessionOccurrenceTransitionIssue> issues,
  ) {
    return SessionOccurrenceTransitionResult._(
      isSuccess: false,
      issues: List.unmodifiable(issues),
    );
  }

  factory SessionOccurrenceTransitionResult.singleFailure(
    SessionOccurrenceTransitionIssueCode code, {
    String? detail,
  }) {
    return SessionOccurrenceTransitionResult.failure([
      SessionOccurrenceTransitionIssue(code: code, detail: detail),
    ]);
  }
}
