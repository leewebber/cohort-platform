import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_version_day.dart';
import '../../../models/programme_version_session_slot.dart';
import '../../../models/programme_vocabulary.dart';
import '../errors/programme_schedule_exception.dart';
import '../models/programme_schedule_resolution.dart';
import '../models/programme_suggested_cursor.dart';
import '../models/programme_template.dart';
import 'programme_schedule_resolver.dart';

/// Pure read-only programme schedule resolver.
class ProgrammeScheduleResolverImpl implements ProgrammeScheduleResolver {
  const ProgrammeScheduleResolverImpl();

  static final _ordinalDayKeyPattern = RegExp(r'^day_[1-9][0-9]*$');

  @override
  ProgrammeSuggestedCursor resolveInitialCursor({
    required ProgrammeTemplateTree tree,
  }) {
    _validateTreeStructure(tree);

    final sortedWeeks = tree.weekNodes.toList()
      ..sort(
        (left, right) =>
            left.week.weekNumber.compareTo(right.week.weekNumber),
      );

    for (final weekNode in sortedWeeks) {
      final sortedDays = weekNode.sortedDays;
      if (sortedDays.isEmpty) continue;

      _validateWeekDays(weekNode);

      return _cursorForDayNode(
        weekNumber: weekNode.week.weekNumber,
        dayNode: sortedDays.first,
      );
    }

    throw ProgrammeScheduleException(
      ProgrammeScheduleErrorCode.emptyProgrammeStructure,
      'Programme template has no schedulable days',
    );
  }

  @override
  ProgrammeScheduleResolution resolve({
    required ProgrammeAssignment assignment,
    required ProgrammeTemplateTree tree,
    required List<ProgrammeSlotOutcome> outcomes,
  }) {
    _validateAssignmentCursor(assignment);
    _validateTreeStructure(tree);
    _validateOutcomesBelongToTree(tree: tree, outcomes: outcomes);

    final weekNode = tree.weekNodeForNumber(assignment.currentWeek);
    if (weekNode == null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.missingCurrentWeek,
        'Assignment cursor references missing week ${assignment.currentWeek}',
      );
    }

    _validateWeekDays(weekNode);

