/// Stable one-to-one key: assignment + version session slot.
class ProgrammeSessionOccurrenceKey {
  const ProgrammeSessionOccurrenceKey({
    required this.programmeAssignmentId,
    required this.programmeSessionSlotId,
  });

  final String programmeAssignmentId;
  final String programmeSessionSlotId;

  @override
  bool operator ==(Object other) {
    return other is ProgrammeSessionOccurrenceKey &&
        other.programmeAssignmentId == programmeAssignmentId &&
        other.programmeSessionSlotId == programmeSessionSlotId;
  }

  @override
  int get hashCode =>
      Object.hash(programmeAssignmentId, programmeSessionSlotId);

  @override
  String toString() =>
      'ProgrammeSessionOccurrenceKey($programmeAssignmentId,$programmeSessionSlotId)';
}
