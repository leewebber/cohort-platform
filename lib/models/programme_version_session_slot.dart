import 'programme_vocabulary.dart';
import '../core/utils/database_uuid.dart';

/// A schedulable session slot within a programme version day.
///
/// References a protocol for execution; does not embed protocol steps.
/// See `42_Programme_Engine_Schema.md`.
class ProgrammeVersionSessionSlot {
  const ProgrammeVersionSessionSlot({
    required this.id,
    required this.dayId,
    required this.sessionOrder,
    required this.protocolId,
    this.displayTitle,
    this.timeOfDay = ProgrammeSessionTimeOfDay.any,
    this.isOptional = false,
    this.completionExpectation =
        ProgrammeSessionCompletionExpectation.required,
    this.coachNote,
    this.athleteNote,
    this.createdAt,
  });

  final String id;
  final String dayId;
  final int sessionOrder;
  final String protocolId;
  final String? displayTitle;
  final ProgrammeSessionTimeOfDay timeOfDay;
  final bool isOptional;
  final ProgrammeSessionCompletionExpectation completionExpectation;
  final String? coachNote;
  final String? athleteNote;
  final DateTime? createdAt;

  bool get isRequiredForProgression {
    if (isOptional) return false;

    return completionExpectation != ProgrammeSessionCompletionExpectation.optional;
  }

  factory ProgrammeVersionSessionSlot.fromMap(Map<String, dynamic> map) {
    return ProgrammeVersionSessionSlot(
      id: _trimStringRequired(map['id']),
      dayId: _trimStringRequired(map['day_id']),
      sessionOrder: map['session_order'] ?? 1,
      protocolId: _trimStringRequired(map['protocol_id']),
      displayTitle: _trimString(map['display_title']),
      timeOfDay:
          ProgrammeSessionTimeOfDayDb.fromDb(map['time_of_day']?.toString()),
      isOptional: map['is_optional'] == true,
      completionExpectation: ProgrammeSessionCompletionExpectationDb.fromDb(
        map['completion_expectation']?.toString(),
      ),
      coachNote: _trimString(map['coach_note']),
      athleteNote: _trimString(map['athlete_note']),
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return DatabaseUuid.includeUuidIdIfValid({
      'day_id': dayId,
      'session_order': sessionOrder,
      'protocol_id': protocolId,
      if (displayTitle != null) 'display_title': displayTitle,
      'time_of_day': timeOfDay.dbValue,
      'is_optional': isOptional,
      'completion_expectation': completionExpectation.dbValue,
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
