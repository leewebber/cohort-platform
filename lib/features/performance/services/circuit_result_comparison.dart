import '../models/circuit_station_actual.dart';
import '../models/performance_result_data.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import 'strength_result_comparison.dart';

class CircuitComparison {
  const CircuitComparison({
    required this.status,
    required this.familyLabel,
    this.previous,
    this.primaryLabel,
    this.currentPrimary,
    this.previousPrimary,
  });

  final StrengthExerciseComparisonStatus status;
  final String familyLabel;
  final CircuitResultData? previous;
  final String? primaryLabel;
  final double? currentPrimary;
  final double? previousPrimary;
}

class CircuitResultComparison {
  const CircuitResultComparison._();

  static const relativeTolerance = 0.01;

  static CircuitResultData? dataFor(TrainingBlockResult block) {
    final data = block.resultData;
    return data is CircuitResultData ? data : null;
  }

  static bool isComparable(CircuitResultData current, CircuitResultData other) {
    if (current.comparisonFamily.isEmpty || other.comparisonFamily.isEmpty) {
      return false;
    }
    if (current.comparisonFamily != other.comparisonFamily) return false;
    if (current.format != other.format) return false;
    if (current.prescribedCount != other.prescribedCount) return false;
    if (current.stations.length != other.stations.length) return false;
    for (var i = 0; i < current.stations.length; i++) {
      final a = current.stations[i];
      final b = other.stations[i];
      if (a.stationId != b.stationId ||
          a.primaryMetric != b.primaryMetric ||
          a.prescribedCalories != b.prescribedCalories ||
          a.prescribedReps != b.prescribedReps ||
          a.prescribedDistanceMeters != b.prescribedDistanceMeters) {
        return false;
      }
    }
    return true;
  }

  static CircuitComparison compare({
    required TrainingBlockResult block,
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final data = dataFor(block);
    if (data == null || !data.usesStationCapture) {
      return const CircuitComparison(
        status: StrengthExerciseComparisonStatus.notComparable,
        familyLabel: 'Circuit',
      );
    }
    final label = data.format == 'emom' ? 'EMOM' : 'Circuit';
    final previous = previousComparable(
      current: current,
      block: block,
      athleteHistory: athleteHistory,
    );
    final primary = primarySignal(data);
    if (previous == null) {
      return CircuitComparison(
        status: StrengthExerciseComparisonStatus.baseline,
        familyLabel: label,
        primaryLabel: primary?.label,
        currentPrimary: primary?.value,
      );
    }
    final previousPrimary = primarySignal(previous.data);
    if (primary == null || previousPrimary == null) {
      return CircuitComparison(
        status: StrengthExerciseComparisonStatus.notComparable,
        familyLabel: label,
        previous: previous.data,
        primaryLabel: primary?.label,
        currentPrimary: primary?.value,
        previousPrimary: previousPrimary?.value,
      );
    }
    final delta = primary.value - previousPrimary.value;
    final tolerance = previousPrimary.value.abs() * relativeTolerance;
    final status = delta > tolerance
        ? (primary.higherIsBetter
              ? StrengthExerciseComparisonStatus.improved
              : StrengthExerciseComparisonStatus.belowPrevious)
        : delta < -tolerance
        ? (primary.higherIsBetter
              ? StrengthExerciseComparisonStatus.belowPrevious
              : StrengthExerciseComparisonStatus.improved)
        : StrengthExerciseComparisonStatus.maintained;
    return CircuitComparison(
      status: status,
      familyLabel: label,
      previous: previous.data,
      primaryLabel: primary.label,
      currentPrimary: primary.value,
      previousPrimary: previousPrimary.value,
    );
  }

  static ({TrainingBlockResult block, CircuitResultData data})? previousComparable({
    required TrainingSessionRecord current,
    required TrainingBlockResult block,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final data = dataFor(block);
    if (data == null) return null;
    final candidates = athleteHistory.where((record) {
      if (record.recordId == current.recordId) return false;
      if (record.status != TrainingSessionRecordStatus.completed) return false;
      return true;
    }).toList()..sort((a, b) {
      final aAt = a.completedAt ?? a.startedAt;
      final bAt = b.completedAt ?? b.startedAt;
      return bAt.compareTo(aAt);
    });
    for (final record in candidates) {
      for (final other in record.blockResults) {
        final otherData = dataFor(other);
        if (otherData == null) continue;
        if (isComparable(data, otherData)) {
          return (block: other, data: otherData);
        }
      }
    }
    return null;
  }

  static ({String label, double value, bool higherIsBetter})? primarySignal(
    CircuitResultData result,
  ) {
    final recorded = result.stations.where((row) => row.hasRecordedActual);
    if (recorded.isEmpty) return null;
    final calories = recorded.where(
      (row) => row.primaryMetric == CircuitStationMetric.calories,
    );
    if (calories.isNotEmpty &&
        calories.every((row) => row.calories != null)) {
      final total = calories.fold<double>(
        0,
        (sum, row) => sum + row.calories!,
      );
      return (label: 'Total calories', value: total, higherIsBetter: true);
    }
    final distances = recorded.where(
      (row) => row.primaryMetric == CircuitStationMetric.distance,
    );
    if (distances.isNotEmpty &&
        distances.every((row) => row.distance != null)) {
      final total = distances.fold<double>(
        0,
        (sum, row) => sum + row.distance!,
      );
      return (label: 'Total station distance', value: total, higherIsBetter: true);
    }
    final reps = recorded.where(
      (row) => row.primaryMetric == CircuitStationMetric.reps,
    );
    if (reps.isNotEmpty && reps.every((row) => row.reps != null)) {
      final total = reps.fold<double>(0, (sum, row) => sum + row.reps!);
      return (label: 'Total reps', value: total, higherIsBetter: true);
    }
    return null;
  }
}
