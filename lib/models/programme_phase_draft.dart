import 'programme_vocabulary.dart';
import 'programme_week_draft.dart';

/// Optional macro block grouping consecutive weeks.
///
/// Programmes may omit phases and use a flat week list.
/// See `07 Documentation/41_Programme_Engine.md`.
class ProgrammePhaseDraft {
  const ProgrammePhaseDraft({
    required this.localId,
    required this.phaseOrder,
    required this.title,
    this.intent,
    this.description,
    this.coachNote,
    this.weeks = const [],
  });

  /// Client-stable identity for authoring.
  final String localId;

  /// Order within the programme (1-based).
  final int phaseOrder;

  final String title;
  final ProgrammeIntent? intent;
  final String? description;
  final String? coachNote;
  final List<ProgrammeWeekDraft> weeks;

  ProgrammePhaseDraft copyWith({
    String? localId,
    int? phaseOrder,
    String? title,
    ProgrammeIntent? intent,
    String? description,
    String? coachNote,
    List<ProgrammeWeekDraft>? weeks,
    bool clearIntent = false,
    bool clearDescription = false,
    bool clearCoachNote = false,
  }) {
    return ProgrammePhaseDraft(
      localId: localId ?? this.localId,
      phaseOrder: phaseOrder ?? this.phaseOrder,
      title: title ?? this.title,
      intent: clearIntent ? null : (intent ?? this.intent),
      description: clearDescription ? null : (description ?? this.description),
      coachNote: clearCoachNote ? null : (coachNote ?? this.coachNote),
      weeks: weeks ?? this.weeks,
    );
  }
}
