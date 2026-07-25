/// Structural and systemic load impact (not pain diagnosis).
enum ImpactLevel {
  veryLow,
  low,
  moderate,
  high,
  veryHigh,
}

extension ImpactLevelDb on ImpactLevel {
  String get dbValue {
    return switch (this) {
      ImpactLevel.veryLow => 'very_low',
      ImpactLevel.low => 'low',
      ImpactLevel.moderate => 'moderate',
      ImpactLevel.high => 'high',
      ImpactLevel.veryHigh => 'very_high',
    };
  }

  static ImpactLevel? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
    for (final level in ImpactLevel.values) {
      if (level.dbValue == normalized) return level;
    }
    return null;
  }
}
