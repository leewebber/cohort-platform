/// Relative impact / loading stress characteristic.
enum ExerciseImpactLevel {
  low,
  moderate,
  high,
  unknown,
}

extension ExerciseImpactLevelCodec on ExerciseImpactLevel {
  String get wireValue {
    return switch (this) {
      ExerciseImpactLevel.low => 'low',
      ExerciseImpactLevel.moderate => 'moderate',
      ExerciseImpactLevel.high => 'high',
      ExerciseImpactLevel.unknown => 'unknown',
    };
  }

  static ExerciseImpactLevel? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    for (final value in ExerciseImpactLevel.values) {
      if (value.wireValue == normalized) return value;
    }
    return null;
  }
}
