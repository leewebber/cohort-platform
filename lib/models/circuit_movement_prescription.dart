/// One prescribed movement within a circuit session plan.
///
/// Targets are coach prescription snapshots (text). Normalised actuals live on
/// [CircuitPerformanceEntry] inside [CircuitSessionExecutionState].
///
/// See `07 Documentation/39_Circuit_Execution_Engine.md`.
class CircuitMovementPrescription {
  const CircuitMovementPrescription({
    required this.localId,
    required this.orderIndex,
    required this.title,
    this.protocolStepId,
    this.exerciseId,
    this.reps,
    this.distance,
    this.duration,
    this.load,
    this.coachCue,
  });

  /// Client-stable identity for in-session references.
  final String localId;

  /// Position in the programmed movement list (1-based).
  final int orderIndex;

  /// Display title, e.g. `Burpees`, `Row 500 m`.
  final String title;

  final int? protocolStepId;
  final String? exerciseId;

  /// Prescribed reps snapshot, e.g. `10`, `Max`.
  final String? reps;

  /// Prescribed distance snapshot, e.g. `400 m`, `0.5 km`.
  final String? distance;

  /// Prescribed duration snapshot, e.g. `30 sec`, `1 min`.
  final String? duration;

  /// Prescribed load snapshot, e.g. `2×22.5 kg`, `24 kg`, `Bodyweight`.
  final String? load;

  /// Optional coach cue shown during execution.
  final String? coachCue;

  CircuitMovementPrescription copyWith({
    String? localId,
    int? orderIndex,
    String? title,
    int? protocolStepId,
    String? exerciseId,
    String? reps,
    String? distance,
    String? duration,
    String? load,
    String? coachCue,
    bool clearProtocolStepId = false,
    bool clearExerciseId = false,
    bool clearReps = false,
    bool clearDistance = false,
    bool clearDuration = false,
    bool clearLoad = false,
    bool clearCoachCue = false,
  }) {
    return CircuitMovementPrescription(
      localId: localId ?? this.localId,
      orderIndex: orderIndex ?? this.orderIndex,
      title: title ?? this.title,
      protocolStepId:
          clearProtocolStepId ? null : (protocolStepId ?? this.protocolStepId),
      exerciseId: clearExerciseId ? null : (exerciseId ?? this.exerciseId),
      reps: clearReps ? null : (reps ?? this.reps),
      distance: clearDistance ? null : (distance ?? this.distance),
      duration: clearDuration ? null : (duration ?? this.duration),
      load: clearLoad ? null : (load ?? this.load),
      coachCue: clearCoachCue ? null : (coachCue ?? this.coachCue),
    );
  }
}
