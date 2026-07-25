/// Canonical exercise library category (structured successor to free-text category).
enum ExerciseCategory {
  strength,
  hypertrophy,
  power,
  conditioning,
  running,
  mobility,
  core,
  carry,
  skill,
  prehab,
  recovery,
  other,
}

extension ExerciseCategoryDb on ExerciseCategory {
  String get dbValue => name;

  static ExerciseCategory? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final category in ExerciseCategory.values) {
      if (category.dbValue == normalized) return category;
    }
    return null;
  }
}
