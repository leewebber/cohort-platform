import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_vocabulary.dart';
import '../../programme_comparison/models/programme_version_comparison_models.dart';
import '../models/programme_migration_plan_models.dart';

/// Pure read-only migration planning rules (M10.3).
class ProgrammeMigrationPlannerEngine {
  const ProgrammeMigrationPlannerEngine._();

  static AssignmentProgressSnapshot buildProgressSnapshot({
    required ProgrammeAssignment assignment,
    required List<ProgrammeSlotSnapshot> sourceSlots,
    required List<ProgrammeSlotOutcome> outcomes,
  }) {
    final requiredSlots = sourceSlots.where(_isRequiredSlot).toList()
      ..sort(_compareSlotSnapshots);

    if (requiredSlots.isEmpty) {
      return AssignmentProgressSnapshot(
        assignmentId: assignment.id,
        isAuthoritative: false,
        hasStarted: false,
        completedRequiredSlotCount: 0,
        totalRequiredSlotCount: 0,
        completionPercent: null,
        currentPosition: null,
        limitationNote: 'Source programme has no required session slots.',
      );
    }

    final currentSlot = _findSlotAtCursor(
      slots: sourceSlots,
      weekIndex: assignment.currentWeek,
      dayKey: assignment.currentDayKey,
      slotIndex: assignment.currentSessionOrder,
    );

    if (currentSlot == null) {
      return AssignmentProgressSnapshot(
        assignmentId: assignment.id,
        isAuthoritative: false,
        hasStarted: _hasTerminalRequiredOutcomes(requiredSlots, outcomes),
        completedRequiredSlotCount: _countCompletedRequired(requiredSlots, outcomes),
        totalRequiredSlotCount: requiredSlots.length,
        completionPercent: null,
        currentPosition: null,
        limitationNote:
            'Assignment cursor does not match any slot on the source programme.',
      );
    }

    final completedRequired =
        _countCompletedRequired(requiredSlots, outcomes);
    final totalRequired = requiredSlots.length;
    final initialSlot = requiredSlots.first;
    final atInitialCursor = assignment.currentWeek == initialSlot.weekIndex &&
        assignment.currentDayKey == initialSlot.dayKey &&
        assignment.currentSessionOrder == initialSlot.slotIndex;
    final hasTerminalOutcomes =
        _hasTerminalRequiredOutcomes(requiredSlots, outcomes);
    final hasStarted = hasTerminalOutcomes ||
        !atInitialCursor ||
        assignment.status == ProgrammeAssignmentStatus.completed;

    final percent = totalRequired == 0
        ? 0
        : ((completedRequired / totalRequired) * 100).round();

    return AssignmentProgressSnapshot(
      assignmentId: assignment.id,
      isAuthoritative: true,
      hasStarted: hasStarted,
      completedRequiredSlotCount: completedRequired,
      totalRequiredSlotCount: totalRequired,
      completionPercent: percent,
      currentPosition: ProgrammeMigrationPosition(
        weekIndex: currentSlot.weekIndex,
        dayKey: currentSlot.dayKey,
        dayIndex: currentSlot.dayIndex,
        slotIndex: currentSlot.slotIndex,
        slotId: currentSlot.slotId,
        protocolId: currentSlot.protocolId,
        sessionName: currentSlot.sessionName,
      ),
    );
  }

