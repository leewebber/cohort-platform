/// High-level exercise modality classification.
///
/// Strength, bodyweight, locomotion, ergs, and sport-specific movements share
/// one Exercise Knowledge Authority — modality is a typed classification, not
/// a separate database.
enum ExerciseModality {
  strength,
  bodyweight,
  locomotion,
  erg,
  mobility,
  recovery,
  sportSpecific,
  other,
}

extension ExerciseModalityCodec on ExerciseModality {
  String get wireValue {
    return switch (this) {
      ExerciseModality.strength => 'strength',
      ExerciseModality.bodyweight => 'bodyweight',
      ExerciseModality.locomotion => 'locomotion',
      ExerciseModality.erg => 'erg',
      ExerciseModality.mobility => 'mobility',
      ExerciseModality.recovery => 'recovery',
      ExerciseModality.sportSpecific => 'sport_specific',
      ExerciseModality.other => 'other',
    };
  }

  static ExerciseModality? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    for (final value in ExerciseModality.values) {
      if (value.wireValue == normalized) return value;
    }
    return null;
  }
}
