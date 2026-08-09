/// Valid prescription or completed-performance dimensions.
///
/// These declare capabilities only. Actual prescribed or completed values
/// belong outside the Exercise Knowledge Authority.
enum PerformanceDimension {
  load,
  repetitions,
  duration,
  distance,
  pace,
  power,
  calories,
  heartRate,
  rpe,
  rir,
  unilateralSide,
  heightOrTarget,
}

extension PerformanceDimensionCodec on PerformanceDimension {
  String get wireValue {
    return switch (this) {
      PerformanceDimension.load => 'load',
      PerformanceDimension.repetitions => 'repetitions',
      PerformanceDimension.duration => 'duration',
      PerformanceDimension.distance => 'distance',
      PerformanceDimension.pace => 'pace',
      PerformanceDimension.power => 'power',
      PerformanceDimension.calories => 'calories',
      PerformanceDimension.heartRate => 'heart_rate',
      PerformanceDimension.rpe => 'rpe',
      PerformanceDimension.rir => 'rir',
      PerformanceDimension.unilateralSide => 'unilateral_side',
      PerformanceDimension.heightOrTarget => 'height_or_target',
    };
  }

  static PerformanceDimension? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    for (final value in PerformanceDimension.values) {
      if (value.wireValue == normalized) return value;
    }
    return null;
  }
}
