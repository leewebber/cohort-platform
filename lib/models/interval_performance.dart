import 'interval_data_source.dart';
import 'interval_modality.dart';
import 'interval_phase_type.dart';

/// Persisted interval phase performance for one session timeline row.
///
/// Maps to `training_session_intervals`.
/// See `07 Documentation/37_Interval_Execution_Engine.md`.
class IntervalPerformance {
  const IntervalPerformance({
    required this.id,
    required this.trainingSessionId,
    required this.blockIndex,
    required this.repNumber,
    required this.phaseType,
    required this.modality,
    required this.completed,
    required this.skipped,
    required this.dataSource,
    this.protocolStepId,
    this.targetDistanceMeters,
    this.targetDurationSeconds,
    this.targetPaceSecondsPerKm,
    this.targetIntensity,
    this.recoveryDurationSeconds,
    this.actualDistanceMeters,
    this.actualDurationSeconds,
    this.actualPaceSecondsPerKm,
    this.averageHeartRate,
    this.maxHeartRate,
    this.rpe,
    this.athleteNote,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int trainingSessionId;
  final int? protocolStepId;
  final int blockIndex;
  final int repNumber;
  final IntervalPhaseType phaseType;
  final IntervalModality modality;
  final double? targetDistanceMeters;
  final int? targetDurationSeconds;
  final double? targetPaceSecondsPerKm;
  final String? targetIntensity;
  final int? recoveryDurationSeconds;
  final double? actualDistanceMeters;
  final int? actualDurationSeconds;
  final double? actualPaceSecondsPerKm;
  final int? averageHeartRate;
  final int? maxHeartRate;
  final int? rpe;
  final bool completed;
  final bool skipped;
  final IntervalDataSource dataSource;
  final String? athleteNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory IntervalPerformance.fromMap(Map<String, dynamic> map) {
    return IntervalPerformance(
      id: map['id'],
      trainingSessionId: map['training_session_id'],
      protocolStepId: _nullableInt(map['protocol_step_id']),
      blockIndex: map['block_index'],
      repNumber: map['rep_number'],
      phaseType: IntervalPhaseTypeDb.fromDb(map['phase_type']?.toString()),
      modality: IntervalModalityDb.fromDb(map['modality']?.toString()),
      targetDistanceMeters: _nullableDouble(map['target_distance_meters']),
      targetDurationSeconds: _nullableInt(map['target_duration_seconds']),
      targetPaceSecondsPerKm:
          _nullableDouble(map['target_pace_seconds_per_km']),
      targetIntensity: _trimString(map['target_intensity']),
      recoveryDurationSeconds: _nullableInt(map['recovery_duration_seconds']),
      actualDistanceMeters: _nullableDouble(map['actual_distance_meters']),
      actualDurationSeconds: _nullableInt(map['actual_duration_seconds']),
      actualPaceSecondsPerKm: _nullableDouble(map['actual_pace_seconds_per_km']),
      averageHeartRate: _nullableInt(map['average_heart_rate']),
      maxHeartRate: _nullableInt(map['max_heart_rate']),
      rpe: _nullableInt(map['rpe']),
      completed: map['completed'] == true,
      skipped: map['skipped'] == true,
      dataSource: IntervalDataSource.fromDb(map['data_source']?.toString()),
      athleteNote: _trimString(map['athlete_note']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    final now = DateTime.now().toUtc().toIso8601String();

    return {
      'training_session_id': trainingSessionId,
      if (protocolStepId != null) 'protocol_step_id': protocolStepId,
      'block_index': blockIndex,
      'rep_number': repNumber,
      'phase_type': phaseType.dbValue,
      'modality': modality.dbValue,
      if (targetDistanceMeters != null)
        'target_distance_meters': targetDistanceMeters,
      if (targetDurationSeconds != null)
        'target_duration_seconds': targetDurationSeconds,
      if (targetPaceSecondsPerKm != null)
        'target_pace_seconds_per_km': targetPaceSecondsPerKm,
      if (targetIntensity != null) 'target_intensity': targetIntensity,
      if (recoveryDurationSeconds != null)
        'recovery_duration_seconds': recoveryDurationSeconds,
      if (actualDistanceMeters != null)
        'actual_distance_meters': actualDistanceMeters,
      if (actualDurationSeconds != null)
        'actual_duration_seconds': actualDurationSeconds,
      if (actualPaceSecondsPerKm != null)
        'actual_pace_seconds_per_km': actualPaceSecondsPerKm,
      if (averageHeartRate != null) 'average_heart_rate': averageHeartRate,
      if (maxHeartRate != null) 'max_heart_rate': maxHeartRate,
      if (rpe != null) 'rpe': rpe,
      'completed': completed,
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

  static double? _nullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is int) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}

/// Database vocabulary for [IntervalPhaseType].
extension IntervalPhaseTypeDb on IntervalPhaseType {
  String get dbValue {
    return switch (this) {
      IntervalPhaseType.warmUp => 'warm_up',
      IntervalPhaseType.work => 'work',
      IntervalPhaseType.recovery => 'recovery',
      IntervalPhaseType.coolDown => 'cool_down',
      IntervalPhaseType.instruction => 'instruction',
    };
  }

  static IntervalPhaseType fromDb(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'warm_up' || 'warmup' => IntervalPhaseType.warmUp,
      'work' => IntervalPhaseType.work,
      'recovery' => IntervalPhaseType.recovery,
      'cool_down' || 'cooldown' => IntervalPhaseType.coolDown,
      'instruction' => IntervalPhaseType.instruction,
      _ => IntervalPhaseType.instruction,
    };
  }
}

/// Database vocabulary for [IntervalModality].
extension IntervalModalityDb on IntervalModality {
  String get dbValue => name;

  static IntervalModality fromDb(String? value) {
    final normalized = value?.trim().toLowerCase();
    for (final modality in IntervalModality.values) {
      if (modality.name == normalized) {
        return modality;
      }
    }

    return IntervalModality.other;
  }
}
