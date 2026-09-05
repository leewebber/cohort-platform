enum IntervalWorkState {
  pending,
  completed,
  skipped,
  paceUnavailable;

  String get dbValue => switch (this) {
    IntervalWorkState.pending => 'pending',
    IntervalWorkState.completed => 'completed',
    IntervalWorkState.skipped => 'skipped',
    IntervalWorkState.paceUnavailable => 'pace_unavailable',
  };

  static IntervalWorkState fromDb(String? value) {
    return switch (value) {
      'completed' => IntervalWorkState.completed,
      'skipped' => IntervalWorkState.skipped,
      'pace_unavailable' => IntervalWorkState.paceUnavailable,
      _ => IntervalWorkState.pending,
    };
  }

  bool get countsAsCompleted =>
      this == IntervalWorkState.completed ||
      this == IntervalWorkState.paceUnavailable;

  bool get hasComparablePace => this == IntervalWorkState.completed;
}

class IntervalWorkResult {
  const IntervalWorkResult({
    required this.ordinal,
    required this.workSeconds,
    this.paceSecondsPerKm,
    this.paceUnit = IntervalPaceUnit.secondsPerKm,
    this.state = IntervalWorkState.pending,
  });

  final int ordinal;
  final int workSeconds;
  final double? paceSecondsPerKm;
  final String paceUnit;
  final IntervalWorkState state;

  bool get hasValidPace =>
      state.hasComparablePace &&
      paceSecondsPerKm != null &&
      paceSecondsPerKm! > 0 &&
      workSeconds > 0;

  double? get impliedDistanceKm {
    if (!hasValidPace) return null;
    return workSeconds / paceSecondsPerKm!;
  }

  IntervalWorkResult copyWith({
    int? ordinal,
    int? workSeconds,
    double? paceSecondsPerKm,
    String? paceUnit,
    IntervalWorkState? state,
    bool clearPace = false,
  }) {
    return IntervalWorkResult(
      ordinal: ordinal ?? this.ordinal,
      workSeconds: workSeconds ?? this.workSeconds,
      paceSecondsPerKm: clearPace
          ? null
          : (paceSecondsPerKm ?? this.paceSecondsPerKm),
      paceUnit: paceUnit ?? this.paceUnit,
      state: state ?? this.state,
    );
  }

  Map<String, dynamic> toJson() => {
    'ordinal': ordinal,
    'workSeconds': workSeconds,
    if (paceSecondsPerKm != null) 'paceSecondsPerKm': paceSecondsPerKm,
    'paceUnit': paceUnit,
    'state': state.dbValue,
  };

  factory IntervalWorkResult.fromJson(Map<String, dynamic> json) {
    return IntervalWorkResult(
      ordinal: _int(json['ordinal']) ?? 0,
      workSeconds: _int(json['workSeconds'] ?? json['work_seconds']) ?? 0,
      paceSecondsPerKm: _double(
        json['paceSecondsPerKm'] ?? json['pace_seconds_per_km'],
      ),
      paceUnit:
          json['paceUnit']?.toString() ?? IntervalPaceUnit.secondsPerKm,
      state: IntervalWorkState.fromDb(json['state']?.toString()),
    );
  }

  static int? _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _double(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class IntervalPaceUnit {
  const IntervalPaceUnit._();

  static const secondsPerKm = 'sec_per_km';

  static bool isSupported(String? unit) {
    final trimmed = unit?.trim();
    return trimmed == null ||
        trimmed.isEmpty ||
        trimmed == secondsPerKm ||
        trimmed == 's/km' ||
        trimmed == 'sec/km';
  }
}
