import '../session_occurrence.dart';
import '../value_objects/session_occurrence_date.dart';
import 'athlete_session_day_key.dart';

/// Read-only index of occurrences by athlete and calendar day (in-memory).
class AthleteSessionOccurrenceIndex {
  AthleteSessionOccurrenceIndex({
    Map<AthleteSessionDayKey, List<SessionOccurrence>>? seed,
  }) : _byDay = _cloneSeed(seed);

  final Map<AthleteSessionDayKey, List<SessionOccurrence>> _byDay;

  List<SessionOccurrence> occurrencesOnDay({
    required String athleteId,
    required SessionOccurrenceDate calendarDate,
  }) {
    final key = AthleteSessionDayKey(
      athleteId: athleteId.trim(),
      calendarDate: calendarDate,
    );
    final matches = _byDay[key];
    if (matches == null || matches.isEmpty) return const [];
    final sorted = List<SessionOccurrence>.from(matches)
      ..sort((a, b) => a.occurrenceId.compareTo(b.occurrenceId));
    return List.unmodifiable(sorted);
  }

  void register({
    required String athleteId,
    required SessionOccurrence occurrence,
  }) {
    final key = AthleteSessionDayKey(
      athleteId: athleteId.trim(),
      calendarDate: occurrence.currentDate,
    );
    final existing = List<SessionOccurrence>.from(_byDay[key] ?? const []);
    final withoutSameId = existing
        .where((o) => o.occurrenceId != occurrence.occurrenceId)
        .toList(growable: true);
    withoutSameId.add(occurrence);
    withoutSameId.sort((a, b) => a.occurrenceId.compareTo(b.occurrenceId));
    _byDay[key] = withoutSameId;
  }

  void upsert({
    required String athleteId,
    required SessionOccurrence occurrence,
  }) {
    register(athleteId: athleteId, occurrence: occurrence);
  }

  static Map<AthleteSessionDayKey, List<SessionOccurrence>> _cloneSeed(
    Map<AthleteSessionDayKey, List<SessionOccurrence>>? seed,
  ) {
    if (seed == null || seed.isEmpty) return {};
    return {
      for (final entry in seed.entries)
        entry.key: List<SessionOccurrence>.from(entry.value),
    };
  }
}
