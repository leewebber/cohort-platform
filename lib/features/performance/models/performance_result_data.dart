import '../../../models/circuit_capture_strategy.dart';
import 'circuit_round_actual.dart';
import 'circuit_station_actual.dart';
import 'interval_work_result.dart';
import 'performance_result_type.dart';

sealed class PerformanceResultData {
  const PerformanceResultData();

  PerformanceResultType get resultType;

  Map<String, dynamic> toJson();

  static PerformanceResultData fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const CompletionResultData();
    }

    final type = PerformanceResultTypeDb.fromDb(json['resultType']?.toString());
    switch (type) {
      case PerformanceResultType.strength:
        return StrengthResultData.fromJson(json);
      case PerformanceResultType.amrap:
        return AmrapResultData.fromJson(json);
      case PerformanceResultType.forTime:
        return ForTimeResultData.fromJson(json);
      case PerformanceResultType.interval:
        return IntervalResultData.fromJson(json);
      case PerformanceResultType.distance:
        return DistanceResultData.fromJson(json);
      case PerformanceResultType.duration:
        return DurationResultData.fromJson(json);
      case PerformanceResultType.endurance:
        return EnduranceResultData.fromJson(json);
      case PerformanceResultType.rounds:
        return RoundsResultData.fromJson(json);
      case PerformanceResultType.circuit:
        return CircuitResultData.fromJson(json);
      case PerformanceResultType.customMetric:
        return CustomMetricResultData.fromJson(json);
      case PerformanceResultType.completion:
        return CompletionResultData.fromJson(json);
    }
  }
}

class CompletionResultData extends PerformanceResultData {
  const CompletionResultData({this.completed = true, this.note});

  final bool completed;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.completion;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    'completed': completed,
    if (note != null) 'note': note,
  };

  factory CompletionResultData.fromJson(Map<String, dynamic> json) {
    return CompletionResultData(
      completed: json['completed'] != false,
      note: _trim(json['note']),
    );
  }

  CompletionResultData copyWith({bool? completed, String? note}) {
    return CompletionResultData(
      completed: completed ?? this.completed,
      note: note ?? this.note,
    );
  }
}

class StrengthResultData extends PerformanceResultData {
  const StrengthResultData({this.note});

  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.strength;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    if (note != null) 'note': note,
  };

  factory StrengthResultData.fromJson(Map<String, dynamic> json) {
    return StrengthResultData(note: _trim(json['note']));
  }
}

class AmrapResultData extends PerformanceResultData {
  const AmrapResultData({
    this.rounds = 0,
    this.extraReps = 0,
    this.entered = false,
    this.note,
  });

  final int rounds;
  final int extraReps;
  final bool entered;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.amrap;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    'rounds': rounds,
    'extraReps': extraReps,
    'entered': entered,
    if (note != null) 'note': note,
  };

  factory AmrapResultData.fromJson(Map<String, dynamic> json) {
    return AmrapResultData(
      rounds: _int(json['rounds']),
      extraReps: _int(json['extraReps']),
      entered: json['entered'] == true,
      note: _trim(json['note']),
    );
  }

  AmrapResultData copyWith({
    int? rounds,
    int? extraReps,
    bool? entered,
    String? note,
  }) {
    return AmrapResultData(
      rounds: rounds ?? this.rounds,
      extraReps: extraReps ?? this.extraReps,
      entered:
          entered ??
          (rounds != null || extraReps != null ? true : this.entered),
      note: note ?? this.note,
    );
  }
}

class ForTimeResultData extends PerformanceResultData {
  const ForTimeResultData({
    this.elapsedSeconds,
    this.completed = true,
    this.timeCapped = false,
    this.remainingWorkNote,
    this.note,
  });

