import '../ports/session_occurrence_repository.dart';
import '../value_objects/session_occurrence_date.dart';
import '../vocabulary/session_occurrence_lifecycle_state.dart';
import 'athlete_daily_session_resolution_result.dart';

/// Resolves an athlete's workout for a calendar day (read-only).
class AthleteDailySessionResolver {
  const AthleteDailySessionResolver();

  AthleteDailySessionResolutionResult resolve({
    required String athleteId,
    required SessionOccurrenceDate date,
    required SessionOccurrenceRepository occurrenceRepository,
  }) {
    final trimmedAthlete = athleteId.trim();
    if (trimmedAthlete.isEmpty || !_isValidDate(date)) {
      return AthleteDailySessionResolutionResult(
        outcome: AthleteDailySessionResolutionOutcome.invalidLookup,
        athleteId: trimmedAthlete,
        date: date,
      );
    }

    final matches = occurrenceRepository.occurrencesOnDay(
      athleteId: trimmedAthlete,
      calendarDate: date,
    );

    if (matches.isEmpty) {
      return AthleteDailySessionResolutionResult(
        outcome: AthleteDailySessionResolutionOutcome.noSessionScheduled,
        athleteId: trimmedAthlete,
        date: date,
      );
    }

    if (matches.length > 1) {
      return AthleteDailySessionResolutionResult(
        outcome: AthleteDailySessionResolutionOutcome.multipleSessionsScheduled,
        athleteId: trimmedAthlete,
        date: date,
        matchingOccurrences: matches,
      );
    }

    final occurrence = matches.single;
    return AthleteDailySessionResolutionResult(
      outcome: _outcomeForLifecycle(occurrence.lifecycleState),
      athleteId: trimmedAthlete,
      date: date,
      occurrence: occurrence,
      matchingOccurrences: matches,
    );
  }

  AthleteDailySessionResolutionOutcome _outcomeForLifecycle(
    SessionOccurrenceLifecycleState state,
  ) {
    return switch (state) {
      SessionOccurrenceLifecycleState.scheduled =>
        AthleteDailySessionResolutionOutcome.sessionPlanned,
      SessionOccurrenceLifecycleState.adapted =>
        AthleteDailySessionResolutionOutcome.sessionAdapted,
      SessionOccurrenceLifecycleState.inProgress =>
        AthleteDailySessionResolutionOutcome.sessionInProgress,
      SessionOccurrenceLifecycleState.completed =>
        AthleteDailySessionResolutionOutcome.sessionCompleted,
      SessionOccurrenceLifecycleState.skipped =>
        AthleteDailySessionResolutionOutcome.sessionSkipped,
      SessionOccurrenceLifecycleState.cancelled =>
        AthleteDailySessionResolutionOutcome.sessionCancelled,
    };
  }

  bool _isValidDate(SessionOccurrenceDate date) {
    if (date.month < 1 || date.month > 12) return false;
    if (date.day < 1 || date.day > 31) return false;
    if (date.year < 1) return false;
    return true;
  }
}
