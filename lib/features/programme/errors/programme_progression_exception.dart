/// Typed programme progression failure.
class ProgrammeProgressionException implements Exception {
  ProgrammeProgressionException(
    this.code,
    this.message, {
    this.details,
  });

  final ProgrammeProgressionErrorCode code;
  final String message;
  final String? details;

  @override
  String toString() => 'ProgrammeProgressionException($code): $message';
}

enum ProgrammeProgressionErrorCode {
  missingSlotContext,
  missingAssignment,
  outcomePersistenceFailed,
  assignmentUpdateFailed,
  athleteStateSyncFailed,
  staleResolution,
  invalidOutcomeTransition,
}