    final dayNode = _dayNodeForKey(weekNode, assignment.currentDayKey);
    if (dayNode == null) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.missingCurrentDay,
        'Assignment cursor references missing day ${assignment.currentDayKey}',
      );
    }

    final outcomeBySlotId = {
      for (final outcome in outcomes) outcome.sessionSlotId: outcome,
    };

    final day = dayNode.day;
    final sortedSlots = dayNode.sortedSlots;
    _validateSlotOrders(sortedSlots);

    if (day.isRestDay || sortedSlots.isEmpty) {
      return _restDayResolution(
        assignment: assignment,
        tree: tree,
        day: day,
        suggestedNextCursor: _nextCursorAfterDay(
          tree: tree,
          weekNumber: assignment.currentWeek,
          dayKey: day.dayKey,
        ),
      );
    }

    final requiredSlots =
        sortedSlots.where((slot) => slot.isRequiredForProgression).toList();
    final optionalUnresolved = sortedSlots
        .where((slot) => !slot.isRequiredForProgression)
        .where((slot) => _isUnresolved(outcomeBySlotId[slot.id]?.outcomeStatus))
        .toList();

    final inProgressSlot = _firstInProgressSlot(
      slots: sortedSlots,
      outcomeBySlotId: outcomeBySlotId,
    );
    if (inProgressSlot != null) {
      return _executableResolution(
        assignment: assignment,
        tree: tree,
        day: day,
        slot: inProgressSlot,
        outcome: outcomeBySlotId[inProgressSlot.id],
        optionalUnresolvedSlots: optionalUnresolved,
      );
    }

    final nextRequiredSlot = _firstUnresolvedRequiredSlot(
      requiredSlots: requiredSlots,
      outcomeBySlotId: outcomeBySlotId,
    );

    if (nextRequiredSlot != null) {
      return _executableResolution(
        assignment: assignment,
        tree: tree,
        day: day,
        slot: nextRequiredSlot,
        outcome: outcomeBySlotId[nextRequiredSlot.id],
        optionalUnresolvedSlots: optionalUnresolved,
      );
    }

    final suggestedNextCursor = _nextCursorAfterDay(
      tree: tree,
      weekNumber: assignment.currentWeek,
      dayKey: day.dayKey,
    );

    if (suggestedNextCursor == null) {
      return ProgrammeScheduleResolution(
        kind: ProgrammeScheduleResolutionKind.programmeComplete,
        assignment: assignment,
        tree: tree,
        weekNumber: assignment.currentWeek,
        dayKey: day.dayKey,
        day: day,
        optionalUnresolvedSlots: optionalUnresolved,
      );
    }

    return ProgrammeScheduleResolution(
      kind: ProgrammeScheduleResolutionKind.dayComplete,
      assignment: assignment,
      tree: tree,
      weekNumber: assignment.currentWeek,
      dayKey: day.dayKey,
      day: day,
      optionalUnresolvedSlots: optionalUnresolved,
      suggestedNextCursor: suggestedNextCursor,
    );
  }

  ProgrammeScheduleResolution _executableResolution({
    required ProgrammeAssignment assignment,
    required ProgrammeTemplateTree tree,
    required ProgrammeVersionDay day,
    required ProgrammeVersionSessionSlot slot,
    required ProgrammeSlotOutcome? outcome,
    required List<ProgrammeVersionSessionSlot> optionalUnresolvedSlots,
  }) {
    final outcomeStatus =
        outcome?.outcomeStatus ?? ProgrammeSlotOutcomeStatus.scheduled;

    return ProgrammeScheduleResolution(
      kind: ProgrammeScheduleResolutionKind.executableSlot,
      assignment: assignment,
      tree: tree,
      weekNumber: assignment.currentWeek,
      dayKey: day.dayKey,
      day: day,
      slot: slot,
      slotOutcome: outcome,
      outcomeStatus: outcomeStatus,
      plannedProtocolId: slot.protocolId,
      effectiveProtocolId: _effectiveProtocolId(slot: slot, outcome: outcome),
      isOptional: !slot.isRequiredForProgression,
      optionalUnresolvedSlots: optionalUnresolvedSlots,
    );
  }

  ProgrammeScheduleResolution _restDayResolution({
    required ProgrammeAssignment assignment,
    required ProgrammeTemplateTree tree,
    required ProgrammeVersionDay day,
    required ProgrammeSuggestedCursor? suggestedNextCursor,
  }) {
    if (suggestedNextCursor == null) {
      return ProgrammeScheduleResolution(
        kind: ProgrammeScheduleResolutionKind.programmeComplete,
        assignment: assignment,
        tree: tree,
        weekNumber: assignment.currentWeek,
        dayKey: day.dayKey,
        day: day,
      );
    }

    return ProgrammeScheduleResolution(
      kind: ProgrammeScheduleResolutionKind.restDay,
      assignment: assignment,
      tree: tree,
      weekNumber: assignment.currentWeek,
      dayKey: day.dayKey,
      day: day,
      suggestedNextCursor: suggestedNextCursor,
    );
  }

  ProgrammeVersionSessionSlot? _firstInProgressSlot({
    required List<ProgrammeVersionSessionSlot> slots,
    required Map<String, ProgrammeSlotOutcome> outcomeBySlotId,
  }) {
    for (final slot in slots) {
      if (outcomeBySlotId[slot.id]?.outcomeStatus ==
          ProgrammeSlotOutcomeStatus.inProgress) {
        return slot;
      }
    }

    return null;
  }

  ProgrammeVersionSessionSlot? _firstUnresolvedRequiredSlot({
    required List<ProgrammeVersionSessionSlot> requiredSlots,
    required Map<String, ProgrammeSlotOutcome> outcomeBySlotId,
  }) {
    for (final slot in requiredSlots) {
      if (_isUnresolved(outcomeBySlotId[slot.id]?.outcomeStatus)) {
        return slot;
      }
    }

    return null;
  }

  bool _isUnresolved(ProgrammeSlotOutcomeStatus? status) {
    if (status == null) return true;

    return switch (status) {
      ProgrammeSlotOutcomeStatus.scheduled => true,
      ProgrammeSlotOutcomeStatus.inProgress => true,
      ProgrammeSlotOutcomeStatus.rescheduled => true,
      ProgrammeSlotOutcomeStatus.completed => false,
      ProgrammeSlotOutcomeStatus.completedPartial => false,
      ProgrammeSlotOutcomeStatus.skipped => false,
      ProgrammeSlotOutcomeStatus.replaced => false,
    };
  }

  String _effectiveProtocolId({
    required ProgrammeVersionSessionSlot slot,
    required ProgrammeSlotOutcome? outcome,
  }) {
    if (outcome?.outcomeStatus == ProgrammeSlotOutcomeStatus.replaced) {
      final replacement = outcome?.replacementProtocolId?.trim();
      if (replacement != null && replacement.isNotEmpty) {
        return replacement;
      }
    }

    return slot.protocolId;
  }

  ProgrammeSuggestedCursor? _nextCursorAfterDay({
    required ProgrammeTemplateTree tree,
    required int weekNumber,
    required String dayKey,
  }) {
    final sortedWeeks = tree.weekNodes.toList()
      ..sort(
        (left, right) =>
            left.week.weekNumber.compareTo(right.week.weekNumber),
      );

    final weekIndex = sortedWeeks.indexWhere(
      (node) => node.week.weekNumber == weekNumber,
    );
    if (weekIndex == -1) return null;

    final currentWeekNode = sortedWeeks[weekIndex];
    final sortedDays = currentWeekNode.sortedDays;
    final dayIndex = sortedDays.indexWhere(
      (node) => node.day.dayKey == dayKey,
    );

    if (dayIndex != -1 && dayIndex < sortedDays.length - 1) {
      return _cursorForDayNode(
        weekNumber: currentWeekNode.week.weekNumber,
        dayNode: sortedDays[dayIndex + 1],
      );
    }

    for (var index = weekIndex + 1; index < sortedWeeks.length; index++) {
      final nextWeekDays = sortedWeeks[index].sortedDays;
      if (nextWeekDays.isEmpty) continue;

      return _cursorForDayNode(
        weekNumber: sortedWeeks[index].week.weekNumber,
        dayNode: nextWeekDays.first,
      );
    }

    return null;
  }

  ProgrammeSuggestedCursor _cursorForDayNode({
    required int weekNumber,
    required ProgrammeTemplateDayNode dayNode,
  }) {
    final day = dayNode.day;
    final sortedSlots = dayNode.sortedSlots;

    if (day.isRestDay || sortedSlots.isEmpty) {
      return ProgrammeSuggestedCursor(
        weekNumber: weekNumber,
        dayKey: day.dayKey,
        slotOrder: 1,
      );
    }

    final requiredSlots =
        sortedSlots.where((slot) => slot.isRequiredForProgression).toList();
    final targetSlot =
        requiredSlots.isNotEmpty ? requiredSlots.first : sortedSlots.first;

    return ProgrammeSuggestedCursor(
      weekNumber: weekNumber,
      dayKey: day.dayKey,
      slotOrder: targetSlot.sessionOrder,
    );
  }

  ProgrammeTemplateDayNode? _dayNodeForKey(
    ProgrammeTemplateWeekNode weekNode,
    String dayKey,
  ) {
    for (final dayNode in weekNode.days) {
      if (dayNode.day.dayKey == dayKey) return dayNode;
    }

    return null;
  }

  void _validateAssignmentCursor(ProgrammeAssignment assignment) {
    if (assignment.currentWeek <= 0) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.malformedAssignmentCursor,
        'Assignment week must be positive',
      );
    }

    if (assignment.currentSessionOrder <= 0) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.malformedAssignmentCursor,
        'Assignment slot order must be positive',
      );
    }

    if (!_ordinalDayKeyPattern.hasMatch(assignment.currentDayKey)) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.malformedAssignmentCursor,
        'Assignment day key must be ordinal day_N',
        details: assignment.currentDayKey,
      );
    }
  }

  void _validateTreeStructure(ProgrammeTemplateTree tree) {
    if (tree.weekNodes.isEmpty) {
      throw ProgrammeScheduleException(
        ProgrammeScheduleErrorCode.emptyProgrammeStructure,
        'Programme template has no weeks',
      );
    }

    final slotIds = <String>{};
    for (final weekNode in tree.weekNodes) {
      for (final dayNode in weekNode.days) {
        for (final slot in dayNode.slots) {
          if (!slotIds.add(slot.id)) {
            throw ProgrammeScheduleException(
              ProgrammeScheduleErrorCode.slotOutsideVersionTree,
              'Duplicate slot id ${slot.id} in programme template',
            );
          }
        }
      }
    }
  }

  void _validateWeekDays(ProgrammeTemplateWeekNode weekNode) {
    final seenDayKeys = <String>{};
    final seenDayOrders = <int>{};

    for (final dayNode in weekNode.sortedDays) {
      if (!seenDayKeys.add(dayNode.day.dayKey)) {
        throw ProgrammeScheduleException(
          ProgrammeScheduleErrorCode.duplicateDayKey,
          'Duplicate day key ${dayNode.day.dayKey} in week ${weekNode.week.weekNumber}',
        );
      }

      if (!seenDayOrders.add(dayNode.day.dayOrder)) {
        throw ProgrammeScheduleException(
          ProgrammeScheduleErrorCode.duplicateDayKey,
          'Duplicate day order ${dayNode.day.dayOrder} in week ${weekNode.week.weekNumber}',
        );
      }
    }
  }

  void _validateSlotOrders(List<ProgrammeVersionSessionSlot> slots) {
    final seenOrders = <int>{};

    for (final slot in slots) {
      if (!seenOrders.add(slot.sessionOrder)) {
        throw ProgrammeScheduleException(
          ProgrammeScheduleErrorCode.duplicateSlotOrder,
          'Duplicate slot order ${slot.sessionOrder} on day ${slot.dayId}',
        );
      }
    }
  }

  void _validateOutcomesBelongToTree({
    required ProgrammeTemplateTree tree,
    required List<ProgrammeSlotOutcome> outcomes,
  }) {
    final slotIds = <String>{};
    for (final weekNode in tree.weekNodes) {
      for (final dayNode in weekNode.days) {
        for (final slot in dayNode.slots) {
          slotIds.add(slot.id);
        }
      }
    }

    for (final outcome in outcomes) {
      if (!slotIds.contains(outcome.sessionSlotId)) {
        throw ProgrammeScheduleException(
          ProgrammeScheduleErrorCode.slotOutcomeOutsideVersionTree,
          'Outcome references slot outside loaded version tree',
          details: outcome.sessionSlotId,
        );
      }
    }
  }
}
