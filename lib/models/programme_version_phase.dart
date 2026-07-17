import 'programme_vocabulary.dart';
import '../core/utils/database_uuid.dart';

/// Optional macro block within a programme version.
///
/// V1 default: zero phases (flat weeks on version).
/// See `42_Programme_Engine_Schema.md`.
class ProgrammeVersionPhase {
  const ProgrammeVersionPhase({
    required this.id,
    required this.versionId,
    required this.phaseOrder,
    required this.title,
    this.intent,
    this.coachNote,
    this.createdAt,
  });

  final String id;
  final String versionId;
  final int phaseOrder;
  final String title;
  final ProgrammeIntent? intent;
  final String? coachNote;
  final DateTime? createdAt;

  factory ProgrammeVersionPhase.fromMap(Map<String, dynamic> map) {
    return ProgrammeVersionPhase(
      id: _trimStringRequired(map['id']),
      versionId: _trimStringRequired(map['version_id']),
      phaseOrder: map['phase_order'] ?? 1,
      title: _trimStringRequired(map['title']),
      intent: ProgrammeIntentDb.fromDb(map['intent']?.toString()),
      coachNote: _trimString(map['coach_note']),
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return DatabaseUuid.includeUuidIdIfValid({
      'version_id': versionId,
      'phase_order': phaseOrder,
      'title': title,
      if (intent != null) 'intent': intent!.dbValue,
      if (coachNote != null) 'coach_note': coachNote,
    }, id);
  }

  static String? _trimString(dynamic value) {
    if (value == null) return null;

    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _trimStringRequired(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }
}
