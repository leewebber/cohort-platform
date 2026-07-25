/// How heavily an exercise can be loaded for progression guidance (qualitative).
enum ExerciseLoadingPotential {
  bodyweightOnly,
  lightImplement,
  moderateLoad,
  heavyLoad,
  maximalLoad,
}

extension ExerciseLoadingPotentialDb on ExerciseLoadingPotential {
  String get dbValue {
    return switch (this) {
      ExerciseLoadingPotential.bodyweightOnly => 'bodyweight_only',
      ExerciseLoadingPotential.lightImplement => 'light_implement',
      ExerciseLoadingPotential.moderateLoad => 'moderate_load',
      ExerciseLoadingPotential.heavyLoad => 'heavy_load',
      ExerciseLoadingPotential.maximalLoad => 'maximal_load',
    };
  }

  static ExerciseLoadingPotential? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final potential in ExerciseLoadingPotential.values) {
      if (potential.dbValue == normalized) return potential;
    }
    return null;
  }
}
