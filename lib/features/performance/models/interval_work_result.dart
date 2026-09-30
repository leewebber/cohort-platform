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

  bool get isResolved => this != IntervalWorkState.pending;
}

class IntervalWorkResult {
  const IntervalWorkResult({
    required this.ordinal,
    required this.workSeconds,
    this.workoutId,
    this.sessionBlockId,
    this.authoredStepId,
    this.repeatOrdinal,
    this.paceSecondsPerKm,
    this.paceUnit = IntervalPaceUnit.secondsPerKm,
    this.state = IntervalWorkState.pending,
  });

  final int ordinal;
  final int workSeconds;
  final String? workoutId;
  final String? sessionBlockId;
  final String? authoredStepId;
  final int? repeatOrdinal;
  final double? paceSecondsPerKm;
  final String paceUnit;
  final IntervalWorkState state;

  bool get hasValidPace =>
      state.hasComparablePace &&
      paceSecondsPerKm != null &&
      paceSecondsPerKm! > 0 &&
      workSeconds > 0;

  bool get hasStructuredIdentity =>
      workoutId != null ||
      sessionBlockId != null ||
      authoredStepId != null ||
      repeatOrdinal != null;

  double? get impliedDistanceKm {
    if (!hasValidPace) return null;
    return workSeconds / paceSecondsPerKm!;
  }

  IntervalWorkResult copyWith({
    int? ordinal,
    int? workSeconds,
    String? workoutId,
    String? sessionBlockId,
    String? authoredStepId,
    int? repeatOrdinal,
    double? paceSecondsPerKm,
    String? paceUnit,
    IntervalWorkState? state,
    bool clearPace = false,
  }) {
    return IntervalWorkResult(
      ordinal: ordinal ?? this.ordinal,
      workSeconds: workSeconds ?? this.workSeconds,
      workoutId: workoutId ?? this.workoutId,
      sessionBlockId: sessionBlockId ?? this.sessionBlockId,
      authoredStepId: authoredStepId ?? this.authoredStepId,
      repeatOrdinal: repeatOrdinal ?? this.repeatOrdinal,
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
    if (workoutId != null) 'workoutId': workoutId,
    if (sessionBlockId != null) 'sessionBlockId': sessionBlockId,
    if (authoredStepId != null) 'authoredStepId': authoredStepId,
    if (repeatOrdinal != null) 'repeatOrdinal': repeatOrdinal,
    if (paceSecondsPerKm != null) 'paceSecondsPerKm': paceSecondsPerKm,
    'paceUnit': paceUnit,
    'state': state.dbValue,
  };

  factory IntervalWorkResult.fromJson(Map<String, dynamic> json) {
    return IntervalWorkResult(
      ordinal: _int(json['ordinal']) ?? 0,
      workSeconds: _int(json['workSeconds'] ?? json['work_seconds']) ?? 0,
      workoutId: _trim(json['workoutId'] ?? json['workout_id']),
      sessionBlockId: _trim(json['sessionBlockId'] ?? json['session_block_id']),
      authoredStepId: _trim(json['authoredStepId'] ?? json['authored_step_id']),
      repeatOrdinal: _int(json['repeatOrdinal'] ?? json['repeat_ordinal']),
      paceSecondsPerKm: _double(
        json['paceSecondsPerKm'] ?? json['pace_seconds_per_km'],
      ),
      paceUnit: json['paceUnit']?.toString() ?? IntervalPaceUnit.secondsPerKm,
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

  static String? _trim(dynamic value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
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
