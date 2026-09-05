import '../models/interval_work_result.dart';
import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import 'interval_capture_contract.dart';
import 'interval_result_math.dart';
import 'strength_result_comparison.dart';

class IntervalComparison {
  const IntervalComparison({
    required this.status,
    required this.familyLabel,
    this.previous,
    this.previousCompletedAt,
    this.fastestIsPersonalRecord = false,
    this.historicalFastest,
  });

  final StrengthExerciseComparisonStatus status;
  final String familyLabel;
  final IntervalResultData? previous;
  final DateTime? previousCompletedAt;
  final bool fastestIsPersonalRecord;
  final IntervalWorkResult? historicalFastest;
}

class IntervalResultComparison {
  const IntervalResultComparison._();

  static const relativeTolerance = 0.01;
  static const absoluteTolerance = 0.5;

  static IntervalResultData? dataFor(TrainingBlockResult block) {
    final data = block.resultData;
    if (data is IntervalResultData) return data;
    return null;
  }

  static bool isComparable(IntervalResultData current, IntervalResultData other) {
    if (current.paceUnit != other.paceUnit) return false;
    if (!IntervalPaceUnit.isSupported(current.paceUnit) ||
        !IntervalPaceUnit.isSupported(other.paceUnit)) {
      return false;
    }
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

  static IntervalComparison compare({
    required TrainingBlockResult block,
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final data = dataFor(block) ?? const IntervalResultData();
    final familyLabel = IntervalCaptureContract.familyLabel(
      workSeconds: data.workSeconds ?? block.blockSnapshot.workSeconds,
    );
    final previous = previousComparable(
      current: current,
      block: block,
      athleteHistory: athleteHistory,
    );
    if (previous == null) {
      return IntervalComparison(
        status: StrengthExerciseComparisonStatus.baseline,
        familyLabel: familyLabel,
      );
    }
    final currentAvg = IntervalResultMath.averagePaceSecondsPerKm(data);
    final previousAvg = IntervalResultMath.averagePaceSecondsPerKm(
      previous.data,
    );
    if (currentAvg == null || previousAvg == null) {
      return IntervalComparison(
        status: StrengthExerciseComparisonStatus.notComparable,
        familyLabel: familyLabel,
        previous: previous.data,
        previousCompletedAt: previous.completedAt,
      );
    }
    final delta = previousAvg - currentAvg;
    final tolerance = _tolerance(previousAvg);
    final status = delta > tolerance
        ? StrengthExerciseComparisonStatus.improved
        : delta < -tolerance
        ? StrengthExerciseComparisonStatus.belowPrevious
        : StrengthExerciseComparisonStatus.maintained;
    final currentFastest = IntervalResultMath.fastest(data);
    final historical = fastestInFamily(
      current: current,
      block: block,
      athleteHistory: athleteHistory,
    );
    final isPr =
        currentFastest != null &&
        historical != null &&
        currentFastest.paceSecondsPerKm! + 1e-9 <
            historical.paceSecondsPerKm!;
    return IntervalComparison(
      status: status,
      familyLabel: familyLabel,
      previous: previous.data,
      previousCompletedAt: previous.completedAt,
      fastestIsPersonalRecord: isPr,
      historicalFastest: historical,
    );
  }

  static ({IntervalResultData data, DateTime completedAt})? previousComparable({
    required TrainingSessionRecord current,
    required TrainingBlockResult block,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final currentData = dataFor(block);
    if (currentData == null) return null;
    final currentAt = current.completedAt ?? current.startedAt;
    IntervalResultData? latest;
    DateTime? latestAt;
    for (final record in athleteHistory) {
      if (record.athleteId != current.athleteId) continue;
      if (record.recordId == current.recordId) continue;
      if (record.status != TrainingSessionRecordStatus.completed) continue;
      final at = record.completedAt ?? record.startedAt;
      if (!at.isBefore(currentAt)) continue;
      for (final candidate in record.blockResults) {
        if (candidate.resultType != PerformanceResultType.interval) continue;
        final data = dataFor(candidate);
        if (data == null || !isComparable(currentData, data)) continue;
        if (latestAt == null || at.isAfter(latestAt)) {
          latest = data;
          latestAt = at;
        }
      }
    }
    if (latest == null || latestAt == null) return null;
    return (data: latest, completedAt: latestAt);
  }

  static IntervalWorkResult? fastestInFamily({
    required TrainingSessionRecord current,
    required TrainingBlockResult block,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final currentData = dataFor(block);
    if (currentData == null) return null;
    IntervalWorkResult? best;
    for (final record in athleteHistory) {
      if (record.athleteId != current.athleteId) continue;
      if (record.recordId == current.recordId) continue;
      if (record.status != TrainingSessionRecordStatus.completed) continue;
      for (final candidate in record.blockResults) {
        final data = dataFor(candidate);
        if (data == null || !isComparable(currentData, data)) continue;
        final fastest = IntervalResultMath.fastest(data);
        if (fastest == null) continue;
        if (best == null ||
            fastest.paceSecondsPerKm! < best.paceSecondsPerKm!) {
          best = fastest;
        }
      }
    }
    return best;
  }

  static double _tolerance(double previousAvg) {
    final relative = previousAvg.abs() * relativeTolerance;
    return relative > absoluteTolerance ? relative : absoluteTolerance;
  }
}
