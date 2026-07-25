/// Minimum prescription that still satisfies block/session intent (qualitative + optional metrics).
class MinimumViablePrescription {
  const MinimumViablePrescription({
    this.durationMinutes,
    this.sets,
    this.reps,
    this.qualitativeLoad,
    this.notes,
  });

  final int? durationMinutes;
  final int? sets;
  final int? reps;
  final String? qualitativeLoad;
  final String? notes;

  bool get isEmpty =>
      durationMinutes == null &&
      sets == null &&
      reps == null &&
      (qualitativeLoad == null || qualitativeLoad!.trim().isEmpty) &&
      (notes == null || notes!.trim().isEmpty);

  Map<String, dynamic> toJson() {
    return {
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (sets != null) 'sets': sets,
      if (reps != null) 'reps': reps,
      if (qualitativeLoad != null && qualitativeLoad!.trim().isNotEmpty)
        'qualitative_load': qualitativeLoad!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
    };
  }

  factory MinimumViablePrescription.fromJson(Map<String, dynamic> json) {
    return MinimumViablePrescription(
      durationMinutes: json['duration_minutes'] as int?,
      sets: json['sets'] as int?,
      reps: json['reps'] as int?,
      qualitativeLoad: json['qualitative_load']?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}
