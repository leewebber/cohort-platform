import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../programme/models/programme_template.dart';
import '../../programme/models/resolved_today_session.dart';

class _OrderedSlot {
  const _OrderedSlot({
    required this.slotId,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
  });

  final String slotId;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
}

/// Deterministic compliance labels from schedule cursor and slot outcomes.
class CoachComplianceSummaryService {
  const CoachComplianceSummaryService();

  CoachComplianceResult summarize({
    required ProgrammeTemplateTree tree,
    required List<ProgrammeSlotOutcome> outcomes,
    required ProgrammeAssignment assignment,
    required ResolvedTodaySession resolution,
    DateTime? referenceTime,
  }) {
    final now = (referenceTime ?? DateTime.now()).toUtc();
    final orderedSlots = _orderedRequiredSlots(tree);
    final cursorIndex = _cursorIndex(
      orderedSlots: orderedSlots,
      assignment: assignment,
    );

    var sessionsBehind = 0;
    for (var index = 0; index < cursorIndex; index++) {
      if (!_hasTerminalOutcome(outcomes, orderedSlots[index].slotId)) {
        sessionsBehind++;
      }
    }

    final completedToday = _completedToday(
      outcomes: outcomes,
      resolution: resolution,
      reference: now,
    );

    return CoachComplianceResult(
      sessionsBehind: sessionsBehind,
      completedToday: completedToday,
      label: _complianceLabel(
        sessionsBehind: sessionsBehind,
        completedToday: completedToday,
      ),
      needsAttention: sessionsBehind > 0 ||
          resolution.kind == ResolvedTodaySessionKind.noActiveProgramme ||
          resolution.kind == ResolvedTodaySessionKind.paused,
    );
  }

  String _complianceLabel({
    required int sessionsBehind,
    required bool completedToday,
  }) {
    if (completedToday) return 'Completed Today';
    if (sessionsBehind <= 0) return 'On Track';
    if (sessionsBehind == 1) return '1 Session Behind';
    return '$sessionsBehind Sessions Behind';
  }

  bool _completedToday({
    required List<ProgrammeSlotOutcome> outcomes,
    required ResolvedTodaySession resolution,
    required DateTime reference,
  }) {
    if (resolution.kind == ResolvedTodaySessionKind.dayComplete ||
        resolution.kind == ResolvedTodaySessionKind.programmeComplete) {
      return true;
    }

    for (final outcome in outcomes) {
      if (!outcome.isTerminal) continue;
      final resolvedAt = outcome.resolvedAt;
      if (resolvedAt == null) continue;
      if (_isSameDay(resolvedAt.toUtc(), reference)) return true;
    }

    return false;
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  List<_OrderedSlot> _orderedRequiredSlots(ProgrammeTemplateTree tree) {
    final slots = <_OrderedSlot>[];

    final sortedWeeks = List.of(tree.weekNodes)
      ..sort((left, right) =>
          left.week.weekNumber.compareTo(right.week.weekNumber));

    for (final weekNode in sortedWeeks) {
      for (final dayNode in weekNode.sortedDays) {
        if (dayNode.day.isRestDay) continue;
        for (final slot in dayNode.sortedSlots) {
          if (!slot.isRequiredForProgression) continue;
          slots.add(
            _OrderedSlot(
              slotId: slot.id,
              weekNumber: weekNode.week.weekNumber,
              dayKey: dayNode.day.dayKey,
              sessionOrder: slot.sessionOrder,
            ),
          );
        }
      }
    }

    return slots;
  }

  int _cursorIndex({
    required List<_OrderedSlot> orderedSlots,
    required ProgrammeAssignment assignment,
  }) {
    for (var index = 0; index < orderedSlots.length; index++) {
      final slot = orderedSlots[index];
      if (slot.weekNumber == assignment.currentWeek &&
          slot.dayKey == assignment.currentDayKey &&
          slot.sessionOrder == assignment.currentSessionOrder) {
        return index;
      }
    }

    return orderedSlots.length;
  }

  bool _hasTerminalOutcome(List<ProgrammeSlotOutcome> outcomes, String slotId) {
    for (final outcome in outcomes) {
      if (outcome.sessionSlotId == slotId && outcome.isTerminal) {
        return true;
      }
    }
    return false;
  }
}

class CoachComplianceResult {
  const CoachComplianceResult({
    required this.sessionsBehind,
    required this.completedToday,
    required this.label,
    required this.needsAttention,
  });

  final int sessionsBehind;
  final bool completedToday;
  final String label;
  final bool needsAttention;
}
