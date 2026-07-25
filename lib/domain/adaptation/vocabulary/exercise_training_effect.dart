/// Primary training effect an exercise supports when selected as a substitute.
enum ExerciseTrainingEffect {
  maxStrength,
  hypertrophy,
  muscularEndurance,
  power,
  aerobicCapacity,
  anaerobicCapacity,
  mobility,
  stability,
  skill,
  recovery,
}

extension ExerciseTrainingEffectDb on ExerciseTrainingEffect {
  String get dbValue {
    return switch (this) {
      ExerciseTrainingEffect.maxStrength => 'max_strength',
      ExerciseTrainingEffect.hypertrophy => 'hypertrophy',
      ExerciseTrainingEffect.muscularEndurance => 'muscular_endurance',
      ExerciseTrainingEffect.power => 'power',
      ExerciseTrainingEffect.aerobicCapacity => 'aerobic_capacity',
      ExerciseTrainingEffect.anaerobicCapacity => 'anaerobic_capacity',
      ExerciseTrainingEffect.mobility => 'mobility',
      ExerciseTrainingEffect.stability => 'stability',
      ExerciseTrainingEffect.skill => 'skill',
      ExerciseTrainingEffect.recovery => 'recovery',
    };
  }

  static ExerciseTrainingEffect? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final effect in ExerciseTrainingEffect.values) {
      if (effect.dbValue == normalized) return effect;
    }
    return null;
  }
}
