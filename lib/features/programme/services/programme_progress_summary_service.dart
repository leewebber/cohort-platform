import '../../../models/programme_slot_outcome.dart';
import '../models/programme_progress_summary.dart';
import '../models/programme_template.dart';

/// Computes simple programme progress labels from template + slot outcomes.
class ProgrammeProgressSummaryService {
  const ProgrammeProgressSummaryService();

  ProgrammeProgressSummary? summarize({
    required ProgrammeTemplateTree tree,
    required List<ProgrammeSlotOutcome> outcomes,
    required int currentWeek,
  }) {
    final totalWeeks = _totalWeeks(tree);
    if (totalWeeks <= 0) return null;

    final requiredSlotIds = _requiredSlotIds(tree);
    if (requiredSlotIds.isEmpty) return null;

    final completedSessions = _countCompletedSessions(
      requiredSlotIds: requiredSlotIds,
      outcomes: outcomes,
    );

    return ProgrammeProgressSummary(
      currentWeek: currentWeek.clamp(1, totalWeeks),
      totalWeeks: totalWeeks,
      completedSessions: completedSessions,
      totalSessions: requiredSlotIds.length,
    );
  }

  int _totalWeeks(ProgrammeTemplateTree tree) {
    if (tree.weekNodes.isEmpty) return 0;

    return tree.weekNodes
        .map((node) => node.week.weekNumber)
        .reduce((left, right) => left > right ? left : right);
  }

  Set<String> _requiredSlotIds(ProgrammeTemplateTree tree) {
    final slotIds = <String>{};

    for (final weekNode in tree.weekNodes) {
      for (final dayNode in weekNode.sortedDays) {
        if (dayNode.day.isRestDay) continue;

        for (final slot in dayNode.sortedSlots) {
          if (slot.isRequiredForProgression) {
            slotIds.add(slot.id);
          }
        }
      }
    }

    return slotIds;
  }

  int _countCompletedSessions({
    required Set<String> requiredSlotIds,
    required List<ProgrammeSlotOutcome> outcomes,
  }) {
    final terminalSlotIds = <String>{};

    for (final outcome in outcomes) {
      if (!requiredSlotIds.contains(outcome.sessionSlotId)) continue;
      if (!outcome.isTerminal) continue;
      terminalSlotIds.add(outcome.sessionSlotId);
    }

    return terminalSlotIds.length;
  }
}
