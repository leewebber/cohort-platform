import 'dart:convert';

enum ProgrammeAdaptationType {
  loadProgression,
  protocolSubstitution,
}

/// Audit record for a deterministic post-completion adaptation.
class ProgrammeAdaptationEvent {
  const ProgrammeAdaptationEvent({
    required this.id,
    required this.assignmentId,
    required this.athleteId,
    required this.triggerTrainingSessionId,
    required this.adaptationType,
    required this.explanation,
    required this.athleteSummary,
    required this.affectedSlotIds,
    required this.payload,
    this.triggerSlotId,
    this.createdAt,
  });

  final String id;
  final String assignmentId;
  final String athleteId;
  final int triggerTrainingSessionId;
  final ProgrammeAdaptationType adaptationType;
  final String explanation;
  final String athleteSummary;
  final List<String> affectedSlotIds;
  final Map<String, dynamic> payload;
  final String? triggerSlotId;
  final DateTime? createdAt;

  factory ProgrammeAdaptationEvent.fromMap(Map<String, dynamic> map) {
    return ProgrammeAdaptationEvent(
      id: map['id']?.toString() ?? '',
      assignmentId: map['assignment_id']?.toString() ?? '',
      athleteId: map['athlete_id']?.toString() ?? '',
      triggerTrainingSessionId: _int(map['trigger_training_session_id']),
      adaptationType: ProgrammeAdaptationTypeDb.fromDb(
        map['adaptation_type']?.toString(),
      ),
      explanation: map['explanation']?.toString() ?? '',
      athleteSummary: map['athlete_summary']?.toString() ?? '',
      affectedSlotIds: _stringList(map['affected_slot_ids']),
      payload: _payload(map['payload']),
      triggerSlotId: _trim(map['trigger_slot_id']),
      createdAt: _date(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'assignment_id': assignmentId,
      'athlete_id': athleteId,
      'trigger_training_session_id': triggerTrainingSessionId,
      'adaptation_type': adaptationType.dbValue,
      'explanation': explanation,
      'athlete_summary': athleteSummary,
      'affected_slot_ids': affectedSlotIds,
      'payload': payload,
      if (triggerSlotId != null) 'trigger_slot_id': triggerSlotId,
    };
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _trim(dynamic value) {
    final trimmed = value?.toString().trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((entry) => entry.toString()).toList();
    }
    return const [];
  }

  static Map<String, dynamic> _payload(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return const {};
  }
}

extension ProgrammeAdaptationTypeDb on ProgrammeAdaptationType {
  String get dbValue {
    return switch (this) {
      ProgrammeAdaptationType.loadProgression => 'load_progression',
      ProgrammeAdaptationType.protocolSubstitution => 'protocol_substitution',
    };
  }

  static ProgrammeAdaptationType fromDb(String? value) {
    return switch (value?.trim()) {
      'protocol_substitution' => ProgrammeAdaptationType.protocolSubstitution,
      _ => ProgrammeAdaptationType.loadProgression,
    };
  }
}
