import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_vocabulary.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/models/training_session_record_status.dart';
import '../../programme/models/programme_template.dart';

/// A programme slot scheduled after the current cursor position.
class FutureProgrammeSlotRef {
  const FutureProgrammeSlotRef({
    required this.slotId,
    required this.weekNumber,
    required this.dayKey,
    required this.sessionOrder,
    required this.protocolId,
    required this.slotTitle,
  });

  final String slotId;
  final int weekNumber;
  final String dayKey;
  final int sessionOrder;
  final String protocolId;
  final String slotTitle;
}

/// Finds unresolved programme slots that occur after a completed slot.
class ProgrammeFutureSlotFinder {
  const ProgrammeFutureSlotFinder();

  List<FutureProgrammeSlotRef> listFutureSlots({
    required ProgrammeTemplateTree tree,
    required int afterWeekNumber,
    required String afterDayKey,
    required int afterSessionOrder,
    required List<ProgrammeSlotOutcome> outcomes,
    String? matchingProtocolId,
  }) {
    final outcomeBySlotId = {
      for (final outcome in outcomes) outcome.sessionSlotId: outcome,
    };

    final refs = <FutureProgrammeSlotRef>[];
    final sortedWeeks = tree.weekNodes.toList()
      ..sort((a, b) => a.week.weekNumber.compareTo(b.week.weekNumber));

    for (final weekNode in sortedWeeks) {
      for (final dayNode in weekNode.sortedDays) {
        for (final slot in dayNode.sortedSlots) {
          if (!_isAfterCursor(
            slotWeek: weekNode.week.weekNumber,
            slotDayKey: dayNode.day.dayKey,
            slotOrder: slot.sessionOrder,
            afterWeekNumber: afterWeekNumber,
            afterDayKey: afterDayKey,
            afterSessionOrder: afterSessionOrder,
          )) {
            continue;
          }

          if (!_isUnresolved(outcomeBySlotId[slot.id]?.outcomeStatus)) {
            continue;
          }

          if (matchingProtocolId != null && slot.protocolId != matchingProtocolId) {
            continue;
          }

          refs.add(
            FutureProgrammeSlotRef(
              slotId: slot.id,
              weekNumber: weekNode.week.weekNumber,
              dayKey: dayNode.day.dayKey,
              sessionOrder: slot.sessionOrder,
              protocolId: slot.protocolId,
              slotTitle: slot.displayTitle ?? slot.protocolId,
            ),
          );
        }
      }
    }

    return refs;
  }

  bool _isAfterCursor({
    required int slotWeek,
    required String slotDayKey,
    required int slotOrder,
    required int afterWeekNumber,
    required String afterDayKey,
    required int afterSessionOrder,
  }) {
    if (slotWeek > afterWeekNumber) return true;
    if (slotWeek < afterWeekNumber) return false;

    final slotDay = _dayOrdinal(slotDayKey);
    final afterDay = _dayOrdinal(afterDayKey);
    if (slotDay > afterDay) return true;
    if (slotDay < afterDay) return false;

    return slotOrder > afterSessionOrder;
  }

  int _dayOrdinal(String dayKey) {
    final match = RegExp(r'day_(\d+)').firstMatch(dayKey);
    if (match == null) return 0;
    return int.tryParse(match.group(1) ?? '') ?? 0;
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
}

/// Strength performance summary extracted from a completed M8 record.
class CompletedStrengthPerformanceSummary {
  const CompletedStrengthPerformanceSummary({
    required this.exerciseId,
    required this.exerciseName,
    required this.prescribedSetCount,
    required this.completedPrescribedSetCount,
    required this.topLoadKg,
  });

  final String exerciseId;
  final String exerciseName;
  final int prescribedSetCount;
  final int completedPrescribedSetCount;
  final double? topLoadKg;

  bool get allPrescribedSetsCompleted =>
      prescribedSetCount > 0 &&
      completedPrescribedSetCount >= prescribedSetCount;
}

/// Deterministic post-completion adaptation evaluation.
class PostCompletionAdaptationEvaluator {
  const PostCompletionAdaptationEvaluator();

  static const loadProgressionDeltaKg = 2.5;

