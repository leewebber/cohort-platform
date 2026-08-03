import 's17_staging_journey_matrix.dart';

/// Redacted before/after snapshot for schedule ops (no full UUIDs required).
class S17ScheduleOpSnapshot {
  const S17ScheduleOpSnapshot({
    required this.scheduleRevision,
    required this.occurrenceCount,
    required this.orderedSlotIds,
    required this.orderedDatesIso,
    required this.uncompletedCount,
  });

  final int scheduleRevision;
  final int occurrenceCount;
  final List<String> orderedSlotIds;
  final List<String> orderedDatesIso;
  final int uncompletedCount;

  bool sameIdentitiesAndDates(S17ScheduleOpSnapshot other) {
    if (occurrenceCount != other.occurrenceCount) return false;
    if (orderedSlotIds.length != other.orderedSlotIds.length) return false;
    for (var i = 0; i < orderedSlotIds.length; i++) {
      if (orderedSlotIds[i] != other.orderedSlotIds[i]) return false;
      if (orderedDatesIso[i] != other.orderedDatesIso[i]) return false;
    }
    return true;
  }
}

class S17ScheduleOpOutcome {
  const S17ScheduleOpOutcome({
    required this.applied,
    required this.before,
    required this.after,
    required this.invalidRejectedAtomically,
    this.restoredTo,
  });

  final bool applied;
  final S17ScheduleOpSnapshot before;
  final S17ScheduleOpSnapshot after;
  final bool invalidRejectedAtomically;
  final S17ScheduleOpSnapshot? restoredTo;
}

/// Pure assertions for F–J. Ordering: Move → Swap → Push → Skip → Undo.
/// Each valid op may mutate; invalid must leave [before] unchanged when applied=false.
class S17ScheduleOpsHarness {
  const S17ScheduleOpsHarness();

  S17JourneyResult evaluateMove(S17ScheduleOpOutcome o) {
    final countStable = o.after.occurrenceCount == o.before.occurrenceCount;
    final changed =
        o.applied && o.after.scheduleRevision != o.before.scheduleRevision;
    return (changed && countStable && o.invalidRejectedAtomically)
        ? S17JourneyResult.pass
        : S17JourneyResult.fail;
  }

  S17JourneyResult evaluateSwap(S17ScheduleOpOutcome o) {
    final countStable = o.after.occurrenceCount == o.before.occurrenceCount;
    final identitiesPreserved =
        o.after.orderedSlotIds.toSet().containsAll(o.before.orderedSlotIds) &&
        o.before.orderedSlotIds.toSet().containsAll(o.after.orderedSlotIds);
    final changed =
        o.applied && o.after.scheduleRevision != o.before.scheduleRevision;
    return (changed &&
            countStable &&
            identitiesPreserved &&
            o.invalidRejectedAtomically)
        ? S17JourneyResult.pass
        : S17JourneyResult.fail;
  }

  S17JourneyResult evaluatePush(S17ScheduleOpOutcome o) {
    final countStable = o.after.occurrenceCount == o.before.occurrenceCount;
    final orderStable = _sameOrder(
      o.before.orderedSlotIds,
      o.after.orderedSlotIds,
    );
    final changed =
        o.applied && o.after.scheduleRevision != o.before.scheduleRevision;
    return (changed &&
            countStable &&
            orderStable &&
            o.invalidRejectedAtomically)
        ? S17JourneyResult.pass
        : S17JourneyResult.fail;
  }

  S17JourneyResult evaluateSkip(S17ScheduleOpOutcome o) {
    final changed =
        o.applied &&
        (o.after.scheduleRevision != o.before.scheduleRevision ||
            o.after.uncompletedCount < o.before.uncompletedCount);
    return changed ? S17JourneyResult.pass : S17JourneyResult.fail;
  }

  S17JourneyResult evaluateUndo({
    required S17ScheduleOpSnapshot beforeSkip,
    required S17ScheduleOpOutcome undo,
    required bool horizonRejectedWithoutMutation,
  }) {
    final restored =
        undo.applied &&
        undo.restoredTo != null &&
        undo.restoredTo!.scheduleRevision == beforeSkip.scheduleRevision &&
        undo.restoredTo!.sameIdentitiesAndDates(beforeSkip);
    final horizonOk = horizonRejectedWithoutMutation;
    return (restored && horizonOk)
        ? S17JourneyResult.pass
        : S17JourneyResult.fail;
  }

  /// Invalid op must leave state identical when not applied.
  static bool atomicRejectionHolds({
    required S17ScheduleOpSnapshot before,
    required S17ScheduleOpSnapshot afterInvalidAttempt,
    required bool invalidPreviewReady,
  }) {
    return !invalidPreviewReady &&
        before.sameIdentitiesAndDates(afterInvalidAttempt);
  }

  bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
