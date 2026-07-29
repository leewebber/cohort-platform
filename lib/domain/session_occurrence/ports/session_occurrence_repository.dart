import '../session_occurrence.dart';
import '../value_objects/session_occurrence_date.dart';

/// Persistence port for athlete calendar occurrences (domain contract).
abstract interface class SessionOccurrenceRepository {
  List<SessionOccurrence> occurrencesOnDay({
    required String athleteId,
    required SessionOccurrenceDate calendarDate,
  });

  void register({
    required String athleteId,
    required SessionOccurrence occurrence,
  });

  void upsert({
    required String athleteId,
    required SessionOccurrence occurrence,
  });
}