  static ProgrammeMigrationChangeScope analyzeChangeScope({
    required ProgrammeVersionComparisonSummary comparison,
    required ProgrammeMigrationPosition? currentPosition,
  }) {
    if (comparison.isIdentical && !comparison.isPartial) {
      return const ProgrammeMigrationChangeScope(
        isIdentical: true,
        affectsCurrentSession: false,
        currentSessionRemoved: false,
        currentSessionRevisionOnly: false,
        affectsCurrentWeek: false,
        affectsPastOrCurrentPosition: false,
        affectsFutureOnly: false,
        affectsFutureWeeksOnly: false,
        hasStructuralChanges: false,
      );
    }

    if (currentPosition == null) {
      return ProgrammeMigrationChangeScope(
        isIdentical: false,
        affectsCurrentSession: comparison.slotChanges.any(
          (change) => change.changeType != ProgrammeChangeType.unchanged,
        ),
        currentSessionRemoved: false,
        currentSessionRevisionOnly: false,
        affectsCurrentWeek: comparison.weekChanges.any(
          (change) => change.changeType != ProgrammeChangeType.unchanged,
        ),
        affectsPastOrCurrentPosition: true,
        affectsFutureOnly: false,
        affectsFutureWeeksOnly: false,
        hasStructuralChanges: comparison.hasStructuralChanges,
      );
    }

    var affectsCurrentSession = false;
    var currentSessionRemoved = false;
    var currentSessionRevisionOnly = false;
    var affectsCurrentWeek = false;
    var affectsPastOrCurrentPosition = false;
    var affectsFutureOnly = true;
    var affectsFutureWeeksOnly = true;
    var hasNonFutureChange = false;

    for (final change in comparison.slotChanges) {
      if (change.changeType == ProgrammeChangeType.unchanged) continue;

      final sourceSlot = change.sourceSlot;
      if (sourceSlot == null) {
        hasNonFutureChange = true;
        affectsFutureOnly = false;
        continue;
      }

      final relation = _compareSlotToPosition(sourceSlot, currentPosition);
      if (relation == 0) {
        hasNonFutureChange = true;
        affectsFutureOnly = false;
        affectsFutureWeeksOnly = false;
        affectsCurrentSession = true;
        if (change.changeType == ProgrammeChangeType.removed) {
          currentSessionRemoved = true;
        } else if (change.changeType == ProgrammeChangeType.modified &&
            change.changedFields.length == 1 &&
            change.changedFields.single == 'protocolId' &&
            sourceSlot.sessionLineageId ==
                change.targetSlot?.sessionLineageId) {
          currentSessionRevisionOnly = true;
        }
      } else if (relation < 0) {
        hasNonFutureChange = true;
        affectsFutureOnly = false;
        affectsFutureWeeksOnly = false;
        affectsPastOrCurrentPosition = true;
      } else if (sourceSlot.weekIndex <= currentPosition.weekIndex) {
        affectsFutureWeeksOnly = false;
      }
    }

    for (final change in comparison.dayChanges) {
      if (change.changeType == ProgrammeChangeType.unchanged) continue;
      hasNonFutureChange = true;
      affectsFutureOnly = false;
      affectsFutureWeeksOnly = false;

      final sourceDay = change.sourceDay;
      if (sourceDay == null) continue;

      if (sourceDay.weekIndex < currentPosition.weekIndex ||
          (sourceDay.weekIndex == currentPosition.weekIndex &&
              sourceDay.dayIndex <= currentPosition.dayIndex)) {
        affectsPastOrCurrentPosition = true;
      }
      if (sourceDay.weekIndex == currentPosition.weekIndex) {
        affectsCurrentWeek = true;
        affectsFutureWeeksOnly = false;
      } else if (sourceDay.weekIndex < currentPosition.weekIndex) {
        affectsPastOrCurrentPosition = true;
      }
    }

    for (final change in comparison.weekChanges) {
      if (change.changeType == ProgrammeChangeType.unchanged) continue;
      hasNonFutureChange = true;
      affectsFutureOnly = false;

      final sourceWeek = change.sourceWeek;
      if (sourceWeek != null && sourceWeek.weekIndex <= currentPosition.weekIndex) {
        affectsPastOrCurrentPosition = true;
        affectsFutureWeeksOnly = false;
      }
      if (sourceWeek != null && sourceWeek.weekIndex == currentPosition.weekIndex) {
        affectsCurrentWeek = true;
      }
    }

    if (!hasNonFutureChange &&
        comparison.metadataChanges.isEmpty &&
        comparison.exerciseSetChange.addedExercises.isEmpty &&
        comparison.exerciseSetChange.removedExercises.isEmpty) {
      affectsFutureOnly = false;
      affectsFutureWeeksOnly = false;
    }

    return ProgrammeMigrationChangeScope(
      isIdentical: false,
      affectsCurrentSession: affectsCurrentSession,
      currentSessionRemoved: currentSessionRemoved,
      currentSessionRevisionOnly:
          affectsCurrentSession && currentSessionRevisionOnly,
      affectsCurrentWeek: affectsCurrentWeek,
      affectsPastOrCurrentPosition: affectsPastOrCurrentPosition,
      affectsFutureOnly: affectsFutureOnly && !hasNonFutureChange,
      affectsFutureWeeksOnly: affectsFutureWeeksOnly && !hasNonFutureChange,
      hasStructuralChanges: comparison.hasStructuralChanges,
    );
  }

