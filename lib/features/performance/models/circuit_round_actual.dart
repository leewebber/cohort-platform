enum CircuitRoundCompletionState { pending, completed, incomplete }

class CircuitRoundActual {
  const CircuitRoundActual({
    required this.ordinal,
    this.elapsedSeconds,
    this.state = CircuitRoundCompletionState.pending,
    this.startedAtMs,
    this.finishedAtMs,
  });

  final int ordinal;
  final int? elapsedSeconds;
  final CircuitRoundCompletionState state;
  final int? startedAtMs;
  final int? finishedAtMs;

  bool get isCompleted =>
      state == CircuitRoundCompletionState.completed && elapsedSeconds != null;

  Map<String, dynamic> toJson() => {
    'ordinal': ordinal,
    if (elapsedSeconds != null) 'elapsedSeconds': elapsedSeconds,
    'state': state.name,
    if (startedAtMs != null) 'startedAtMs': startedAtMs,
    if (finishedAtMs != null) 'finishedAtMs': finishedAtMs,
  };

  factory CircuitRoundActual.fromJson(Map<String, dynamic> json) {
    return CircuitRoundActual(
      ordinal: _int(json['ordinal']),
      elapsedSeconds: _nullableInt(json['elapsedSeconds']),
      state: CircuitRoundCompletionState.values.firstWhere(
        (value) => value.name == json['state']?.toString(),
        orElse: () => CircuitRoundCompletionState.pending,
      ),
      startedAtMs: _nullableInt(json['startedAtMs']),
      finishedAtMs: _nullableInt(json['finishedAtMs']),
    );
  }

  CircuitRoundActual copyWith({
    int? elapsedSeconds,
    CircuitRoundCompletionState? state,
    int? startedAtMs,
    int? finishedAtMs,
    bool clearElapsed = false,
    bool clearStarted = false,
    bool clearFinished = false,
  }) {
    return CircuitRoundActual(
      ordinal: ordinal,
      elapsedSeconds: clearElapsed
          ? null
          : (elapsedSeconds ?? this.elapsedSeconds),
      state: state ?? this.state,
      startedAtMs: clearStarted ? null : (startedAtMs ?? this.startedAtMs),
      finishedAtMs: clearFinished ? null : (finishedAtMs ?? this.finishedAtMs),
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
}

class CircuitSharedSetup {
  const CircuitSharedSetup({
    required this.stationId,
    required this.displayName,
    this.loadKg,
    this.loadUnit = 'kg',
  });

  final String stationId;
  final String displayName;
  final double? loadKg;
  final String loadUnit;

  Map<String, dynamic> toJson() => {
    'stationId': stationId,
    'displayName': displayName,
    if (loadKg != null) 'loadKg': loadKg,
    'loadUnit': loadUnit,
  };

  factory CircuitSharedSetup.fromJson(Map<String, dynamic> json) {
    return CircuitSharedSetup(
      stationId: json['stationId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      loadKg: _nullableDouble(json['loadKg'] ?? json['load']),
      loadUnit: json['loadUnit']?.toString() ?? 'kg',
    );
  }

  CircuitSharedSetup copyWith({double? loadKg, bool clearLoad = false}) {
    return CircuitSharedSetup(
      stationId: stationId,
      displayName: displayName,
      loadKg: clearLoad ? null : (loadKg ?? this.loadKg),
      loadUnit: loadUnit,
    );
  }

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
