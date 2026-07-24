import 'package:founder_importer/models/programme_vocabulary.dart';
import 'package:founder_importer/core/utils/database_uuid.dart';

/// One day within a programme version week.
///
/// Canonical cursor keys are ordinal: `day_1`, `day_2`, …
/// See `42_Programme_Engine_Schema.md`.
class ProgrammeVersionDay {
  const ProgrammeVersionDay({
    required this.id,
    required this.weekId,
    required this.dayKey,
    required this.dayOrder,
    this.title,
    this.dayType = ProgrammeDayType.training,
    this.intent,
    this.coachNote,
    this.athleteNote,
    this.createdAt,
  });

  final String id;
  final String weekId;

  /// Ordinal cursor key — e.g. `day_1`, `day_2`.
  final String dayKey;

  final int dayOrder;
  final String? title;
  final ProgrammeDayType dayType;
  final ProgrammeIntent? intent;
  final String? coachNote;
  final String? athleteNote;
  final DateTime? createdAt;

  bool get isRestDay => dayType == ProgrammeDayType.rest;

  factory ProgrammeVersionDay.fromMap(Map<String, dynamic> map) {
    return ProgrammeVersionDay(
      id: _trimStringRequired(map['id']),
      weekId: _trimStringRequired(map['week_id']),
      dayKey: _trimStringRequired(map['day_key']),
      dayOrder: map['day_order'] ?? 1,
      title: _trimString(map['title']),
      dayType: ProgrammeDayTypeDb.fromDb(map['day_type']?.toString()),
      intent: ProgrammeIntentDb.fromDb(map['intent']?.toString()),
      coachNote: _trimString(map['coach_note']),
      athleteNote: _trimString(map['athlete_note']),
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return DatabaseUuid.includeUuidIdIfValid({
      'week_id': weekId,
      'day_key': dayKey,
      'day_order': dayOrder,
      if (title != null) 'title': title,
      'day_type': dayType.dbValue,
      if (intent != null) 'intent': intent!.dbValue,
      if (coachNote != null) 'coach_note': coachNote,
      if (athleteNote != null) 'athlete_note': athleteNote,
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
