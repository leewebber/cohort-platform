import '../../session/models/session_execution_plan.dart';
import '../../session/services/block_timer_controller.dart';
import '../models/circuit_station_actual.dart';
import '../models/performance_result_data.dart';
import 'circuit_capture_contract.dart';

/// Canonical EMOM score: one [CircuitResultData.completedRounds] per interval.
class EmomScoreContract {
  const EmomScoreContract._();

  static bool appliesTo(CircuitResultData result) => result.isEmomScore;

  static int? authoredIntervalCount(SessionExecutionBlock block) {
    return CircuitCaptureContract.occurrenceCount(block);
  }

  static int suggestedCompletedIntervals({
    required CircuitResultData result,
    BlockTimerState? timer,
  }) {
    final total = result.targetRounds ?? 0;
    if (total <= 0) return 0;
    if (timer != null) {
      if (timer.isFinished) return total;
      return (timer.currentRound - 1).clamp(0, total);
    }
    final cursor = result.timerCursor;
    if (cursor != null) {
      if (cursor.isFinished) return total;
      return (cursor.currentRound - 1).clamp(0, total);
    }
    if (result.recordedCompletedRounds != null) {
      return result.recordedCompletedRounds!.clamp(0, total);
    }
    return total;
  }

  static bool stationNeedsAdjustedActual(CircuitStationActual row) {
    return row.primaryMetric == CircuitStationMetric.calories ||
        row.primaryMetric == CircuitStationMetric.reps ||
        row.primaryMetric == CircuitStationMetric.distance;
  }

  static String stationMetricLabel(CircuitStationActual row) {
    return switch (row.primaryMetric) {
      CircuitStationMetric.calories => 'calories',
      CircuitStationMetric.reps => 'reps',
      CircuitStationMetric.distance => row.distanceUnit,
      CircuitStationMetric.duration => 'seconds',
      CircuitStationMetric.load => row.loadUnit ?? 'kg',
      CircuitStationMetric.completion => 'completion',
    };
  }

  static String prescribedStationLine(CircuitStationActual row) {
    final target = switch (row.primaryMetric) {
      CircuitStationMetric.calories =>
        row.prescribedCalories == null
            ? null
            : '${row.prescribedCalories} calories',
      CircuitStationMetric.reps =>
        row.prescribedReps == null ? null : '${row.prescribedReps} reps',
      CircuitStationMetric.distance =>
        row.prescribedDistanceMeters == null &&
                (row.prescribedDistanceText == null ||
                    row.prescribedDistanceText!.trim().isEmpty)
            ? null
            : '${row.prescribedDistanceMeters ?? row.prescribedDistanceText} ${row.distanceUnit}',
      _ => null,
    };
    return target == null ? row.displayName : '${row.displayName} $target';
  }

  static String adjustedStationLine(CircuitStationActual row) {
    if (!row.hasRecordedActual) return row.displayName;
    return switch (row.primaryMetric) {
      CircuitStationMetric.calories =>
        '${row.displayName} ${row.calories} cal',
      CircuitStationMetric.reps => '${row.displayName} ${row.reps} reps',
      CircuitStationMetric.distance =>
        '${row.displayName} ${row.distance} ${row.distanceUnit}',
      _ => row.displayName,
    };
  }

  static String completedSummary(CircuitResultData result) {
    final total = result.targetRounds ?? result.completedRounds;
    final completed = result.completedRounds;
    final head = '$completed of $total intervals completed';
    if (result.prescribedTargetsUsed == false) {
      final adjusted = result.stations
          .where((row) => row.hasRecordedActual)
          .map(adjustedStationLine)
          .join(' · ');
      return [
        head,
        'Targets adjusted',
        if (adjusted.isNotEmpty) adjusted,
      ].join('\n');
    }
    final prescribed = result.stations.map(prescribedStationLine).join(' · ');
    return [
      head,
      'Prescribed targets achieved',
      if (prescribed.isNotEmpty) prescribed,
    ].join('\n');
  }

  static String comparisonLine({
    required CircuitResultData today,
    CircuitResultData? previous,
  }) {
    final todayLine =
        '${today.completedRounds} of ${today.targetRounds ?? today.completedRounds} intervals completed';
    if (previous == null) return 'Today: $todayLine';
    return 'Last time: ${previous.completedRounds} of ${previous.targetRounds ?? previous.completedRounds} intervals completed\nToday: $todayLine';
  }
}
