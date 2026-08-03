/// Stable authored identity for a scheduled programme occurrence.
///
/// Date, display label, and collection index are never part of identity.
class ScheduledOccurrenceIdentity {
  const ScheduledOccurrenceIdentity({
    required this.assignmentId,
    required this.programmeVersionId,
    required this.packageContentHash,
    required this.sessionSlotId,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
    required this.protocolId,
    required this.programmedSessionKey,
  });

  final String assignmentId;
  final String programmeVersionId;
  final String packageContentHash;
  final String sessionSlotId;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
  final String protocolId;

  /// Programme-shaped [ProgrammedSessionKey.value] — not a date.
  final String programmedSessionKey;

  /// Authored-order sort key: week, day ordinal from dayKey, session order.
  int get authoredOrderKey {
    final dayMatch = RegExp(r'day_(\d+)').firstMatch(dayKey);
    final dayOrdinal = dayMatch == null
        ? weekNumber * 100
        : int.parse(dayMatch.group(1)!);
    return (weekNumber * 1_000_000) + (dayOrdinal * 1_000) + sessionOrder;
  }

  Map<String, Object?> toCanonicalMap() => {
    'assignmentId': assignmentId,
    'programmeVersionId': programmeVersionId,
    'packageContentHash': packageContentHash,
    'sessionSlotId': sessionSlotId,
    'weekNumber': weekNumber,
    'dayKey': dayKey,
    'sessionOrder': sessionOrder,
    'protocolId': protocolId,
    'programmedSessionKey': programmedSessionKey,
  };

  @override
  bool operator ==(Object other) {
    return other is ScheduledOccurrenceIdentity &&
        other.assignmentId == assignmentId &&
        other.programmeVersionId == programmeVersionId &&
        other.packageContentHash == packageContentHash &&
        other.sessionSlotId == sessionSlotId &&
        other.weekNumber == weekNumber &&
        other.dayKey == dayKey &&
        other.sessionOrder == sessionOrder &&
        other.protocolId == protocolId &&
        other.programmedSessionKey == programmedSessionKey;
  }

  @override
  int get hashCode => Object.hash(
    assignmentId,
    programmeVersionId,
    packageContentHash,
    sessionSlotId,
    weekNumber,
    dayKey,
    sessionOrder,
    protocolId,
    programmedSessionKey,
  );
}
