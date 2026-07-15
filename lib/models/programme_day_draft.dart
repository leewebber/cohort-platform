import 'programme_session_slot_draft.dart';
import 'programme_vocabulary.dart';

/// One day within a programme week.
///
/// May contain zero slots (rest), one slot, or multiple ordered slots.
/// See `07 Documentation/41_Programme_Engine.md`.
class ProgrammeDayDraft {
  const ProgrammeDayDraft({
    required this.localId,
    required this.dayKey,
    required this.dayOrder,
    this.title,
    this.dayType = ProgrammeDayType.training,
    this.intent,
    this.coachNote,
    this.athleteNote,
    this.slots = const [],
  });

  /// Client-stable identity for authoring.
  final String localId;

  /// Ordinal cursor key — `day_1`, `day_2`, … Weekday labels are derived at
  /// resolution time from assignment start date and timezone.
  final String dayKey;

  /// Display order within the week (1-based).
  final int dayOrder;

  final String? title;
  final ProgrammeDayType dayType;
  final ProgrammeIntent? intent;
  final String? coachNote;
  final String? athleteNote;
  final List<ProgrammeSessionSlotDraft> slots;

  bool get isRestDay => dayType == ProgrammeDayType.rest || slots.isEmpty;

  ProgrammeDayDraft copyWith({
    String? localId,
    String? dayKey,
    int? dayOrder,
    String? title,
    ProgrammeDayType? dayType,
    ProgrammeIntent? intent,
    String? coachNote,
    String? athleteNote,
    List<ProgrammeSessionSlotDraft>? slots,
    bool clearTitle = false,
    bool clearIntent = false,
    bool clearCoachNote = false,
    bool clearAthleteNote = false,
  }) {
    return ProgrammeDayDraft(
      localId: localId ?? this.localId,
      dayKey: dayKey ?? this.dayKey,
      dayOrder: dayOrder ?? this.dayOrder,
      title: clearTitle ? null : (title ?? this.title),
      dayType: dayType ?? this.dayType,
      intent: clearIntent ? null : (intent ?? this.intent),
      coachNote: clearCoachNote ? null : (coachNote ?? this.coachNote),
      athleteNote: clearAthleteNote ? null : (athleteNote ?? this.athleteNote),
      slots: slots ?? this.slots,
    );
  }
}
