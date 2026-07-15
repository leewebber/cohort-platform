import 'programme_day_draft.dart';
import 'programme_vocabulary.dart';

/// One numbered week within a programme phase or flat programme.
///
/// See `07 Documentation/41_Programme_Engine.md`.
class ProgrammeWeekDraft {
  const ProgrammeWeekDraft({
    required this.localId,
    required this.weekNumber,
    this.title,
    this.intent,
    this.coachNote,
    this.athleteNote,
    this.days = const [],
  });

  /// Client-stable identity for authoring.
  final String localId;

  /// Week index within the programme (1-based).
  final int weekNumber;

  final String? title;
  final ProgrammeIntent? intent;
  final String? coachNote;
  final String? athleteNote;
  final List<ProgrammeDayDraft> days;

  int get trainingDayCount =>
      days.where((day) => day.dayType != ProgrammeDayType.rest).length;

  ProgrammeWeekDraft copyWith({
    String? localId,
    int? weekNumber,
    String? title,
    ProgrammeIntent? intent,
    String? coachNote,
    String? athleteNote,
    List<ProgrammeDayDraft>? days,
    bool clearTitle = false,
    bool clearIntent = false,
    bool clearCoachNote = false,
    bool clearAthleteNote = false,
  }) {
    return ProgrammeWeekDraft(
      localId: localId ?? this.localId,
      weekNumber: weekNumber ?? this.weekNumber,
      title: clearTitle ? null : (title ?? this.title),
      intent: clearIntent ? null : (intent ?? this.intent),
      coachNote: clearCoachNote ? null : (coachNote ?? this.coachNote),
      athleteNote: clearAthleteNote ? null : (athleteNote ?? this.athleteNote),
      days: days ?? this.days,
    );
  }
}
