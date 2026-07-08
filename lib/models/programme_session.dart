class ProgrammeSession {
  final int id;
  final String programmeId;
  final int weekNumber;
  final String day;
  final String protocolId;
  final int sessionOrder;

  const ProgrammeSession({
    required this.id,
    required this.programmeId,
    required this.weekNumber,
    required this.day,
    required this.protocolId,
    required this.sessionOrder,
  });

  factory ProgrammeSession.fromMap(Map<String, dynamic> map) {
    return ProgrammeSession(
      id: map['id'],
      programmeId: map['programme_id'] ?? '',
      weekNumber: map['week_number'] ?? 0,
      day: map['day'] ?? '',
      protocolId: map['protocol_id'] ?? '',
      sessionOrder: map['session_order'] ?? 1,
    );
  }
}