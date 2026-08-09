/// Relative technical demand of an exercise definition.
enum ExerciseTechnicalComplexity {
  beginner,
  intermediate,
  advanced,
  unknown,
}

extension ExerciseTechnicalComplexityCodec on ExerciseTechnicalComplexity {
  String get wireValue {
    return switch (this) {
      ExerciseTechnicalComplexity.beginner => 'beginner',
      ExerciseTechnicalComplexity.intermediate => 'intermediate',
      ExerciseTechnicalComplexity.advanced => 'advanced',
      ExerciseTechnicalComplexity.unknown => 'unknown',
    };
  }

  static ExerciseTechnicalComplexity? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    for (final value in ExerciseTechnicalComplexity.values) {
      if (value.wireValue == normalized) return value;
    }
    return null;
  }
}
