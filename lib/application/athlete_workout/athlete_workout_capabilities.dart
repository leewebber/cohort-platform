import 'package:cohort_platform/domain/session_occurrence/session_occurrence_domain.dart';

/// Read-only capability flags derived from [SessionOccurrence] lifecycle (no new rules).
class AthleteWorkoutCapabilities {
  const AthleteWorkoutCapabilities._();

  static bool adaptationAvailable(SessionOccurrence occurrence) {
    return !occurrence.isTerminal &&
        occurrence.lifecycleState.allowsExecutionSnapshotAttachment;
  }

  static bool canStartWorkout(SessionOccurrence occurrence) {
    if (occurrence.isTerminal) return false;
    return switch (occurrence.lifecycleState) {
      SessionOccurrenceLifecycleState.scheduled ||
      SessionOccurrenceLifecycleState.adapted => true,
      _ => false,
    };
  }

  static bool canCompleteWorkout(SessionOccurrence occurrence) {
    if (occurrence.isTerminal) return false;
    return occurrence.lifecycleState ==
        SessionOccurrenceLifecycleState.inProgress;
  }
}
