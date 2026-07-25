/// Entity scope a constraint or adaptation action applies to.
enum AdaptationConstraintScope {
  programme,
  trainingDay,
  session,
  block,
  exercisePlacement,
  prescription,
  equipment,
}

extension AdaptationConstraintScopeDb on AdaptationConstraintScope {
  String get dbValue {
    return switch (this) {
      AdaptationConstraintScope.programme => 'programme',
      AdaptationConstraintScope.trainingDay => 'training_day',
      AdaptationConstraintScope.session => 'session',
      AdaptationConstraintScope.block => 'block',
      AdaptationConstraintScope.exercisePlacement => 'exercise_placement',
      AdaptationConstraintScope.prescription => 'prescription',
      AdaptationConstraintScope.equipment => 'equipment',
    };
  }

  static AdaptationConstraintScope? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final scope in AdaptationConstraintScope.values) {
      if (scope.dbValue == normalized) return scope;
    }
    return null;
  }
}