  static MigrationClassification classifyAssignment({
    required ProgrammeAssignment assignment,
    required AssignmentProgressSnapshot progress,
    required ProgrammeMigrationChangeScope changeScope,
    required bool comparisonAvailable,
    required bool comparisonPartial,
  }) {
    if (assignment.status == ProgrammeAssignmentStatus.completed) {
      return MigrationClassification.alreadyCompleted;
    }

    if (assignment.status == ProgrammeAssignmentStatus.reassigned) {
      return MigrationClassification.unsupported;
    }

    if (assignment.status == ProgrammeAssignmentStatus.paused) {
      return MigrationClassification.manualReview;
    }

    if (!comparisonAvailable) {
      return MigrationClassification.cannotDetermine;
    }

    if (!progress.isAuthoritative) {
      return MigrationClassification.cannotDetermine;
    }

    if (changeScope.isIdentical && !comparisonPartial) {
      return MigrationClassification.safeImmediate;
    }

    if (!progress.hasStarted) {
      return MigrationClassification.safeImmediate;
    }

    if (changeScope.currentSessionRemoved) {
      return MigrationClassification.manualReview;
    }

    if (changeScope.affectsCurrentSession &&
        !changeScope.currentSessionRevisionOnly) {
      return MigrationClassification.manualReview;
    }

    if (changeScope.affectsPastOrCurrentPosition &&
        !changeScope.affectsFutureOnly) {
      if (changeScope.affectsCurrentSession &&
          changeScope.currentSessionRevisionOnly) {
        return MigrationClassification.safeAfterCurrentSession;
      }
      if (changeScope.affectsCurrentWeek && !changeScope.affectsCurrentSession) {
        return MigrationClassification.safeAfterCurrentWeek;
      }
      return MigrationClassification.manualReview;
    }

    if (changeScope.affectsFutureWeeksOnly) {
      return MigrationClassification.safeAfterCurrentWeek;
    }

    if (changeScope.affectsFutureOnly) {
      return MigrationClassification.safeAfterCurrentSession;
    }

    if (changeScope.affectsCurrentSession &&
        changeScope.currentSessionRevisionOnly) {
      return MigrationClassification.safeAfterCurrentSession;
    }

    return MigrationClassification.manualReview;
  }

  static String buildReasoning({
    required MigrationClassification classification,
    required AssignmentProgressSnapshot progress,
    required ProgrammeMigrationChangeScope changeScope,
    required ProgrammeVersionComparisonSummary comparison,
  }) {
    switch (classification) {
      case MigrationClassification.alreadyCompleted:
        return 'Assignment status is completed.';
      case MigrationClassification.unsupported:
        return 'Assignment is reassigned and no longer active on the source version.';
      case MigrationClassification.cannotDetermine:
        return progress.limitationNote ??
            (comparison.isPartial
                ? 'Comparison or progress facts are partial.'
                : 'Current progress cannot be resolved.');
      case MigrationClassification.safeImmediate:
        if (changeScope.isIdentical) {
          return 'No programme differences were found between the source and target versions.';
        }
        return 'Assignment has not started and no completed sessions block migration planning.';
      case MigrationClassification.safeAfterCurrentSession:
        if (changeScope.currentSessionRevisionOnly) {
          return 'The current session revision would change, but structural position is retained.';
        }
        if (changeScope.affectsFutureOnly) {
          return 'Only programme content after the current session position changed.';
        }
        return 'Current session should finish before applying target version content.';
      case MigrationClassification.safeAfterCurrentWeek:
        return 'Only programme content after the current week changed.';
      case MigrationClassification.manualReview:
        if (changeScope.currentSessionRemoved) {
          return 'The current session slot was removed in the target programme.';
        }
        if (changeScope.affectsPastOrCurrentPosition) {
          return 'Programme structure diverged at or before the athlete\'s current position.';
        }
        return 'Programme structure diverged in a way that requires coach review.';
    }
  }

