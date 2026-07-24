import 'package:founder_importer/models/programme_vocabulary.dart';

/// A schedulable session within a programme day.
///
/// References a protocol for execution; does not embed protocol steps.
/// See `07 Documentation/41_Programme_Engine.md`.
class ProgrammeSessionSlotDraft {
  const ProgrammeSessionSlotDraft({
    required this.localId,
    required this.sessionOrder,
    required this.protocolId,
    this.displayTitle,
    this.timeOfDay = ProgrammeSessionTimeOfDay.any,
    this.isOptional = false,
    this.completionExpectation =
        ProgrammeSessionCompletionExpectation.required,
    this.coachNote,
    this.athleteNote,
  });

  /// Client-stable identity for authoring and future resume.
  final String localId;

  /// Order within the day (1-based).
  final int sessionOrder;

  /// Reference to `performance_protocols.protocol_id`.
  final String protocolId;

  /// Optional override for Today's Session display.
  final String? displayTitle;

  final ProgrammeSessionTimeOfDay timeOfDay;
  final bool isOptional;
  final ProgrammeSessionCompletionExpectation completionExpectation;
  final String? coachNote;
  final String? athleteNote;

  ProgrammeSessionSlotDraft copyWith({
    String? localId,
    int? sessionOrder,
    String? protocolId,
    String? displayTitle,
    ProgrammeSessionTimeOfDay? timeOfDay,
    bool? isOptional,
    ProgrammeSessionCompletionExpectation? completionExpectation,
    String? coachNote,
    String? athleteNote,
    bool clearDisplayTitle = false,
    bool clearCoachNote = false,
    bool clearAthleteNote = false,
  }) {
    return ProgrammeSessionSlotDraft(
      localId: localId ?? this.localId,
      sessionOrder: sessionOrder ?? this.sessionOrder,
      protocolId: protocolId ?? this.protocolId,
      displayTitle:
          clearDisplayTitle ? null : (displayTitle ?? this.displayTitle),
      timeOfDay: timeOfDay ?? this.timeOfDay,
      isOptional: isOptional ?? this.isOptional,
      completionExpectation:
          completionExpectation ?? this.completionExpectation,
      coachNote: clearCoachNote ? null : (coachNote ?? this.coachNote),
      athleteNote: clearAthleteNote ? null : (athleteNote ?? this.athleteNote),
    );
  }
}