  /// Returns null when no adaptation should execute.
  AdaptationEvaluation? evaluate({
    required TrainingSessionRecord record,
    required String plannedProtocolId,
    required String completedSlotId,
    required List<ProgrammeSlotOutcome> assignmentOutcomes,
    required FutureProgrammeSlotRef? nextMatchingFutureSlot,
    required CompletedStrengthPerformanceSummary? strengthSummary,
    required bool endedEarly,
    required int priorCompletedSameProtocolCount,
  }) {
    if (record.status != TrainingSessionRecordStatus.completed) {
      return null;
    }

    if (nextMatchingFutureSlot == null) {
      return null;
    }

    if (endedEarly) {
      return AdaptationEvaluation(
        type: AdaptationEvaluationType.protocolSubstitution,
        explanation:
            'Session ended early — recovery substitution scheduled for the next '
            '${nextMatchingFutureSlot.slotTitle} session.',
        athleteSummary:
            'Next ${nextMatchingFutureSlot.slotTitle} session adjusted for recovery.',
        targetSlot: nextMatchingFutureSlot,
        triggerSlotId: completedSlotId,
      );
    }

    if (strengthSummary == null || !strengthSummary.allPrescribedSetsCompleted) {
      return null;
    }

    final priorCompletedSameProtocol = priorCompletedSameProtocolCount;

    if (priorCompletedSameProtocol < 1) {
      return null;
    }

    final currentLoad = strengthSummary.topLoadKg;
    if (currentLoad == null) {
      return null;
    }

    final newLoad = currentLoad + loadProgressionDeltaKg;
    final formattedLoad = _formatLoad(newLoad);

    return AdaptationEvaluation(
      type: AdaptationEvaluationType.loadProgression,
      explanation:
          'Completed all prescribed repetitions for two consecutive sessions. '
          'Progression rule increased target load by ${loadProgressionDeltaKg.toStringAsFixed(1)} kg.',
      athleteSummary:
          'Next ${nextMatchingFutureSlot.slotTitle} target increased to $formattedLoad.',
      targetSlot: nextMatchingFutureSlot,
      triggerSlotId: completedSlotId,
      exerciseId: strengthSummary.exerciseId,
      exerciseName: strengthSummary.exerciseName,
      previousLoadKg: currentLoad,
      newLoadKg: newLoad,
    );
  }

  CompletedStrengthPerformanceSummary? summarizeStrengthPerformance(
    TrainingSessionRecord record,
  ) {
    for (final block in record.blockResults) {
      if (block.exerciseResults.isEmpty) continue;

      final exercise = block.exerciseResults.first;
      final completedSets =
          exercise.setResults.where((set) => set.completed).toList();
      if (completedSets.isEmpty) continue;

      final prescribedCount = exercise.setResults.length;
      final completedPrescribed = completedSets.length;

      double? topLoad;
      for (final set in completedSets) {
        if (set.loadUnit != 'kg' || set.load == null) continue;
        if (topLoad == null || set.load! > topLoad) {
          topLoad = set.load;
        }
      }

      return CompletedStrengthPerformanceSummary(
        exerciseId: exercise.sourceExerciseId,
        exerciseName: exercise.exerciseSnapshot.displayName,
        prescribedSetCount: prescribedCount,
        completedPrescribedSetCount: completedPrescribed,
        topLoadKg: topLoad,
      );
    }

    return null;
  }

  String _formatLoad(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()} kg';
    }
    return '${value.toStringAsFixed(1)} kg';
  }
}

enum AdaptationEvaluationType {
  loadProgression,
  protocolSubstitution,
}

class AdaptationEvaluation {
  const AdaptationEvaluation({
    required this.type,
    required this.explanation,
    required this.athleteSummary,
    required this.targetSlot,
    required this.triggerSlotId,
    this.exerciseId,
    this.exerciseName,
    this.previousLoadKg,
    this.newLoadKg,
  });

  final AdaptationEvaluationType type;
  final String explanation;
  final String athleteSummary;
  final FutureProgrammeSlotRef targetSlot;
  final String triggerSlotId;
  final String? exerciseId;
  final String? exerciseName;
  final double? previousLoadKg;
  final double? newLoadKg;
}
