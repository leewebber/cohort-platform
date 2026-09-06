enum CircuitStationMetric { calories, reps, distance, duration, load, completion }

enum CircuitOccurrenceState { pending, recorded, skipped }

class CircuitStationActual {
  const CircuitStationActual({
    required this.ordinal,
    required this.round,
    required this.stationIndex,
    required this.stationId,
    required this.displayName,
    required this.primaryMetric,
    this.prescribedCalories,
    this.prescribedReps,
    this.prescribedDistanceMeters,
    this.prescribedDistanceText,
    this.calories,
    this.reps,
    this.distance,
    this.distanceUnit = 'm',
    this.durationSeconds,
    this.load,
    this.loadUnit,
    this.state = CircuitOccurrenceState.pending,
  });

  final int ordinal;
  final int round;
  final int stationIndex;
  final String stationId;
  final String displayName;
  final CircuitStationMetric primaryMetric;
  final int? prescribedCalories;
  final int? prescribedReps;
  final double? prescribedDistanceMeters;
  final String? prescribedDistanceText;
  final double? calories;
  final int? reps;
  final double? distance;
  final String distanceUnit;
  final int? durationSeconds;
  final double? load;
  final String? loadUnit;
  final CircuitOccurrenceState state;

  bool get hasRecordedActual =>
      state == CircuitOccurrenceState.recorded && primaryValue != null;

  num? get primaryValue {
    return switch (primaryMetric) {
      CircuitStationMetric.calories => calories,
      CircuitStationMetric.reps => reps,
      CircuitStationMetric.distance => distance,
      CircuitStationMetric.duration => durationSeconds,
      CircuitStationMetric.load => load,
      CircuitStationMetric.completion =>
        state == CircuitOccurrenceState.recorded ? 1 : null,
    };
  }

  Map<String, dynamic> toJson() => {
    'ordinal': ordinal,
    'round': round,
    'stationIndex': stationIndex,
    'stationId': stationId,
    'displayName': displayName,
    'primaryMetric': primaryMetric.name,
    if (prescribedCalories != null) 'prescribedCalories': prescribedCalories,
    if (prescribedReps != null) 'prescribedReps': prescribedReps,
    if (prescribedDistanceMeters != null)
      'prescribedDistanceMeters': prescribedDistanceMeters,
    if (prescribedDistanceText != null)
      'prescribedDistanceText': prescribedDistanceText,
    if (calories != null) 'calories': calories,
    if (reps != null) 'reps': reps,
    if (distance != null) 'distance': distance,
    'distanceUnit': distanceUnit,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (load != null) 'load': load,
    if (loadUnit != null) 'loadUnit': loadUnit,
    'state': state.name,
  };

  factory CircuitStationActual.fromJson(Map<String, dynamic> json) {
    return CircuitStationActual(
      ordinal: _int(json['ordinal']),
      round: _int(json['round']),
      stationIndex: _int(json['stationIndex']),
      stationId: json['stationId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      primaryMetric: CircuitStationMetric.values.firstWhere(
        (metric) => metric.name == json['primaryMetric']?.toString(),
        orElse: () => CircuitStationMetric.completion,
      ),
      prescribedCalories: _nullableInt(json['prescribedCalories']),
      prescribedReps: _nullableInt(json['prescribedReps']),
      prescribedDistanceMeters: _nullableDouble(json['prescribedDistanceMeters']),
      prescribedDistanceText: json['prescribedDistanceText']?.toString(),
      calories: _nullableDouble(json['calories']),
      reps: _nullableInt(json['reps']),
      distance: _nullableDouble(json['distance']),
      distanceUnit: json['distanceUnit']?.toString() ?? 'm',
      durationSeconds: _nullableInt(json['durationSeconds']),
      load: _nullableDouble(json['load']),
      loadUnit: json['loadUnit']?.toString(),
      state: CircuitOccurrenceState.values.firstWhere(
        (value) => value.name == json['state']?.toString(),
        orElse: () => CircuitOccurrenceState.pending,
      ),
    );
  }

