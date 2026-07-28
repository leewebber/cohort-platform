import '../value_objects/session_occurrence_date.dart';
import 'programme_session_occurrence_key.dart';

/// Normalized schedule input from the programme engine (no template traversal here).
class ProgrammeScheduledSlotInput {
  const ProgrammeScheduledSlotInput({
    required this.programmeAssignmentId,
    required this.programmeSessionSlotId,
    required this.athleteId,
    required this.sourceSessionId,
    required this.plannedDate,
  });

  final String programmeAssignmentId;
  final String programmeSessionSlotId;
  final String athleteId;
  final String sourceSessionId;
  final SessionOccurrenceDate plannedDate;

  ProgrammeSessionOccurrenceKey get slotKey => ProgrammeSessionOccurrenceKey(
        programmeAssignmentId: programmeAssignmentId,
        programmeSessionSlotId: programmeSessionSlotId,
      );
}
