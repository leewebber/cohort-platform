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
      case PerformanceResultType.customMetric:
        return CustomMetricResultData.fromJson(json);
      case PerformanceResultType.completion:
        return CompletionResultData.fromJson(json);
    }
  }
}

class CompletionResultData extends PerformanceResultData {
  const CompletionResultData({
    this.completed = true,
    this.note,
  });

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
    this.note,
  });

  final int rounds;
  final int extraReps;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.amrap;

  @override
  Map<String, dynamic> toJson() => {
        'resultType': resultType.dbValue,
        'rounds': rounds,
        'extraReps': extraReps,
        if (note != null) 'note': note,
      };

  factory AmrapResultData.fromJson(Map<String, dynamic> json) {
    return AmrapResultData(
      rounds: _int(json['rounds']),
      extraReps: _int(json['extraReps']),
      note: _trim(json['note']),
    );
  }

  AmrapResultData copyWith({int? rounds, int? extraReps, String? note}) {
    return AmrapResultData(
      rounds: rounds ?? this.rounds,
      extraReps: extraReps ?? this.extraReps,
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
    this.note,
  });

  final int intervalsCompleted;
  final int? totalIntervals;
  final double? totalDistance;
  final String? distanceUnit;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.interval;

  @override
  Map<String, dynamic> toJson() => {
        'resultType': resultType.dbValue,
        'intervalsCompleted': intervalsCompleted,
        if (totalIntervals != null) 'totalIntervals': totalIntervals,
        if (totalDistance != null) 'totalDistance': totalDistance,
        if (distanceUnit != null) 'distanceUnit': distanceUnit,
        if (note != null) 'note': note,
      };

  factory IntervalResultData.fromJson(Map<String, dynamic> json) {
    return IntervalResultData(
      intervalsCompleted: _int(json['intervalsCompleted']),
      totalIntervals: _nullableInt(json['totalIntervals']),
      totalDistance: _nullableDouble(json['totalDistance']),
      distanceUnit: _trim(json['distanceUnit']),
      note: _trim(json['note']),
    );
  }

  IntervalResultData copyWith({
    int? intervalsCompleted,
    int? totalIntervals,
    double? totalDistance,
    String? distanceUnit,
    String? note,
  }) {
    return IntervalResultData(
      intervalsCompleted: intervalsCompleted ?? this.intervalsCompleted,
      totalIntervals: totalIntervals ?? this.totalIntervals,
      totalDistance: totalDistance ?? this.totalDistance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      note: note ?? this.note,
    );
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
  const DurationResultData({
    this.durationSeconds,
    this.note,
  });

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
    this.note,
  });

  final int roundsCompleted;
  final int extraReps;
  final int? elapsedSeconds;
  final String? note;

  @override
  PerformanceResultType get resultType => PerformanceResultType.rounds;

  @override
  Map<String, dynamic> toJson() => {
        'resultType': resultType.dbValue,
        'roundsCompleted': roundsCompleted,
        'extraReps': extraReps,
        if (elapsedSeconds != null) 'elapsedSeconds': elapsedSeconds,
        if (note != null) 'note': note,
      };

  factory RoundsResultData.fromJson(Map<String, dynamic> json) {
    return RoundsResultData(
      roundsCompleted: _int(json['roundsCompleted']),
      extraReps: _int(json['extraReps']),
      elapsedSeconds: _nullableInt(json['elapsedSeconds']),
      note: _trim(json['note']),
    );
  }

  RoundsResultData copyWith({
    int? roundsCompleted,
    int? extraReps,
    int? elapsedSeconds,
    String? note,
  }) {
    return RoundsResultData(
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      extraReps: extraReps ?? this.extraReps,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      note: note ?? this.note,
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
