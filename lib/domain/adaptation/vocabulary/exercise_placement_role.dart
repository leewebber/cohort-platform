/// Role of an exercise within the session architecture (not library category).
enum ExercisePlacementRole {
  primaryLift,
  secondaryLift,
  accessory,
  warmupMovement,
  cooldownMovement,
  conditioningStation,
  skillPractice,
  prehab,
  filler,
}

extension ExercisePlacementRoleDb on ExercisePlacementRole {
  String get dbValue {
    return switch (this) {
      ExercisePlacementRole.primaryLift => 'primary_lift',
      ExercisePlacementRole.secondaryLift => 'secondary_lift',
      ExercisePlacementRole.accessory => 'accessory',
      ExercisePlacementRole.warmupMovement => 'warmup_movement',
      ExercisePlacementRole.cooldownMovement => 'cooldown_movement',
      ExercisePlacementRole.conditioningStation => 'conditioning_station',
      ExercisePlacementRole.skillPractice => 'skill_practice',
      ExercisePlacementRole.prehab => 'prehab',
      ExercisePlacementRole.filler => 'filler',
    };
  }

  static ExercisePlacementRole? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final role in ExercisePlacementRole.values) {
      if (role.dbValue == normalized) return role;
    }
    return null;
  }
}
