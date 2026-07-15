import 'programme_vocabulary.dart';

/// One numbered week within a programme version snapshot.
///
/// See `42_Programme_Engine_Schema.md`.
class ProgrammeVersionWeek {
  const ProgrammeVersionWeek({
    required this.id,
    required this.versionId,
    required this.weekNumber,
    this.phaseId,
    this.title,
    this.intent,
    this.coachNote,
    this.athleteNote,
    this.createdAt,
  });

  final String id;
  final String versionId;
  final String? phaseId;
  final int weekNumber;
  final String? title;
  final ProgrammeIntent? intent;
  final String? coachNote;
  final String? athleteNote;
  final DateTime? createdAt;

  factory ProgrammeVersionWeek.fromMap(Map<String, dynamic> map) {
    return ProgrammeVersionWeek(
      id: _trimStringRequired(map['id']),
      versionId: _trimStringRequired(map['version_id']),
      phaseId: _trimString(map['phase_id']),
      weekNumber: map['week_number'] ?? 1,
      title: _trimString(map['title']),
      intent: ProgrammeIntentDb.fromDb(map['intent']?.toString()),
      coachNote: _trimString(map['coach_note']),
      athleteNote: _trimString(map['athlete_note']),
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'version_id': versionId,
      if (phaseId != null) 'phase_id': phaseId,
      'week_number': weekNumber,
      if (title != null) 'title': title,
      if (intent != null) 'intent': intent!.dbValue,
      if (coachNote != null) 'coach_note': coachNote,
      if (athleteNote != null) 'athlete_note': athleteNote,
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

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }
}
