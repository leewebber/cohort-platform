import 'programme_session_occurrence_key.dart';

/// Deterministic occurrence id for programme slot materialization.
class SessionOccurrenceId {
  const SessionOccurrenceId._();

  static String forProgrammeSlot(ProgrammeSessionOccurrenceKey key) {
    return 'pso:${key.programmeAssignmentId}:${key.programmeSessionSlotId}';
  }
}