  final int? elapsedSeconds;
  final bool completed;
  final bool timeCapped;
  final String? remainingWorkNote;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.forTime;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    if (elapsedSeconds != null) 'elapsedSeconds': elapsedSeconds,
    'completed': completed,
    'timeCapped': timeCapped,
    if (remainingWorkNote != null) 'remainingWorkNote': remainingWorkNote,
    if (note != null) 'note': note,
  };

  factory ForTimeResultData.fromJson(Map<String, dynamic> json) {
    return ForTimeResultData(
      elapsedSeconds: _nullableInt(json['elapsedSeconds']),
      completed: json['completed'] != false,
      timeCapped: json['timeCapped'] == true,
      remainingWorkNote: _trim(json['remainingWorkNote']),
      note: _trim(json['note']),
    );
  }

  ForTimeResultData copyWith({
    int? elapsedSeconds,
    bool? completed,
    bool? timeCapped,
    String? remainingWorkNote,
    String? note,
  }) {
    return ForTimeResultData(
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      completed: completed ?? this.completed,
      timeCapped: timeCapped ?? this.timeCapped,
      remainingWorkNote: remainingWorkNote ?? this.remainingWorkNote,
      note: note ?? this.note,
    );
  }
}

class IntervalResultData extends PerformanceResultData {
  const IntervalResultData({
    this.intervalsCompleted = 0,
    this.totalIntervals,
    this.totalDistance,
    this.distanceUnit,
    this.entered = false,
    this.note,
    this.workSeconds,
    this.paceUnit = IntervalPaceUnit.secondsPerKm,
    this.comparisonFamily,
    this.intervals = const [],
  });

  final int intervalsCompleted;
  final int? totalIntervals;
  final double? totalDistance;
  final String? distanceUnit;
  final bool entered;
  final String? note;
  final int? workSeconds;
  final String paceUnit;
  final String? comparisonFamily;
  final List<IntervalWorkResult> intervals;

  bool get usesPerIntervalCapture => intervals.isNotEmpty;

  int get recordedCount {
    if (usesPerIntervalCapture) {
      return intervals.where((row) => row.state.countsAsCompleted).length;
    }
    return intervalsCompleted;
  }

  int? get prescribedCount =>
      totalIntervals ?? (usesPerIntervalCapture ? intervals.length : null);

  @override
  PerformanceResultType get resultType => PerformanceResultType.interval;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    'intervalsCompleted': recordedCount,
    if (totalIntervals != null) 'totalIntervals': totalIntervals,
    if (totalDistance != null) 'totalDistance': totalDistance,
    if (distanceUnit != null) 'distanceUnit': distanceUnit,
    'entered': entered || recordedCount > 0,
    if (note != null) 'note': note,
    if (workSeconds != null) 'workSeconds': workSeconds,
    'paceUnit': paceUnit,
    if (comparisonFamily != null) 'comparisonFamily': comparisonFamily,
    if (intervals.isNotEmpty)
      'intervals': intervals.map((row) => row.toJson()).toList(),
  };

  factory IntervalResultData.fromJson(Map<String, dynamic> json) {
    final rawIntervals = json['intervals'];
    final parsed = rawIntervals is List
        ? rawIntervals
              .whereType<Map>()
              .map(
                (item) => IntervalWorkResult.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((row) => row.ordinal > 0)
              .toList(growable: false)
        : const <IntervalWorkResult>[];
    return IntervalResultData(
      intervalsCompleted: _int(json['intervalsCompleted']),
      totalIntervals: _nullableInt(json['totalIntervals']),
      totalDistance: _nullableDouble(json['totalDistance']),
      distanceUnit: _trim(json['distanceUnit']),
      entered: json['entered'] == true,
      note: _trim(json['note']),
      workSeconds: _nullableInt(json['workSeconds'] ?? json['work_seconds']),
      paceUnit: _trim(json['paceUnit']) ?? IntervalPaceUnit.secondsPerKm,
      comparisonFamily: _trim(json['comparisonFamily']),
      intervals: parsed,
    );
  }

  IntervalResultData copyWith({
    int? intervalsCompleted,
    int? totalIntervals,
    double? totalDistance,
    String? distanceUnit,
    bool? entered,
    String? note,
    int? workSeconds,
    String? paceUnit,
    String? comparisonFamily,
    List<IntervalWorkResult>? intervals,
  }) {
    final nextIntervals = intervals ?? this.intervals;
    return IntervalResultData(
      intervalsCompleted: intervalsCompleted ?? this.intervalsCompleted,
      totalIntervals: totalIntervals ?? this.totalIntervals,
      totalDistance: totalDistance ?? this.totalDistance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      entered:
          entered ??
          (intervals != null ||
                  intervalsCompleted != null ||
                  totalDistance != null ||
                  distanceUnit != null
              ? true
              : this.entered),
      note: note ?? this.note,
      workSeconds: workSeconds ?? this.workSeconds,
      paceUnit: paceUnit ?? this.paceUnit,
      comparisonFamily: comparisonFamily ?? this.comparisonFamily,
      intervals: nextIntervals,
    );
  }

  IntervalResultData replaceInterval(IntervalWorkResult row) {
    if (intervals.isEmpty) {
      return copyWith(intervals: [row], entered: row.state.countsAsCompleted);
    }
    final next = intervals
        .map((current) => current.ordinal == row.ordinal ? row : current)
        .toList(growable: false);
    return copyWith(intervals: next, entered: true);
  }
}

