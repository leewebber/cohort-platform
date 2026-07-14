import 'interval_rep_entry.dart';
import 'interval_session_plan.dart';

/// Mutable in-session execution state for the interval engine.
///
/// Holds the plan plus athlete progress. Services mutate entry copies and
/// replace this state; widgets read derived current/completed/upcoming phases.
///
/// See `07 Documentation/37_Interval_Execution_Engine.md`.
class IntervalSessionExecutionState {
  const IntervalSessionExecutionState({
    required this.plan,
    required this.entries,
    this.activeLocalId,
    this.sessionNote,
    this.endedEarly = false,
    this.endReasonLabel,
    this.trainingSessionId,
  });

  final IntervalSessionPlan plan;
  final List<IntervalRepEntry> entries;
  final String? activeLocalId;
  final String? sessionNote;
  final bool endedEarly;
  final String? endReasonLabel;
  final int? trainingSessionId;

  bool get isRealSession => trainingSessionId != null;

  int get totalPhases => entries.length;

  int get completedPhaseCount => entries.where((entry) => entry.completed).length;

  int get totalWorkPhaseCount =>
      entries.where((entry) => entry.isWorkPhase).length;

  int get completedWorkPhaseCount => entries
      .where((entry) => entry.isWorkPhase && entry.completed)
      .length;

  bool get allPhasesComplete =>
      entries.isNotEmpty && completedPhaseCount == entries.length;

  bool get hasRecordedProgress =>
      entries.any((entry) => entry.completed || entry.hasStartedData);

  IntervalRepEntry? get activeEntry {
    final id = activeLocalId;
    if (id == null) {
      return null;
    }

    return entryByLocalId(id);
  }

  IntervalRepEntry? entryByLocalId(String localId) {
    for (final entry in entries) {
      if (entry.localId == localId) {
        return entry;
      }
    }

    return null;
  }

  int indexOf(String localId) {
    return entries.indexWhere((entry) => entry.localId == localId);
  }

  /// First incomplete phase in timeline order.
  IntervalRepEntry? get currentPhase {
    final active = activeEntry;
    if (active != null && !active.completed) {
      return active;
    }

    for (final entry in entries) {
      if (!entry.completed) {
        return entry;
      }
    }

    return null;
  }

  List<IntervalRepEntry> get completedPhases =>
      entries.where((entry) => entry.completed).toList(growable: false);

  List<IntervalRepEntry> get upcomingPhases {
    final current = currentPhase;
    if (current == null) {
      return const [];
    }

    final currentIndex = indexOf(current.localId);
    if (currentIndex < 0) {
      return const [];
    }

    return entries
        .skip(currentIndex + 1)
        .where((entry) => !entry.completed)
        .toList(growable: false);
  }

  IntervalSessionExecutionState copyWith({
    IntervalSessionPlan? plan,
    List<IntervalRepEntry>? entries,
    String? activeLocalId,
    String? sessionNote,
    bool? endedEarly,
    String? endReasonLabel,
    int? trainingSessionId,
    bool clearActiveLocalId = false,
    bool clearSessionNote = false,
    bool clearEndReasonLabel = false,
  }) {
    return IntervalSessionExecutionState(
      plan: plan ?? this.plan,
      entries: entries ?? this.entries,
      activeLocalId:
          clearActiveLocalId ? null : (activeLocalId ?? this.activeLocalId),
      sessionNote: clearSessionNote ? null : (sessionNote ?? this.sessionNote),
      endedEarly: endedEarly ?? this.endedEarly,
      endReasonLabel: clearEndReasonLabel
          ? null
          : (endReasonLabel ?? this.endReasonLabel),
      trainingSessionId: trainingSessionId ?? this.trainingSessionId,
    );
  }

  IntervalSessionExecutionState updateEntry(IntervalRepEntry updated) {
    final nextEntries = [
      for (final entry in entries)
        if (entry.localId == updated.localId) updated else entry,
    ];

    return copyWith(entries: nextEntries);
  }
}
