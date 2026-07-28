import '../session_occurrence.dart';

enum ProgrammeSessionOccurrenceCreationIssueCode {
  invalidAssignmentId,
  invalidSessionSlotId,
  invalidAthleteId,
  invalidSourceSessionId,
  duplicateSlotOccurrence,
  sourceSessionConflict,
}

class ProgrammeSessionOccurrenceCreationIssue {
  const ProgrammeSessionOccurrenceCreationIssue({
    required this.code,
    this.detail,
  });

  final ProgrammeSessionOccurrenceCreationIssueCode code;
  final String? detail;
}

class ProgrammeSessionOccurrenceCreationResult {
  const ProgrammeSessionOccurrenceCreationResult._({
    required this.isSuccess,
    this.occurrence,
    this.issues = const [],
  });

  final bool isSuccess;
  final SessionOccurrence? occurrence;
  final List<ProgrammeSessionOccurrenceCreationIssue> issues;

  factory ProgrammeSessionOccurrenceCreationResult.success(
    SessionOccurrence occurrence,
  ) {
    return ProgrammeSessionOccurrenceCreationResult._(
      isSuccess: true,
      occurrence: occurrence,
    );
  }

  factory ProgrammeSessionOccurrenceCreationResult.failure(
    List<ProgrammeSessionOccurrenceCreationIssue> issues,
  ) {
    return ProgrammeSessionOccurrenceCreationResult._(
      isSuccess: false,
      issues: List.unmodifiable(issues),
    );
  }

  factory ProgrammeSessionOccurrenceCreationResult.singleFailure(
    ProgrammeSessionOccurrenceCreationIssueCode code, {
    String? detail,
  }) {
    return ProgrammeSessionOccurrenceCreationResult.failure([
      ProgrammeSessionOccurrenceCreationIssue(code: code, detail: detail),
    ]);
  }
}