class DistanceResultData extends PerformanceResultData {
  const DistanceResultData({
    this.distance,
    this.distanceUnit = 'km',
    this.durationSeconds,
    this.note,
  });

  final double? distance;
  final String distanceUnit;
  final int? durationSeconds;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.distance;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    if (distance != null) 'distance': distance,
    'distanceUnit': distanceUnit,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (note != null) 'note': note,
  };

  factory DistanceResultData.fromJson(Map<String, dynamic> json) {
    return DistanceResultData(
      distance: _nullableDouble(json['distance']),
      distanceUnit: _trim(json['distanceUnit']) ?? 'km',
      durationSeconds: _nullableInt(json['durationSeconds']),
      note: _trim(json['note']),
    );
  }

  DistanceResultData copyWith({
    double? distance,
    String? distanceUnit,
    int? durationSeconds,
    String? note,
  }) {
    return DistanceResultData(
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      note: note ?? this.note,
    );
  }
}

class EnduranceResultData extends PerformanceResultData {
  const EnduranceResultData({
    this.completed = true,
    this.distance,
    this.distanceUnit = 'km',
    this.durationSeconds,
    this.averageHeartRate,
    this.note,
  });

  final bool completed;
  final double? distance;
  final String distanceUnit;
  final int? durationSeconds;
  final int? averageHeartRate;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.endurance;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    'completed': completed,
    if (distance != null) 'distance': distance,
    'distanceUnit': distanceUnit,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (note != null) 'note': note,
  };

  factory EnduranceResultData.fromJson(Map<String, dynamic> json) {
    return EnduranceResultData(
      completed: json['completed'] != false,
      distance: _nullableDouble(json['distance']),
      distanceUnit: _trim(json['distanceUnit']) ?? 'km',
      durationSeconds: _nullableInt(json['durationSeconds']),
      averageHeartRate: _nullableInt(json['averageHeartRate']),
      note: _trim(json['note']),
    );
  }

  EnduranceResultData copyWith({
    bool? completed,
    double? distance,
    String? distanceUnit,
    int? durationSeconds,
    int? averageHeartRate,
    String? note,
  }) {
    return EnduranceResultData(
      completed: completed ?? this.completed,
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      note: note ?? this.note,
    );
  }
}

class DurationResultData extends PerformanceResultData {
  const DurationResultData({this.durationSeconds, this.note});

  final int? durationSeconds;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.duration;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (note != null) 'note': note,
  };

  factory DurationResultData.fromJson(Map<String, dynamic> json) {
    return DurationResultData(
      durationSeconds: _nullableInt(json['durationSeconds']),
      note: _trim(json['note']),
    );
  }

  DurationResultData copyWith({int? durationSeconds, String? note}) {
    return DurationResultData(
      durationSeconds: durationSeconds ?? this.durationSeconds,
      note: note ?? this.note,
    );
  }
}

class RoundsResultData extends PerformanceResultData {
  const RoundsResultData({
    this.roundsCompleted = 0,
    this.extraReps = 0,
    this.elapsedSeconds,
    this.entered = false,
    this.note,
  });

