import 'session_occurrence.dart';
import 'session_occurrence_transition_result.dart';
import 'vocabulary/session_occurrence_lifecycle_state.dart';

/// Pure lifecycle transition rules (no side effects).
class SessionOccurrenceLifecycle {
  const SessionOccurrenceLifecycle._();

  static const allowedTransitions = {
    SessionOccurrenceLifecycleState.scheduled: {
      SessionOccurrenceLifecycleState.adapted,
      SessionOccurrenceLifecycleState.inProgress,
      SessionOccurrenceLifecycleState.skipped,
      SessionOccurrenceLifecycleState.cancelled,
    },
    SessionOccurrenceLifecycleState.adapted: {
      SessionOccurrenceLifecycleState.adapted,
      SessionOccurrenceLifecycleState.inProgress,
      SessionOccurrenceLifecycleState.skipped,
      SessionOccurrenceLifecycleState.cancelled,
    },
    SessionOccurrenceLifecycleState.inProgress: {
      SessionOccurrenceLifecycleState.completed,
      SessionOccurrenceLifecycleState.cancelled,
    },
  };

  static bool canTransition({
    required SessionOccurrenceLifecycleState from,
    required SessionOccurrenceLifecycleState to,
  }) {
    if (from.isTerminal) return false;
    final allowed = allowedTransitions[from];
    return allowed?.contains(to) ?? false;
  }

  static SessionOccurrenceTransitionResult requireTransition({
    required SessionOccurrence occurrence,
    required SessionOccurrenceLifecycleState target,
  }) {
    if (!canTransition(from: occurrence.lifecycleState, to: target)) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.invalidLifecycleState,
        detail: '${occurrence.lifecycleState.name}->${target.name}',
      );
    }
    return SessionOccurrenceTransitionResult.success(occurrence);
  }
}
