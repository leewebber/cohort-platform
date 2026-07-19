import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';
import 'performance_result_data.dart';
import 'performance_result_type.dart';
import 'performance_snapshot.dart';
import 'training_block_result_status.dart';
import 'training_session_record_status.dart';

class TrainingSetResult {
  const TrainingSetResult({
    required this.setResultId,
    required this.exerciseResultId,
    required this.setNumber,
    required this.position,
    this.reps,
    this.load,
    this.loadUnit,
    this.distance,
    this.distanceUnit,
    this.durationSeconds,
    this.completed = false,
    this.rpe,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String setResultId;
  final String exerciseResultId;
  final int setNumber;
  final int position;
  final int? reps;
  final double? load;
  final String? loadUnit;
  final double? distance;
  final String? distanceUnit;
  final int? durationSeconds;
  final bool completed;
  final int? rpe;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TrainingSetResult.fromMap(Map<String, dynamic> map) {
    return TrainingSetResult(
      setResultId: map['set_result_id']?.toString() ?? '',
      exerciseResultId: map['exercise_result_id']?.toString() ?? '',
      setNumber: map['set_number'] ?? 0,
      position: map['position'] ?? 0,
      reps: _nullableInt(map['reps']),
      load: _nullableDouble(map['load']),
      loadUnit: _trim(map['load_unit']),
      distance: _nullableDouble(map['distance']),
      distanceUnit: _trim(map['distance_unit']),
      durationSeconds: _nullableInt(map['duration_seconds']),
      completed: map['completed'] == true,
      rpe: _nullableInt(map['rpe']),
      note: _trim(map['note']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'set_result_id': setResultId,
      'exercise_result_id': exerciseResultId,
      'set_number': setNumber,
      'position': position,
      if (reps != null) 'reps': reps,
      if (load != null) 'load': load,
      if (loadUnit != null) 'load_unit': loadUnit,
      if (distance != null) 'distance': distance,
      if (distanceUnit != null) 'distance_unit': distanceUnit,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'completed': completed,
      if (rpe != null) 'rpe': rpe,
      if (note != null) 'note': note,
    };
  }
}

class TrainingExerciseResult {
  const TrainingExerciseResult({
    required this.exerciseResultId,
    required this.blockResultId,
    required this.sourceExerciseId,
    required this.exerciseSnapshot,
    required this.position,
    this.athleteNote,
    this.setResults = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String exerciseResultId;
  final String blockResultId;
  final String sourceExerciseId;
  final ExercisePerformanceSnapshot exerciseSnapshot;
  final int position;
  final String? athleteNote;
  final List<TrainingSetResult> setResults;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TrainingExerciseResult.fromMap(
    Map<String, dynamic> map, {
    List<TrainingSetResult> setResults = const [],
  }) {
    final snapshotJson = map['exercise_snapshot'];
    return TrainingExerciseResult(
      exerciseResultId: map['exercise_result_id']?.toString() ?? '',
      blockResultId: map['block_result_id']?.toString() ?? '',
      sourceExerciseId: map['source_exercise_id']?.toString() ?? '',
      exerciseSnapshot: snapshotJson is Map
          ? ExercisePerformanceSnapshot.fromJson(
              Map<String, dynamic>.from(snapshotJson),
            )
          : ExercisePerformanceSnapshot(
              sourceExerciseId: map['source_exercise_id']?.toString() ?? '',
              displayName: '',
              position: map['position'] ?? 0,
            ),
      position: map['position'] ?? 0,
      athleteNote: _trim(map['athlete_note']),
      setResults: setResults,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'exercise_result_id': exerciseResultId,
      'block_result_id': blockResultId,
      'source_exercise_id': sourceExerciseId,
      'exercise_snapshot': exerciseSnapshot.toJson(),
      'position': position,
      if (athleteNote != null) 'athlete_note': athleteNote,
    };
  }
}

class TrainingBlockResult {
  const TrainingBlockResult({
    required this.blockResultId,
    required this.sessionRecordId,
    required this.sourceBlockId,
    required this.blockSnapshot,
    required this.status,
    required this.resultType,
    required this.position,
    this.resultData,
    this.athleteNote,
    this.startedAt,
    this.completedAt,
    this.durationSeconds,
    this.exerciseResults = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String blockResultId;
  final String sessionRecordId;
  final String sourceBlockId;
  final BlockPerformanceSnapshot blockSnapshot;
  final TrainingBlockResultStatus status;
  final PerformanceResultType resultType;
  final int position;
  final PerformanceResultData? resultData;
  final String? athleteNote;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final List<TrainingExerciseResult> exerciseResults;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TrainingBlockResult.fromMap(
    Map<String, dynamic> map, {
    List<TrainingExerciseResult> exerciseResults = const [],
  }) {
    final snapshotJson = map['block_snapshot'];
    final resultJson = map['result_data'];
    return TrainingBlockResult(
      blockResultId: map['block_result_id']?.toString() ?? '',
      sessionRecordId: map['session_record_id']?.toString() ?? '',
      sourceBlockId: map['source_block_id']?.toString() ?? '',
      blockSnapshot: snapshotJson is Map
          ? BlockPerformanceSnapshot.fromJson(
              Map<String, dynamic>.from(snapshotJson),
            )
          : BlockPerformanceSnapshot(
              sourceBlockId: map['source_block_id']?.toString() ?? '',
              title: '',
              blockType: SessionBlockType.custom,
              content: '',
              workoutFormat: WorkoutFormat.none,
              position: map['position'] ?? 0,
            ),
      status: TrainingBlockResultStatusDb.fromDb(map['status']?.toString()),
      resultType: PerformanceResultTypeDb.fromDb(map['result_type']?.toString()),
      position: map['position'] ?? 0,
      resultData: resultJson is Map
          ? PerformanceResultData.fromJson(Map<String, dynamic>.from(resultJson))
          : null,
      athleteNote: _trim(map['athlete_note']),
      startedAt: _parseDateTime(map['started_at']),
      completedAt: _parseDateTime(map['completed_at']),
      durationSeconds: _nullableInt(map['duration_seconds']),
      exerciseResults: exerciseResults,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'block_result_id': blockResultId,
      'session_record_id': sessionRecordId,
      'source_block_id': sourceBlockId,
      'block_snapshot': blockSnapshot.toJson(),
      'status': status.dbValue,
      'result_type': resultType.dbValue,
      'position': position,
      if (resultData != null) 'result_data': resultData!.toJson(),
      if (athleteNote != null) 'athlete_note': athleteNote,
      if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
    };
  }
}

class TrainingSessionRecord {
  const TrainingSessionRecord({
    required this.recordId,
    required this.athleteId,
    required this.status,
    required this.sessionSnapshot,
    required this.startedAt,
    this.trainingSessionId,
    this.sourceProtocolId,
    this.programmeId,
    this.assignmentId,
    this.programmeSessionId,
    this.activeBlockId,
    this.completedAt,
    this.durationSeconds,
    this.overallRpe,
    this.athleteNote,
    this.blockResults = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String recordId;
  final String athleteId;
  final int? trainingSessionId;
  final String? sourceProtocolId;
  final String? programmeId;
  final String? assignmentId;
  final String? programmeSessionId;
  final TrainingSessionRecordStatus status;
  final SessionPerformanceSnapshot sessionSnapshot;
  final String? activeBlockId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final int? overallRpe;
  final String? athleteNote;
  final List<TrainingBlockResult> blockResults;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get completedBlockCount => blockResults
      .where((b) => b.status == TrainingBlockResultStatus.completed)
      .length;

  factory TrainingSessionRecord.fromMap(
    Map<String, dynamic> map, {
    List<TrainingBlockResult> blockResults = const [],
  }) {
    final snapshotJson = map['session_snapshot'];
    return TrainingSessionRecord(
      recordId: map['record_id']?.toString() ?? '',
      athleteId: map['athlete_id']?.toString() ?? '',
      trainingSessionId: _nullableInt(map['training_session_id']),
      sourceProtocolId: _trim(map['source_protocol_id']),
      programmeId: _trim(map['programme_id']),
      assignmentId: _trim(map['assignment_id']),
      programmeSessionId: _trim(map['programme_session_id']),
      status: TrainingSessionRecordStatusDb.fromDb(map['status']?.toString()),
      sessionSnapshot: snapshotJson is Map
          ? SessionPerformanceSnapshot.fromJson(
              Map<String, dynamic>.from(snapshotJson),
            )
          : SessionPerformanceSnapshot(
              sourceProtocolId: map['source_protocol_id']?.toString() ?? '',
              sessionTitle: '',
            ),
      activeBlockId: _trim(map['active_block_id']),
      startedAt: _parseDateTime(map['started_at']) ?? DateTime.now().toUtc(),
      completedAt: _parseDateTime(map['completed_at']),
      durationSeconds: _nullableInt(map['duration_seconds']),
      overallRpe: _nullableInt(map['overall_rpe']),
      athleteNote: _trim(map['athlete_note']),
      blockResults: blockResults,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'record_id': recordId,
      'athlete_id': athleteId,
      if (trainingSessionId != null) 'training_session_id': trainingSessionId,
      if (sourceProtocolId != null) 'source_protocol_id': sourceProtocolId,
      if (programmeId != null) 'programme_id': programmeId,
      if (assignmentId != null) 'assignment_id': assignmentId,
      if (programmeSessionId != null) 'programme_session_id': programmeSessionId,
      'status': status.dbValue,
      'session_snapshot': sessionSnapshot.toJson(),
      if (activeBlockId != null) 'active_block_id': activeBlockId,
      'started_at': startedAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (overallRpe != null) 'overall_rpe': overallRpe,
      if (athleteNote != null) 'athlete_note': athleteNote,
    };
  }
}

String? _trim(dynamic value) {
  final trimmed = value?.toString().trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
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

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