  final int roundsCompleted;
  final int extraReps;
  final int? elapsedSeconds;
  final bool entered;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.rounds;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    'roundsCompleted': roundsCompleted,
    'extraReps': extraReps,
    if (elapsedSeconds != null) 'elapsedSeconds': elapsedSeconds,
    'entered': entered,
    if (note != null) 'note': note,
  };

  factory RoundsResultData.fromJson(Map<String, dynamic> json) {
    return RoundsResultData(
      roundsCompleted: _int(json['roundsCompleted']),
      extraReps: _int(json['extraReps']),
      elapsedSeconds: _nullableInt(json['elapsedSeconds']),
      entered: json['entered'] == true,
      note: _trim(json['note']),
    );
  }

  RoundsResultData copyWith({
    int? roundsCompleted,
    int? extraReps,
    int? elapsedSeconds,
    bool? entered,
    String? note,
  }) {
    return RoundsResultData(
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      extraReps: extraReps ?? this.extraReps,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      entered:
          entered ??
          (roundsCompleted != null ||
                  extraReps != null ||
                  elapsedSeconds != null
              ? true
              : this.entered),
      note: note ?? this.note,
    );
  }
}

class CircuitResultData extends PerformanceResultData {
  const CircuitResultData({
    required this.format,
    required this.comparisonFamily,
    required this.stations,
    this.captureStrategy = CircuitCaptureStrategy.variableOutput,
    this.sharedSetup = const [],
    this.rounds = const [],
    this.targetRounds,
    this.intervalSeconds,
    this.restBetweenRoundsSeconds,
    this.timerCursor,
    this.endedEarly = false,
    this.earlyEndReason,
    this.note,
    this.recordedCompletedRounds,
    this.prescribedTargetsUsed,
    this.scoreEntered = false,
  });

  final String format;
  final String comparisonFamily;
  final CircuitCaptureStrategy captureStrategy;
  final List<CircuitStationActual> stations;
  final List<CircuitSharedSetup> sharedSetup;
  final List<CircuitRoundActual> rounds;
  final int? targetRounds;
  final int? intervalSeconds;
  final int? restBetweenRoundsSeconds;
  final CircuitTimerCursor? timerCursor;
  final bool endedEarly;
  final String? earlyEndReason;
  final String? note;

  /// Canonical EMOM interval/round count. Athlete-facing copy says "intervals".
  final int? recordedCompletedRounds;
  final bool? prescribedTargetsUsed;
  final bool scoreEntered;

  bool get isFixedWork =>
      captureStrategy == CircuitCaptureStrategy.fixedWork;

  /// One timed EMOM minute is one canonical [completedRounds] unit.
  bool get isEmomScore => format == 'emom' && !isFixedWork;

  bool get usedInAppTimer =>
      timerCursor != null &&
      (timerCursor!.isFinished ||
          timerCursor!.isRunning ||
          timerCursor!.isPaused ||
          timerCursor!.currentRound > 1);

  bool get usesStationCapture =>
      !isFixedWork && !isEmomScore && stations.isNotEmpty;

  bool get usesCircuitCapture =>
      isFixedWork || isEmomScore || stations.isNotEmpty;

  int get recordedCount => isEmomScore
      ? completedRounds
      : isFixedWork
      ? rounds.where((round) => round.isCompleted).length
      : stations.where((row) => row.hasRecordedActual).length;

  int get prescribedCount => isEmomScore || isFixedWork
      ? (targetRounds ?? rounds.length)
      : stations.length;

  int get completedRounds {
    if (isEmomScore) {
      return recordedCompletedRounds ?? _derivedStationRounds;
    }
    if (isFixedWork) {
      return rounds.where((round) => round.isCompleted).length;
    }
    return _derivedStationRounds;
  }

  int get _derivedStationRounds {
    if (targetRounds == null || targetRounds! <= 0) return 0;
    final byRound = <int, List<CircuitStationActual>>{};
    for (final row in stations) {
      byRound.putIfAbsent(row.round, () => []).add(row);
    }
    var complete = 0;
    for (final entries in byRound.values) {
      if (entries.isNotEmpty &&
          entries.every((row) => row.hasRecordedActual)) {
        complete += 1;
      }
    }
    return complete;
  }

  List<int> get completedRoundSeconds =>
      rounds
          .where((round) => round.isCompleted)
          .map((round) => round.elapsedSeconds!)
          .toList(growable: false);

