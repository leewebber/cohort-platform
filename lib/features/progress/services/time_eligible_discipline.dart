import '../../../models/programme_vocabulary.dart';
import '../../programme/models/fixed_programme_occurrence_projection.dart';
import '../models/progress_summary.dart';

/// Training Discipline from Calendar occurrences due so far.
///
/// Formula: completed eligible sessions ÷ all eligible sessions due so far.
/// Future required sessions never enter the denominator.
///
/// Partial-completion rule (v1, binary): `completed_partial` / occurrence
/// `COMPLETED` counts as numerator +1. Calendar SQL maps both `completed` and
/// `completed_partial` onto occurrence state `COMPLETED`. Slot outcome
/// `completedPartial` is terminal and does not block day advancement — the
/// same lifecycle as a valid completed session. No fractional 0.5 score.
abstract final class TimeEligibleDiscipline {
  static TimeEligibleDisciplineScore score({
    required List<FixedProgrammeOccurrenceProjection> occurrences,
    required String athleteLocalToday,
    String? programmeStartDate,
    Map<String, ProgrammeSlotOutcomeStatus> slotOutcomes = const {},
    Set<String> cancelledOccurrenceIds = const {},
  }) {
    if (programmeStartDate != null &&
        programmeStartDate.compareTo(athleteLocalToday) > 0) {
      return TimeEligibleDisciplineScore.noneDue(
        availability: DisciplineAvailability.preStart,
        asOfDate: athleteLocalToday,
        totalRequired: _requiredCount(
          occurrences,
          cancelledOccurrenceIds: cancelledOccurrenceIds,
          slotOutcomes: slotOutcomes,
        ),
      );
    }

    final seen = <String>{};
    var completedEligible = 0;
    var eligibleDue = 0;
    var futureExcluded = 0;
    var incompleteCount = 0;
    var skippedCount = 0;
    var partialCompletedCount = 0;
    var totalRequired = 0;

    for (final occurrence in occurrences) {
      if (!seen.add(occurrence.occurrenceId)) continue;
      if (!_isRequiredSession(occurrence)) continue;
      if (cancelledOccurrenceIds.contains(occurrence.occurrenceId)) continue;
      final overlay = _overlayFor(occurrence, slotOutcomes);
      if (overlay == ProgrammeSlotOutcomeStatus.replaced) continue;

      totalRequired++;
      final scheduled = occurrence.scheduledDate;
      final contribution = _contribution(
        occurrence: occurrence,
        overlay: overlay,
      );
      final today = scheduled == athleteLocalToday;
      final future = scheduled.compareTo(athleteLocalToday) > 0;
      final terminal =
          contribution == _DisciplineContribution.completed ||
          contribution == _DisciplineContribution.partialCompleted ||
          contribution == _DisciplineContribution.skipped;
      if (future && !terminal) {
        futureExcluded++;
        continue;
      }
      if (today && contribution == _DisciplineContribution.pending) {
        continue;
      }

      eligibleDue++;
      switch (contribution) {
        case _DisciplineContribution.completed:
          completedEligible++;
        case _DisciplineContribution.partialCompleted:
          completedEligible++;
          partialCompletedCount++;
        case _DisciplineContribution.skipped:
          skippedCount++;
        case _DisciplineContribution.incomplete:
        case _DisciplineContribution.pending:
          incompleteCount++;
      }
    }

    if (eligibleDue == 0) {
      return TimeEligibleDisciplineScore.noneDue(
        availability: DisciplineAvailability.noneDue,
        asOfDate: athleteLocalToday,
        totalRequired: totalRequired,
        futureExcluded: futureExcluded,
      );
    }

    final percentage = ((completedEligible / eligibleDue) * 100).round().clamp(
      0,
      100,
    );
    return TimeEligibleDisciplineScore(
      availability: DisciplineAvailability.scored,
      completedEligible: completedEligible,
      eligibleDue: eligibleDue,
      percentage: percentage,
      futureExcluded: futureExcluded,
      incompleteCount: incompleteCount,
      skippedCount: skippedCount,
      partialCompletedCount: partialCompletedCount,
      totalRequired: totalRequired,
      asOfDate: athleteLocalToday,
    );
  }

