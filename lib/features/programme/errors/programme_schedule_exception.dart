/// Typed schedule resolution failure.
class ProgrammeScheduleException implements Exception {
  ProgrammeScheduleException(
    this.code,
    this.message, {
    this.details,
  });

  final ProgrammeScheduleErrorCode code;
  final String message;
  final String? details;

  @override
  String toString() => 'ProgrammeScheduleException($code): $message';
}

enum ProgrammeScheduleErrorCode {
  emptyProgrammeStructure,
  missingCurrentWeek,
  missingCurrentDay,
  duplicateDayKey,
  duplicateSlotOrder,
  slotOutsideVersionTree,
  malformedAssignmentCursor,
  slotOutcomeOutsideVersionTree,
}
