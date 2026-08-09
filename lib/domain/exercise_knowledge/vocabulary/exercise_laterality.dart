/// Bilateral vs unilateral execution characteristic.
enum ExerciseLaterality {
  bilateral,
  unilateral,
  either,
  notApplicable,
}

extension ExerciseLateralityCodec on ExerciseLaterality {
  String get wireValue {
    return switch (this) {
      ExerciseLaterality.bilateral => 'bilateral',
      ExerciseLaterality.unilateral => 'unilateral',
      ExerciseLaterality.either => 'either',
      ExerciseLaterality.notApplicable => 'not_applicable',
    };
  }

  static ExerciseLaterality? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    for (final value in ExerciseLaterality.values) {
      if (value.wireValue == normalized) return value;
    }
    return null;
  }
}
