import '../models/performance_result_data.dart';
import '../models/training_session_record.dart';
import '../services/interval_capture_contract.dart';
import '../services/interval_result_math.dart';
import 'eligible_performance_evidence.dart';
import 'progression_comparison.dart';

abstract final class IntervalProgressionComparison {
  static ProgressionComparison compare({
    required IntervalResultData current,
    IntervalResultData? previous,
    DateTime? previousPerformedAt,
  }) {
    final family = current.comparisonFamily;
    if (family == null || family.isEmpty) {
      return ProgressionComparison.insufficient;
    }
    if (previous == null) return ProgressionComparison.first;
    if (!_compatible(current, previous)) {
      return ProgressionComparison.notComparable;
    }
    final currentAvg = IntervalResultMath.averagePaceSecondsPerKm(current);
    final previousAvg = IntervalResultMath.averagePaceSecondsPerKm(previous);
    if (currentAvg == null || previousAvg == null) {
      return ProgressionComparison.insufficient;
    }
    final faster = previousAvg - currentAvg;
    final tolerance = _tolerance(previousAvg);
    final currentSpread = IntervalResultMath.paceSpreadSeconds(current);
    final previousSpread = IntervalResultMath.paceSpreadSeconds(previous);
    final consistencyWorse =
        currentSpread != null &&
        previousSpread != null &&
        currentSpread > previousSpread + 15 &&
        currentSpread > previousSpread * 1.5;
    final moreWork =
        current.recordedCount > previous.recordedCount &&
        (current.prescribedCount ?? current.intervals.length) >=
            (previous.prescribedCount ?? previous.intervals.length);

    final deltas = <MetricDelta>[
      if (faster.abs() > 0.5)
        MetricDelta(
          key: 'pace',
          label: '${faster > 0 ? '+' : ''}${faster.round().abs()} sec/km ${faster > 0 ? 'faster' : 'slower'}',
        ),
      if (moreWork)
        MetricDelta(
          key: 'intervals',
          label:
              '${current.recordedCount - previous.recordedCount} additional interval completed',
        ),
    ];

    if (faster > tolerance && !consistencyWorse) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.improved,
        confidence: EvidenceConfidence.high,
        summary: '${faster.round()} sec faster',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: family,
      );
    }
    if (faster > tolerance && consistencyWorse) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.mixed,
        confidence: EvidenceConfidence.moderate,
        summary: 'Faster average but materially worse consistency',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: family,
      );
    }
    if (faster.abs() <= tolerance && moreWork) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.improved,
        confidence: EvidenceConfidence.moderate,
        summary: 'More prescribed work completed',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: family,
      );
    }
    if (faster.abs() <= tolerance) {
      return ProgressionComparison(
        outcome: ProgressionOutcome.matched,
        confidence: EvidenceConfidence.high,
        summary: 'Matched last performance',
        deltas: deltas,
        previousPerformedAt: previousPerformedAt,
        comparisonKey: family,
      );
    }
    return ProgressionComparison(
      outcome: ProgressionOutcome.belowLastPerformance,
      confidence: EvidenceConfidence.high,
      summary: 'Below last performance',
      deltas: deltas,
      previousPerformedAt: previousPerformedAt,
      comparisonKey: family,
    );
  }

  static ({IntervalResultData data, DateTime completedAt})? previousComparable({
    required TrainingSessionRecord current,
    required IntervalResultData currentData,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    for (final record in EligiblePerformanceEvidence.priorsNewestFirst(
      current: current,
      athleteHistory: athleteHistory,
    )) {
      for (final block in record.blockResults) {
        final data = block.resultData;
        if (data is! IntervalResultData) continue;
        if (!_compatible(currentData, data)) continue;
        return (data: data, completedAt: record.performanceChronologyAt);
      }
    }
    return null;
  }

  static String familyLabel(IntervalResultData data) {
    return IntervalCaptureContract.familyLabel(workSeconds: data.workSeconds);
  }

  static bool _compatible(IntervalResultData current, IntervalResultData other) {
    if (current.paceUnit != other.paceUnit) return false;
    if (current.workSeconds == null ||
        other.workSeconds == null ||
        current.workSeconds != other.workSeconds) {
      return false;
    }
    final currentFamily = current.comparisonFamily;
    final otherFamily = other.comparisonFamily;
    if (currentFamily == null || otherFamily == null) return false;
    return currentFamily == otherFamily;
  }

  static double _tolerance(double previous) {
    final relative = previous.abs() * 0.01;
    return relative > 0.5 ? relative : 0.5;
  }

}
