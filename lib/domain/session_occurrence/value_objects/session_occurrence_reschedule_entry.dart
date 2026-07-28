import 'session_occurrence_date.dart';

/// Record of a calendar move without implementing scheduling logic.
class SessionOccurrenceRescheduleEntry {
  const SessionOccurrenceRescheduleEntry({
    required this.fromDate,
    required this.toDate,
    required this.recordedAt,
    this.reason,
  });

  final SessionOccurrenceDate fromDate;
  final SessionOccurrenceDate toDate;
  final DateTime recordedAt;
  final String? reason;

  @override
  bool operator ==(Object other) {
    return other is SessionOccurrenceRescheduleEntry &&
        other.fromDate == fromDate &&
        other.toDate == toDate &&
        other.recordedAt == recordedAt &&
        other.reason == reason;
  }

  @override
  int get hashCode => Object.hash(fromDate, toDate, recordedAt, reason);
}
