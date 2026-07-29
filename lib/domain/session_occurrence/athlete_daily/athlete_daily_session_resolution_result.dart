import '../session_occurrence.dart';
import '../value_objects/session_occurrence_date.dart';
import '../vocabulary/session_occurrence_lifecycle_state.dart';

enum AthleteDailySessionResolutionOutcome {
  invalidLookup,
  noSessionScheduled,
  multipleSessionsScheduled,
  sessionPlanned,
  sessionAdapted,
  sessionInProgress,
  sessionCompleted,
  sessionSkipped,
  sessionCancelled,
}

/// Read-only answer to "what is this athlete's workout on this day?"
class AthleteDailySessionResolutionResult {
  const AthleteDailySessionResolutionResult({
    required this.outcome,
    required this.athleteId,
    required this.date,
    this.occurrence,
    this.matchingOccurrences = const [],
  });

  final AthleteDailySessionResolutionOutcome outcome;
  final String athleteId;
  final SessionOccurrenceDate date;
  final SessionOccurrence? occurrence;
  final List<SessionOccurrence> matchingOccurrences;

  bool get hasSingleOccurrence => occurrence != null;

  SessionOccurrenceLifecycleState? get lifecycleState =>
      occurrence?.lifecycleState;

  bool get hasExecutionSnapshot => occurrence?.executionSnapshot != null;

  @override
  bool operator ==(Object other) {
    return other is AthleteDailySessionResolutionResult &&
        other.outcome == outcome &&
        other.athleteId == athleteId &&
        other.date == date &&
        other.occurrence == occurrence &&
        _listEquals(other.matchingOccurrences, matchingOccurrences);
  }

  @override
  int get hashCode => Object.hash(
    outcome,
    athleteId,
    date,
    occurrence,
    Object.hashAll(matchingOccurrences),
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