  static MigrationSummary buildSummary(List<AssignmentMigrationPlan> plans) {
    var safeImmediate = 0;
    var safeAfterCurrentWeek = 0;
    var safeAfterCurrentSession = 0;
    var manualReview = 0;
    var completed = 0;
    var cancelled = 0;
    var unknown = 0;

    for (final plan in plans) {
      switch (plan.migrationClassification) {
        case MigrationClassification.alreadyCompleted:
          completed++;
        case MigrationClassification.safeImmediate:
          safeImmediate++;
        case MigrationClassification.safeAfterCurrentWeek:
          safeAfterCurrentWeek++;
        case MigrationClassification.safeAfterCurrentSession:
          safeAfterCurrentSession++;
        case MigrationClassification.manualReview:
          manualReview++;
        case MigrationClassification.cannotDetermine:
          unknown++;
        case MigrationClassification.unsupported:
          cancelled++;
      }
    }

    return MigrationSummary(
      totalAssignments: plans.length,
      safeImmediate: safeImmediate,
      safeAfterCurrentWeek: safeAfterCurrentWeek,
      safeAfterCurrentSession: safeAfterCurrentSession,
      manualReview: manualReview,
      completed: completed,
      cancelled: cancelled,
      unknown: unknown,
    );
  }

  static bool _isRequiredSlot(ProgrammeSlotSnapshot slot) {
    if (slot.isOptional) return false;
    return slot.completionExpectation != 'optional';
  }

  static int _compareSlotSnapshots(ProgrammeSlotSnapshot a, ProgrammeSlotSnapshot b) {
    final weekCompare = a.weekIndex.compareTo(b.weekIndex);
    if (weekCompare != 0) return weekCompare;

    final dayCompare = a.dayIndex.compareTo(b.dayIndex);
    if (dayCompare != 0) return dayCompare;

    return a.slotIndex.compareTo(b.slotIndex);
  }

  static ProgrammeSlotSnapshot? _findSlotAtCursor({
    required List<ProgrammeSlotSnapshot> slots,
    required int weekIndex,
    required String dayKey,
    required int slotIndex,
  }) {
    for (final slot in slots) {
      if (slot.weekIndex == weekIndex &&
          slot.dayKey == dayKey &&
          slot.slotIndex == slotIndex) {
        return slot;
      }
    }
    return null;
  }

  static int _compareSlotToPosition(
    ProgrammeSlotSnapshot slot,
    ProgrammeMigrationPosition position,
  ) {
    final weekCompare = slot.weekIndex.compareTo(position.weekIndex);
    if (weekCompare != 0) return weekCompare;

    final dayCompare = slot.dayIndex.compareTo(position.dayIndex);
    if (dayCompare != 0) return dayCompare;

    return slot.slotIndex.compareTo(position.slotIndex);
  }

  static bool _isTerminalOutcome(ProgrammeSlotOutcome outcome) {
    return outcome.outcomeStatus.isTerminal;
  }

  static int _countCompletedRequired(
    List<ProgrammeSlotSnapshot> requiredSlots,
    List<ProgrammeSlotOutcome> outcomes,
  ) {
    final requiredSlotIds = requiredSlots.map((slot) => slot.slotId).toSet();
    return outcomes
        .where(
          (outcome) =>
              requiredSlotIds.contains(outcome.sessionSlotId) &&
              _isTerminalOutcome(outcome),
        )
        .length;
  }

  static bool _hasTerminalRequiredOutcomes(
    List<ProgrammeSlotSnapshot> requiredSlots,
    List<ProgrammeSlotOutcome> outcomes,
  ) {
    return _countCompletedRequired(requiredSlots, outcomes) > 0;
  }
}