  static int _requiredCount(
    List<FixedProgrammeOccurrenceProjection> occurrences, {
    required Set<String> cancelledOccurrenceIds,
    required Map<String, ProgrammeSlotOutcomeStatus> slotOutcomes,
  }) {
    final seen = <String>{};
    var count = 0;
    for (final occurrence in occurrences) {
      if (!seen.add(occurrence.occurrenceId)) continue;
      if (!_isRequiredSession(occurrence)) continue;
      if (cancelledOccurrenceIds.contains(occurrence.occurrenceId)) continue;
      if (_overlayFor(occurrence, slotOutcomes) ==
          ProgrammeSlotOutcomeStatus.replaced) {
        continue;
      }
      count++;
    }
    return count;
  }

  static bool _isRequiredSession(
    FixedProgrammeOccurrenceProjection occurrence,
  ) {
    return occurrence.state != FixedProgrammeOccurrenceState.rest;
  }

  static ProgrammeSlotOutcomeStatus? _overlayFor(
    FixedProgrammeOccurrenceProjection occurrence,
    Map<String, ProgrammeSlotOutcomeStatus> slotOutcomes,
  ) {
    return slotOutcomes['${occurrence.sessionSlotId}|${occurrence.weekNumber}|'
            '${occurrence.dayKey}|${occurrence.sessionOrder}'] ??
        slotOutcomes[occurrence.sessionSlotId];
  }

  static _DisciplineContribution _contribution({
    required FixedProgrammeOccurrenceProjection occurrence,
    required ProgrammeSlotOutcomeStatus? overlay,
  }) {
    if (overlay == ProgrammeSlotOutcomeStatus.completedPartial) {
      return _DisciplineContribution.partialCompleted;
    }
    if (overlay == ProgrammeSlotOutcomeStatus.completed ||
        occurrence.state == FixedProgrammeOccurrenceState.completed) {
      return _DisciplineContribution.completed;
    }
    if (overlay == ProgrammeSlotOutcomeStatus.skipped ||
        occurrence.state == FixedProgrammeOccurrenceState.skipped) {
      return _DisciplineContribution.skipped;
    }
    if (overlay == ProgrammeSlotOutcomeStatus.inProgress ||
        occurrence.state == FixedProgrammeOccurrenceState.inProgress ||
        occurrence.state == FixedProgrammeOccurrenceState.today ||
        occurrence.state == FixedProgrammeOccurrenceState.planned) {
      return _DisciplineContribution.pending;
    }
    return _DisciplineContribution.incomplete;
  }
}

enum _DisciplineContribution {
  completed,
  partialCompleted,
  skipped,
  incomplete,
  pending,
}

class TimeEligibleDisciplineScore {
  const TimeEligibleDisciplineScore({
    required this.availability,
    required this.completedEligible,
    required this.eligibleDue,
    required this.percentage,
    required this.futureExcluded,
    required this.incompleteCount,
    required this.skippedCount,
    required this.partialCompletedCount,
    required this.totalRequired,
    required this.asOfDate,
  });

  factory TimeEligibleDisciplineScore.noneDue({
    required DisciplineAvailability availability,
    required String asOfDate,
    int totalRequired = 0,
    int futureExcluded = 0,
  }) {
    return TimeEligibleDisciplineScore(
      availability: availability,
      completedEligible: 0,
      eligibleDue: 0,
      percentage: 0,
      futureExcluded: futureExcluded,
      incompleteCount: 0,
      skippedCount: 0,
      partialCompletedCount: 0,
      totalRequired: totalRequired,
      asOfDate: asOfDate,
    );
  }

  final DisciplineAvailability availability;
  final int completedEligible;
  final int eligibleDue;
  final int percentage;
  final int futureExcluded;
  final int incompleteCount;
  final int skippedCount;
  final int partialCompletedCount;
  final int totalRequired;
  final String asOfDate;

  bool get hasScore => availability == DisciplineAvailability.scored;

  ProgressCompliance toCompliance({
    String? timezone,
    int currentStreak = 0,
    int longestStreak = 0,
  }) {
    return ProgressCompliance(
      completed: completedEligible,
      planned: eligibleDue,
      percentage: percentage,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      availability: availability,
      asOfDate: asOfDate,
      timezone: timezone,
      futureExcluded: futureExcluded,
      incompleteCount: incompleteCount,
      skippedCount: skippedCount,
      partialCompletedCount: partialCompletedCount,
      totalRequired: totalRequired,
    );
  }
}
