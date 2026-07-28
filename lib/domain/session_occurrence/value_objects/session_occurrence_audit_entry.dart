enum SessionOccurrenceAuditEventType {
  scheduled,
  adaptationAttached,
  adaptationReplaced,
  started,
  completed,
  skipped,
  cancelled,
  rescheduled,
  notesUpdated,
  currentDateUpdated,
}

class SessionOccurrenceAuditEntry {
  const SessionOccurrenceAuditEntry({
    required this.eventType,
    required this.recordedAt,
    this.detail,
  });

  final SessionOccurrenceAuditEventType eventType;
  final DateTime recordedAt;
  final String? detail;

  @override
  bool operator ==(Object other) {
    return other is SessionOccurrenceAuditEntry &&
        other.eventType == eventType &&
        other.recordedAt == recordedAt &&
        other.detail == detail;
  }

  @override
  int get hashCode => Object.hash(eventType, recordedAt, detail);
}