  int? get totalWorkSeconds {
    final times = completedRoundSeconds;
    if (times.isEmpty) return null;
    return times.fold<int>(0, (sum, value) => sum + value);
  }

  int? get averageRoundSeconds {
    final times = completedRoundSeconds;
    if (times.isEmpty) return null;
    return (times.fold<int>(0, (sum, value) => sum + value) / times.length)
        .round();
  }

  int? get fastestRoundSeconds {
    final times = completedRoundSeconds;
    if (times.isEmpty) return null;
    return times.reduce((a, b) => a < b ? a : b);
  }

  @override
  PerformanceResultType get resultType => PerformanceResultType.circuit;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    'format': format,
    'comparisonFamily': comparisonFamily,
    'captureStrategy': captureStrategy.dbValue,
    'stations': stations.map((row) => row.toJson()).toList(),
    if (sharedSetup.isNotEmpty)
      'sharedSetup': sharedSetup.map((row) => row.toJson()).toList(),
    if (rounds.isNotEmpty)
      'rounds': rounds.map((row) => row.toJson()).toList(),
    if (targetRounds != null) 'targetRounds': targetRounds,
    if (intervalSeconds != null) 'intervalSeconds': intervalSeconds,
    if (restBetweenRoundsSeconds != null)
      'restBetweenRoundsSeconds': restBetweenRoundsSeconds,
    if (timerCursor != null) 'timerCursor': timerCursor!.toJson(),
    'endedEarly': endedEarly,
    if (earlyEndReason != null) 'earlyEndReason': earlyEndReason,
    if (note != null) 'note': note,
    if (recordedCompletedRounds != null)
      'completedRounds': recordedCompletedRounds,
    if (prescribedTargetsUsed != null)
      'prescribedTargetsUsed': prescribedTargetsUsed,
    'scoreEntered': scoreEntered,
  };

  factory CircuitResultData.fromJson(Map<String, dynamic> json) {
    final raw = json['stations'];
    final parsed = raw is List
        ? raw
              .whereType<Map>()
              .map(
                (item) => CircuitStationActual.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((row) => row.ordinal > 0)
              .toList(growable: false)
        : const <CircuitStationActual>[];
    final rawRounds = json['rounds'];
    final parsedRounds = rawRounds is List
        ? rawRounds
              .whereType<Map>()
              .map(
                (item) => CircuitRoundActual.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((row) => row.ordinal > 0)
              .toList(growable: false)
        : const <CircuitRoundActual>[];
    final rawSetup = json['sharedSetup'];
    final parsedSetup = rawSetup is List
        ? rawSetup
              .whereType<Map>()
              .map(
                (item) => CircuitSharedSetup.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((row) => row.stationId.isNotEmpty)
              .toList(growable: false)
        : const <CircuitSharedSetup>[];
    final strategy = CircuitCaptureStrategyDb.tryParse(
      json['captureStrategy']?.toString(),
    );
    // Legacy drafts without an explicit strategy stay variable-output.
    // Never reinterpret 12 station rows as round times.
    return CircuitResultData(
      format: json['format']?.toString() ?? 'rounds',
      comparisonFamily: json['comparisonFamily']?.toString() ?? '',
      captureStrategy: strategy ?? CircuitCaptureStrategy.variableOutput,
      stations: parsed,
      sharedSetup: parsedSetup,
      rounds: parsedRounds,
      targetRounds: _nullableInt(json['targetRounds']),
      intervalSeconds: _nullableInt(json['intervalSeconds']),
      restBetweenRoundsSeconds: _nullableInt(json['restBetweenRoundsSeconds']),
      timerCursor: json['timerCursor'] is Map
          ? CircuitTimerCursor.fromJson(
              Map<String, dynamic>.from(json['timerCursor'] as Map),
            )
          : null,
      endedEarly: json['endedEarly'] == true,
      earlyEndReason: _trim(json['earlyEndReason']),
      note: _trim(json['note']),
      recordedCompletedRounds: _nullableInt(json['completedRounds']),
      prescribedTargetsUsed: json['prescribedTargetsUsed'] is bool
          ? json['prescribedTargetsUsed'] as bool
          : null,
      scoreEntered:
          json['scoreEntered'] == true || json['completedRounds'] != null,
    );
  }

  CircuitResultData copyWith({
    List<CircuitStationActual>? stations,
    List<CircuitSharedSetup>? sharedSetup,
    List<CircuitRoundActual>? rounds,
    int? targetRounds,
    int? intervalSeconds,
    CircuitTimerCursor? timerCursor,
    bool? endedEarly,
    String? earlyEndReason,
    String? note,
    int? recordedCompletedRounds,
    bool? prescribedTargetsUsed,
    bool? scoreEntered,
    bool clearTimerCursor = false,
    bool clearEarlyEndReason = false,
    bool clearRecordedCompletedRounds = false,
    bool clearPrescribedTargetsUsed = false,
  }) {
    return CircuitResultData(
      format: format,
      comparisonFamily: comparisonFamily,
      captureStrategy: captureStrategy,
      stations: stations ?? this.stations,
      sharedSetup: sharedSetup ?? this.sharedSetup,
      rounds: rounds ?? this.rounds,
      targetRounds: targetRounds ?? this.targetRounds,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      restBetweenRoundsSeconds: restBetweenRoundsSeconds,
      timerCursor: clearTimerCursor ? null : (timerCursor ?? this.timerCursor),
      endedEarly: endedEarly ?? this.endedEarly,
      earlyEndReason: clearEarlyEndReason
          ? null
          : (earlyEndReason ?? this.earlyEndReason),
      note: note ?? this.note,
      recordedCompletedRounds: clearRecordedCompletedRounds
          ? null
          : (recordedCompletedRounds ?? this.recordedCompletedRounds),
      prescribedTargetsUsed: clearPrescribedTargetsUsed
          ? null
          : (prescribedTargetsUsed ?? this.prescribedTargetsUsed),
      scoreEntered: scoreEntered ?? this.scoreEntered,
    );
  }

  CircuitResultData replaceStation(CircuitStationActual row) {
    if (stations.isEmpty) return copyWith(stations: [row]);
    return copyWith(
      stations: [
        for (final current in stations)
          current.ordinal == row.ordinal ? row : current,
      ],
    );
  }

  CircuitResultData replaceSetup(CircuitSharedSetup row) {
    return copyWith(
      sharedSetup: [
        for (final current in sharedSetup)
          current.stationId == row.stationId ? row : current,
      ],
    );
  }

  CircuitResultData replaceRound(CircuitRoundActual row) {
    return copyWith(
      rounds: [
        for (final current in rounds)
          current.ordinal == row.ordinal ? row : current,
      ],
    );
  }
}

class CustomMetricResultData extends PerformanceResultData {
  const CustomMetricResultData({
    this.label,
    this.numericValue,
    this.unit,
    this.textValue,
    this.note,
  });

  final String? label;
  final double? numericValue;
  final String? unit;
  final String? textValue;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.customMetric;

  @override
  Map<String, dynamic> toJson() => {
    'resultType': resultType.dbValue,
    if (label != null) 'label': label,
    if (numericValue != null) 'numericValue': numericValue,
    if (unit != null) 'unit': unit,
    if (textValue != null) 'textValue': textValue,
    if (note != null) 'note': note,
  };

  factory CustomMetricResultData.fromJson(Map<String, dynamic> json) {
    return CustomMetricResultData(
      label: _trim(json['label']),
      numericValue: _nullableDouble(json['numericValue']),
      unit: _trim(json['unit']),
      textValue: _trim(json['textValue']),
      note: _trim(json['note']),
    );
  }

  CustomMetricResultData copyWith({
    String? label,
    double? numericValue,
    String? unit,
    String? textValue,
    String? note,
  }) {
    return CustomMetricResultData(
      label: label ?? this.label,
      numericValue: numericValue ?? this.numericValue,
      unit: unit ?? this.unit,
      textValue: textValue ?? this.textValue,
      note: note ?? this.note,
    );
  }
}

String? _trim(dynamic value) {
  final trimmed = value?.toString().trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

int _int(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value.toString());
}
