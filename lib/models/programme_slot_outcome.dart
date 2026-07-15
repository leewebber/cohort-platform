import 'programme_vocabulary.dart';

/// Per-assignment resolution of a programme session slot.
///
/// Separate from `training_sessions.status`.
/// See `42_Programme_Engine_Schema.md` §5.
class ProgrammeSlotOutcome {
  const ProgrammeSlotOutcome({
    required this.id,
    required this.assignmentId,
    required this.sessionSlotId,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
    required this.outcomeStatus,
    this.trainingSessionId,
    this.replacementProtocolId,
    this.resolutionNote,
    this.resolvedAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String assignmentId;
  final String sessionSlotId;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
  final ProgrammeSlotOutcomeStatus outcomeStatus;
  final int? trainingSessionId;
  final String? replacementProtocolId;
  final String? resolutionNote;
  final DateTime? resolvedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isTerminal => outcomeStatus.isTerminal;

  factory ProgrammeSlotOutcome.fromMap(Map<String, dynamic> map) {
    return ProgrammeSlotOutcome(
      id: _trimStringRequired(map['id']),
      assignmentId: _trimStringRequired(map['assignment_id']),
      sessionSlotId: _trimStringRequired(map['session_slot_id']),
      weekNumber: map['week_number'] ?? 1,
      dayKey: _trimStringRequired(map['day_key']),
      sessionOrder: map['session_order'] ?? 1,
      outcomeStatus: ProgrammeSlotOutcomeStatusDb.fromDb(
        map['outcome_status']?.toString(),
      ),
      trainingSessionId: _nullableInt(map['training_session_id']),
      replacementProtocolId: _trimString(
        map['replacement_protocol_id'] ?? map['resolved_protocol_id'],
      ),
      resolutionNote: _trimString(
        map['resolution_note'] ?? map['coach_note'] ?? map['athlete_note'],
      ),
      resolvedAt: _parseDateTime(map['resolved_at']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'assignment_id': assignmentId,
      'session_slot_id': sessionSlotId,
      'week_number': weekNumber,
      'day_key': dayKey,
      'session_order': sessionOrder,
      'outcome_status': outcomeStatus.dbValue,
      if (trainingSessionId != null) 'training_session_id': trainingSessionId,
      if (replacementProtocolId != null)
        'replacement_protocol_id': replacementProtocolId,
      if (resolutionNote != null) 'resolution_note': resolutionNote,
      if (resolvedAt != null) 'resolved_at': resolvedAt!.toIso8601String(),
    };
  }

  ProgrammeSlotOutcome copyWith({
    String? id,
    String? assignmentId,
    String? sessionSlotId,
    int? weekNumber,
    String? dayKey,
    int? sessionOrder,
    ProgrammeSlotOutcomeStatus? outcomeStatus,
    int? trainingSessionId,
    String? replacementProtocolId,
    String? resolutionNote,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearTrainingSessionId = false,
    bool clearReplacementProtocolId = false,
    bool clearResolutionNote = false,
    bool clearResolvedAt = false,
  }) {
    return ProgrammeSlotOutcome(
      id: id ?? this.id,
      assignmentId: assignmentId ?? this.assignmentId,
      sessionSlotId: sessionSlotId ?? this.sessionSlotId,
      weekNumber: weekNumber ?? this.weekNumber,
      dayKey: dayKey ?? this.dayKey,
      sessionOrder: sessionOrder ?? this.sessionOrder,
      outcomeStatus: outcomeStatus ?? this.outcomeStatus,
      trainingSessionId: clearTrainingSessionId
          ? null
          : (trainingSessionId ?? this.trainingSessionId),
      replacementProtocolId: clearReplacementProtocolId
          ? null
          : (replacementProtocolId ?? this.replacementProtocolId),
      resolutionNote:
          clearResolutionNote ? null : (resolutionNote ?? this.resolutionNote),
      resolvedAt: clearResolvedAt ? null : (resolvedAt ?? this.resolvedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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
    if (value == null) return null;
    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }
}
