import 'circuit_data_source.dart';
import 'circuit_format.dart';
import 'circuit_score_type.dart';

/// Persisted circuit performance for one training session attempt.
///
/// Maps to `training_session_circuits`.
/// See `07 Documentation/39_Circuit_Execution_Engine.md`.
class CircuitPerformance {
  const CircuitPerformance({
    required this.id,
    required this.trainingSessionId,
    required this.protocolId,
    required this.circuitFormat,
    required this.scoreType,
    required this.completed,
    required this.timeCapped,
    required this.skipped,
    required this.dataSource,
    this.elapsedDurationSeconds,
    this.completedRounds,
    this.additionalReps,
    this.totalReps,
    this.completedIntervals,
    this.completedMovements,
    this.prescribedLoad,
    this.actualLoad,
    this.rpe,
    this.athleteNote,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int trainingSessionId;
  final String protocolId;
  final CircuitFormat circuitFormat;
  final CircuitScoreType scoreType;
  final int? elapsedDurationSeconds;
  final int? completedRounds;
  final int? additionalReps;
  final int? totalReps;
  final int? completedIntervals;
  final int? completedMovements;
  final String? prescribedLoad;
  final String? actualLoad;
  final int? rpe;
  final bool completed;
  final bool timeCapped;
  final bool skipped;
  final CircuitDataSource dataSource;
  final String? athleteNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Duration? get elapsedDuration {
    if (elapsedDurationSeconds == null) {
      return null;
    }

    return Duration(seconds: elapsedDurationSeconds!);
  }

  factory CircuitPerformance.fromMap(Map<String, dynamic> map) {
    return CircuitPerformance(
      id: map['id'],
      trainingSessionId: map['training_session_id'],
      protocolId: map['protocol_id'].toString(),
      circuitFormat:
          CircuitFormatDb.fromDb(map['circuit_format']?.toString()),
      scoreType: CircuitScoreTypeDb.fromDb(map['score_type']?.toString()),
      elapsedDurationSeconds: _nullableInt(map['elapsed_duration_seconds']),
      completedRounds: _nullableInt(map['completed_rounds']),
      additionalReps: _nullableInt(map['additional_reps']),
      totalReps: _nullableInt(map['total_reps']),
      completedIntervals: _nullableInt(map['completed_intervals']),
      completedMovements: _nullableInt(map['completed_movements']),
      prescribedLoad: _trimString(map['prescribed_load']),
      actualLoad: _trimString(map['actual_load']),
      rpe: _nullableInt(map['rpe']),
      completed: map['completed'] == true,
      timeCapped: map['time_capped'] == true,
      skipped: map['skipped'] == true,
      dataSource: CircuitDataSource.fromDb(map['data_source']?.toString()),
      athleteNote: _trimString(map['athlete_note']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    final now = DateTime.now().toUtc().toIso8601String();

    return {
      'training_session_id': trainingSessionId,
      'protocol_id': protocolId,
      'circuit_format': circuitFormat.dbValue,
      'score_type': scoreType.dbValue,
      if (elapsedDurationSeconds != null)
        'elapsed_duration_seconds': elapsedDurationSeconds,
      if (completedRounds != null) 'completed_rounds': completedRounds,
      if (additionalReps != null) 'additional_reps': additionalReps,
      if (totalReps != null) 'total_reps': totalReps,
      if (completedIntervals != null)
        'completed_intervals': completedIntervals,
      if (completedMovements != null)
        'completed_movements': completedMovements,
      if (prescribedLoad != null) 'prescribed_load': prescribedLoad,
      if (actualLoad != null) 'actual_load': actualLoad,
      if (rpe != null) 'rpe': rpe,
      'completed': completed,
      'time_capped': timeCapped,
      'skipped': skipped,
      'data_source': dataSource.dbValue,
      if (athleteNote != null) 'athlete_note': athleteNote,
      'updated_at': now,
    };
  }

  static String? _trimString(dynamic value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}

/// Database vocabulary for [CircuitFormat].
extension CircuitFormatDb on CircuitFormat {
  String get dbValue {
    return switch (this) {
      CircuitFormat.amrap => 'amrap',
      CircuitFormat.forTime => 'for_time',
      CircuitFormat.roundsForTime => 'rounds_for_time',
      CircuitFormat.emom => 'emom',
      CircuitFormat.intervalClock => 'interval_clock',
      CircuitFormat.chipper => 'chipper',
      CircuitFormat.fixedDuration => 'fixed_duration',
      CircuitFormat.benchmark => 'benchmark',
    };
  }

  static CircuitFormat fromDb(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'amrap' => CircuitFormat.amrap,
      'for_time' || 'fortime' => CircuitFormat.forTime,
      'rounds_for_time' || 'roundsfortime' => CircuitFormat.roundsForTime,
      'emom' => CircuitFormat.emom,
      'interval_clock' || 'intervalclock' => CircuitFormat.intervalClock,
      'chipper' => CircuitFormat.chipper,
      'fixed_duration' || 'fixedduration' => CircuitFormat.fixedDuration,
      'benchmark' => CircuitFormat.benchmark,
      _ => CircuitFormat.amrap,
    };
  }
}

/// Database vocabulary for [CircuitScoreType].
extension CircuitScoreTypeDb on CircuitScoreType {
  String get dbValue {
    return switch (this) {
      CircuitScoreType.roundsAndReps => 'rounds_and_reps',
      CircuitScoreType.elapsedTime => 'elapsed_time',
      CircuitScoreType.roundsCompleted => 'rounds_completed',
      CircuitScoreType.totalReps => 'total_reps',
      CircuitScoreType.movementsCompleted => 'movements_completed',
      CircuitScoreType.benchmarkScore => 'benchmark_score',
    };
  }

  static CircuitScoreType fromDb(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'rounds_and_reps' || 'roundsandreps' => CircuitScoreType.roundsAndReps,
      'elapsed_time' || 'elapsedtime' => CircuitScoreType.elapsedTime,
      'rounds_completed' || 'roundscompleted' =>
        CircuitScoreType.roundsCompleted,
      'total_reps' || 'totalreps' => CircuitScoreType.totalReps,
      'movements_completed' || 'movementscompleted' =>
        CircuitScoreType.movementsCompleted,
      'benchmark_score' || 'benchmarkscore' =>
        CircuitScoreType.benchmarkScore,
      _ => CircuitScoreType.roundsAndReps,
    };
  }
}
