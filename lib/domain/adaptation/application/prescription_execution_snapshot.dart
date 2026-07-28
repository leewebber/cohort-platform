/// Immutable prescription values for execution snapshots (structured fields only).
class PrescriptionExecutionSnapshot {
  const PrescriptionExecutionSnapshot({
    this.sets,
    this.reps,
    this.restSeconds,
  });

  final int? sets;
  final int? reps;
  final int? restSeconds;

  PrescriptionExecutionSnapshot copyWith({int? sets, int? reps, int? restSeconds}) {
    return PrescriptionExecutionSnapshot(
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PrescriptionExecutionSnapshot &&
        other.sets == sets &&
        other.reps == reps &&
        other.restSeconds == restSeconds;
  }

  @override
  int get hashCode => Object.hash(sets, reps, restSeconds);
}
