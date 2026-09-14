import '../models/performance_result_data.dart';
import '../models/training_session_record.dart';
import '../services/circuit_result_comparison.dart';
import 'eligible_performance_evidence.dart';
import 'progression_comparison.dart';

abstract final class CircuitProgressionComparison {
  static ProgressionComparison compare({
    required CircuitResultData current,
    CircuitResultData? previous,
    DateTime? previousPerformedAt,
    AmrapResultData? currentAmrap,
    AmrapResultData? previousAmrap,
    ForTimeResultData? currentForTime,
    ForTimeResultData? previousForTime,
  }) {
    if (currentForTime != null) {
      return _forTime(
        currentForTime,
        previousForTime,
        previousPerformedAt,
      );
    }
    if (currentAmrap != null) {
      return _amrap(currentAmrap, previousAmrap, previousPerformedAt);
    }
    if (previous == null) return ProgressionComparison.first;
    if (current.prescribedTargetsUsed == false &&
        previous.prescribedTargetsUsed != false) {
      return const ProgressionComparison(
        outcome: ProgressionOutcome.notComparable,
        confidence: EvidenceConfidence.none,
        summary: 'Adjusted-target work is not compared as prescribed-target work',
        prescriptionChanged: true,
      );
    }
    if (!CircuitResultComparison.sameFamily(current, previous)) {
      return ProgressionComparison.notComparable;
    }
    if (current.isFixedWork &&
        !CircuitResultComparison.loadsAreComparable(current, previous)) {
      return ProgressionComparison.notComparable;
    }
    final primary = CircuitResultComparison.primarySignal(current);
    final previousPrimary = CircuitResultComparison.primarySignal(previous);
    if (primary == null || previousPrimary == null) {
      return ProgressionComparison.insufficient;
    }
    final delta = primary.value - previousPrimary.value;
    final tolerance = previousPrimary.value.abs() * 0.01;
    final improved = primary.higherIsBetter ? delta > tolerance : delta < -tolerance;
    final below = primary.higherIsBetter ? delta < -tolerance : delta > tolerance;
    if (improved) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.improved,
        confidence: EvidenceConfidence.high,
        summary: current.isEmomScore
            ? '${current.completedRounds - previous.completedRounds} additional interval completed'
            : primary.higherIsBetter
            ? 'More work completed'
            : 'Faster completion',
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.comparisonFamily,
      );
    }
    if (below) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.belowLastPerformance,
        confidence: EvidenceConfidence.high,
        summary: 'Below last performance',
        previousPerformedAt: previousPerformedAt,
        comparisonKey: current.comparisonFamily,
      );
    }
    return ProgressionComparison(
      outcome: ProgressionOutcome.matched,
      confidence: EvidenceConfidence.high,
      summary: 'Matched last performance',
      previousPerformedAt: previousPerformedAt,
      comparisonKey: current.comparisonFamily,
    );
  }

  static ({CircuitResultData data, DateTime completedAt})? previousComparable({
    required TrainingSessionRecord current,
    required CircuitResultData currentData,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    for (final record in EligiblePerformanceEvidence.priorsNewestFirst(
      current: current,
      athleteHistory: athleteHistory,
    )) {
      for (final block in record.blockResults) {
        final data = block.resultData;
        if (data is! CircuitResultData) continue;
        if (currentData.isFixedWork
            ? CircuitResultComparison.sameFamily(currentData, data)
            : CircuitResultComparison.isComparable(currentData, data)) {
          return (data: data, completedAt: record.performanceChronologyAt);
        }
      }
    }
    return null;
  }

  static ProgressionComparison _amrap(
    AmrapResultData current,
    AmrapResultData? previous,
    DateTime? previousPerformedAt,
  ) {
    if (previous == null) return ProgressionComparison.first;
    final currentScore = current.rounds * 1000 + current.extraReps;
    final previousScore = previous.rounds * 1000 + previous.extraReps;
    if (currentScore > previousScore) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.improved,
        confidence: EvidenceConfidence.high,
        summary: 'More rounds/reps',
        previousPerformedAt: previousPerformedAt,
        comparisonKey: 'amrap',
      );
    }
    if (currentScore < previousScore) {
      return const ProgressionComparison(
        outcome: ProgressionOutcome.belowLastPerformance,
        confidence: EvidenceConfidence.high,
        summary: 'Below last performance',
        comparisonKey: 'amrap',
      );
    }
    return const ProgressionComparison(
      outcome: ProgressionOutcome.matched,
      confidence: EvidenceConfidence.high,
      summary: 'Matched last performance',
      comparisonKey: 'amrap',
    );
  }

  static ProgressionComparison _forTime(
    ForTimeResultData current,
    ForTimeResultData? previous,
    DateTime? previousPerformedAt,
  ) {
    if (previous == null) return ProgressionComparison.first;
    if (!current.completed && !previous.completed) {
      return const ProgressionComparison(
        outcome: ProgressionOutcome.insufficientEvidence,
        confidence: EvidenceConfidence.low,
        summary: 'Neither attempt completed the prescription',
        comparisonKey: 'for-time',
      );
    }
    if (current.completed && !previous.completed) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.improved,
        confidence: EvidenceConfidence.high,
        summary: 'Completed the prescription',
        previousPerformedAt: previousPerformedAt,
        comparisonKey: 'for-time',
      );
    }
    if (!current.completed && previous.completed) {
      return const ProgressionComparison(
        outcome: ProgressionOutcome.belowLastPerformance,
        confidence: EvidenceConfidence.high,
        summary: 'Below last performance',
        comparisonKey: 'for-time',
      );
    }
    final currentTime = current.elapsedSeconds;
    final previousTime = previous.elapsedSeconds;
    if (currentTime == null || previousTime == null) {
      return ProgressionComparison.insufficient;
    }
    if (currentTime < previousTime) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.improved,
        confidence: EvidenceConfidence.high,
        summary: 'Faster completion',
        previousPerformedAt: previousPerformedAt,
        comparisonKey: 'for-time',
      );
    }
    if (currentTime > previousTime) {
      return const ProgressionComparison(
        outcome: ProgressionOutcome.belowLastPerformance,
        confidence: EvidenceConfidence.high,
        summary: 'Below last performance',
        comparisonKey: 'for-time',
      );
    }
    return const ProgressionComparison(
      outcome: ProgressionOutcome.matched,
      confidence: EvidenceConfidence.high,
      summary: 'Matched last performance',
      comparisonKey: 'for-time',
    );
  }
}
