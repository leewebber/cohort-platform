import '../value_objects/session_occurrence_date.dart';

/// Lookup key: athlete calendar day (uses occurrence [SessionOccurrence.currentDate]).
class AthleteSessionDayKey {
  const AthleteSessionDayKey({
    required this.athleteId,
    required this.calendarDate,
  });

  final String athleteId;
  final SessionOccurrenceDate calendarDate;

  @override
  bool operator ==(Object other) {
    return other is AthleteSessionDayKey &&
        other.athleteId == athleteId &&
        other.calendarDate == calendarDate;
  }

  @override
  int get hashCode => Object.hash(athleteId, calendarDate);
}
