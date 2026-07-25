/// Canonical movement pattern for substitution and intent matching.
enum MovementPattern {
  squat,
  hinge,
  lunge,
  horizontalPush,
  verticalPush,
  horizontalPull,
  verticalPull,
  carry,
  core,
  rotation,
  locomotion,
  cyclical,
  jump,
  ballThrow,
  other,
}

extension MovementPatternDb on MovementPattern {
  String get dbValue {
    return switch (this) {
      MovementPattern.squat => 'squat',
      MovementPattern.hinge => 'hinge',
      MovementPattern.lunge => 'lunge',
      MovementPattern.horizontalPush => 'horizontal_push',
      MovementPattern.verticalPush => 'vertical_push',
      MovementPattern.horizontalPull => 'horizontal_pull',
      MovementPattern.verticalPull => 'vertical_pull',
      MovementPattern.carry => 'carry',
      MovementPattern.core => 'core',
      MovementPattern.rotation => 'rotation',
      MovementPattern.locomotion => 'locomotion',
      MovementPattern.cyclical => 'cyclical',
      MovementPattern.jump => 'jump',
      MovementPattern.ballThrow => 'ball_throw',
      MovementPattern.other => 'other',
    };
  }

  static MovementPattern? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
    for (final pattern in MovementPattern.values) {
      if (pattern.dbValue == normalized) return pattern;
    }
    return null;
  }
}
