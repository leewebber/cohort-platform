import '../../../models/programme_phase_draft.dart';
import '../../../models/programme_week_draft.dart';

/// Nested template tree for programme authoring.
///
/// Reuses existing week/day/slot draft node models.
/// See `44_Programme_Builder.md`.
class ProgrammeTemplateDraft {
  const ProgrammeTemplateDraft({
    this.weeks = const [],
    this.phases = const [],
  });

  final List<ProgrammeWeekDraft> weeks;
  final List<ProgrammePhaseDraft> phases;

  /// All weeks from flat list and phases, sorted by week number.
  List<ProgrammeWeekDraft> get allWeeks {
    final combined = <ProgrammeWeekDraft>[
      ...weeks,
      for (final phase in phases) ...phase.weeks,
    ];
    combined.sort((left, right) => left.weekNumber.compareTo(right.weekNumber));
    return combined;
  }

  ProgrammeTemplateDraft copyWith({
    List<ProgrammeWeekDraft>? weeks,
    List<ProgrammePhaseDraft>? phases,
  }) {
    return ProgrammeTemplateDraft(
      weeks: weeks ?? this.weeks,
      phases: phases ?? this.phases,
    );
  }
}
