import 'strength_set_performance.dart';

/// Repository row for exercise history queries.
///
/// Maps a completed set plus parent session metadata. Grouping belongs in
/// [ExerciseHistoryService], not the repository.
class ExerciseHistoryRawRow {
  const ExerciseHistoryRawRow({
    required this.performance,
    required this.trainingSessionId,
    required this.protocolId,
    this.sessionCompletedAt,
    this.endedEarly = false,
    this.completionReason,
  });

  final StrengthSetPerformance performance;
  final int trainingSessionId;
  final String protocolId;
  final DateTime? sessionCompletedAt;
  final bool endedEarly;
  final String? completionReason;

  factory ExerciseHistoryRawRow.fromMap(Map<String, dynamic> map) {
    final session = map['training_sessions'];
    final sessionMap =
        session is Map ? Map<String, dynamic>.from(session) : <String, dynamic>{};

    return ExerciseHistoryRawRow(
      performance: StrengthSetPerformance.fromMap(
        Map<String, dynamic>.from(map),
      ),
      trainingSessionId: map['training_session_id'] as int,
      protocolId: _trimStringRequired(sessionMap['protocol_id']),
      sessionCompletedAt: _parseDateTime(sessionMap['completed_at']),
      endedEarly: sessionMap['ended_early'] == true,
      completionReason: _trimString(sessionMap['completion_reason']),
    );
  }

  static String? _trimString(dynamic value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _trimStringRequired(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}

/// Lightweight session header used to apply [sessionLimit] before set fetch.
class ExerciseHistorySessionHeader {
  const ExerciseHistorySessionHeader({
    required this.trainingSessionId,
    required this.protocolId,
    this.sessionCompletedAt,
  });

  final int trainingSessionId;
  final String protocolId;
  final DateTime? sessionCompletedAt;
}
