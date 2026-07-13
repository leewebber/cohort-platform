import 'training_session_status.dart';

/// Historical execution record for a completed or in-progress athlete workout.
class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.athleteId,
    required this.protocolId,
    required this.status,
    this.programmeId,
    this.weekNumber,
    this.day,
    this.startedAt,
    this.completedAt,
    this.durationSeconds,
    this.sessionNote,
    this.endedEarly = false,
    this.completionReason,
    this.completedExerciseCount,
    this.totalExerciseCount,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String athleteId;
  final String protocolId;
  final TrainingSessionStatus status;
  final String? programmeId;
  final int? weekNumber;
  final String? day;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final String? sessionNote;
  final bool endedEarly;
  final String? completionReason;
  final int? completedExerciseCount;
  final int? totalExerciseCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TrainingSession.fromMap(Map<String, dynamic> map) {
    return TrainingSession(
      id: map['id'],
      athleteId: _trimStringRequired(map['athlete_id']),
      protocolId: _trimStringRequired(map['protocol_id']),
      status: TrainingSessionStatusDb.fromDb(map['status']?.toString()),
      programmeId: _trimString(map['programme_id']),
      weekNumber: _nullableInt(map['week_number']),
      day: _trimString(map['day']),
      startedAt: _parseDateTime(map['started_at']),
      completedAt: _parseDateTime(map['completed_at']),
      durationSeconds: _nullableInt(map['duration_seconds']),
      sessionNote: _trimString(map['session_note']),
      endedEarly: map['ended_early'] == true,
      completionReason: _trimString(map['completion_reason']),
      completedExerciseCount: _nullableInt(map['completed_exercise_count']),
      totalExerciseCount: _nullableInt(map['total_exercise_count']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'athlete_id': athleteId,
      'protocol_id': protocolId,
      'status': status.dbValue,
      if (programmeId != null) 'programme_id': programmeId,
      if (weekNumber != null) 'week_number': weekNumber,
      if (day != null) 'day': day,
      if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }

  static String? _trimString(dynamic value) {
    if (value == null) return null;

    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _trimStringRequired(dynamic value) {
    return value?.toString().trim() ?? '';
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
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }
}