  CircuitStationActual copyWith({
    double? calories,
    int? reps,
    double? distance,
    int? durationSeconds,
    double? load,
    String? loadUnit,
    CircuitOccurrenceState? state,
    bool clearCalories = false,
    bool clearReps = false,
    bool clearDistance = false,
    bool clearDuration = false,
    bool clearLoad = false,
  }) {
    return CircuitStationActual(
      ordinal: ordinal,
      round: round,
      stationIndex: stationIndex,
      stationId: stationId,
      displayName: displayName,
      primaryMetric: primaryMetric,
      prescribedCalories: prescribedCalories,
      prescribedReps: prescribedReps,
      prescribedDistanceMeters: prescribedDistanceMeters,
      prescribedDistanceText: prescribedDistanceText,
      calories: clearCalories ? null : (calories ?? this.calories),
      reps: clearReps ? null : (reps ?? this.reps),
      distance: clearDistance ? null : (distance ?? this.distance),
      distanceUnit: distanceUnit,
      durationSeconds: clearDuration
          ? null
          : (durationSeconds ?? this.durationSeconds),
      load: clearLoad ? null : (load ?? this.load),
      loadUnit: loadUnit ?? this.loadUnit,
      state: state ?? this.state,
    );
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class CircuitTimerCursor {
  const CircuitTimerCursor({
    required this.currentRound,
    required this.currentOrdinal,
    required this.remainingSeconds,
    required this.phase,
    this.secondarySeconds,
    this.isRunning = false,
    this.isPaused = false,
    this.isFinished = false,
    this.workStartedAtMs,
    this.restStartedAtMs,
  });

  final int currentRound;
  final int currentOrdinal;
  final int remainingSeconds;
  final String phase;
  final int? secondarySeconds;
  final bool isRunning;
  final bool isPaused;
  final bool isFinished;
  final int? workStartedAtMs;
  final int? restStartedAtMs;

  Map<String, dynamic> toJson() => {
    'currentRound': currentRound,
    'currentOrdinal': currentOrdinal,
    'remainingSeconds': remainingSeconds,
    'phase': phase,
    if (secondarySeconds != null) 'secondarySeconds': secondarySeconds,
    'isRunning': isRunning,
    'isPaused': isPaused,
    'isFinished': isFinished,
    if (workStartedAtMs != null) 'workStartedAtMs': workStartedAtMs,
    if (restStartedAtMs != null) 'restStartedAtMs': restStartedAtMs,
  };

  factory CircuitTimerCursor.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CircuitTimerCursor(
        currentRound: 1,
        currentOrdinal: 1,
        remainingSeconds: 0,
        phase: 'ready',
      );
    }
    return CircuitTimerCursor(
      currentRound: CircuitStationActual._int(json['currentRound']) == 0
          ? 1
          : CircuitStationActual._int(json['currentRound']),
      currentOrdinal: CircuitStationActual._int(json['currentOrdinal']) == 0
          ? 1
          : CircuitStationActual._int(json['currentOrdinal']),
      remainingSeconds: CircuitStationActual._int(json['remainingSeconds']),
      phase: json['phase']?.toString() ?? 'ready',
      secondarySeconds: CircuitStationActual._nullableInt(
        json['secondarySeconds'],
      ),
      isRunning: json['isRunning'] == true,
      isPaused: json['isPaused'] == true,
      isFinished: json['isFinished'] == true,
      workStartedAtMs: CircuitStationActual._nullableInt(json['workStartedAtMs']),
      restStartedAtMs: CircuitStationActual._nullableInt(json['restStartedAtMs']),
    );
  }

  CircuitTimerCursor copyWith({
    int? currentRound,
    int? currentOrdinal,
    int? remainingSeconds,
    String? phase,
    int? secondarySeconds,
    bool? isRunning,
    bool? isPaused,
    bool? isFinished,
    int? workStartedAtMs,
    int? restStartedAtMs,
    bool clearWorkStarted = false,
    bool clearRestStarted = false,
  }) {
    return CircuitTimerCursor(
      currentRound: currentRound ?? this.currentRound,
      currentOrdinal: currentOrdinal ?? this.currentOrdinal,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      phase: phase ?? this.phase,
      secondarySeconds: secondarySeconds ?? this.secondarySeconds,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      isFinished: isFinished ?? this.isFinished,
      workStartedAtMs: clearWorkStarted
          ? null
          : (workStartedAtMs ?? this.workStartedAtMs),
      restStartedAtMs: clearRestStarted
          ? null
          : (restStartedAtMs ?? this.restStartedAtMs),
    );
  }
}
