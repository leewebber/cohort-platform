import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/training_session_record.dart';
import '../models/training_block_result_status.dart';
import 'endurance_metrics_calculator.dart';
import 'interval_result_math.dart';

class PerformanceResultSummaryFormatter {
  const PerformanceResultSummaryFormatter._();

  static String formatBlock(TrainingBlockResult block) {
    if (block.status == TrainingBlockResultStatus.skipped) {
      return 'Skipped';
    }

    final result = block.resultData;
    if (result == null) {
      return _statusFallback(block.status);
    }

    switch (result.resultType) {
      case PerformanceResultType.completion:
        return _formatCompletion(result as CompletionResultData, block.status);
      case PerformanceResultType.strength:
        return _formatStrength(block);
      case PerformanceResultType.amrap:
        return _formatAmrap(result as AmrapResultData);
      case PerformanceResultType.forTime:
        return _formatForTime(result as ForTimeResultData);
      case PerformanceResultType.interval:
        return _formatInterval(result as IntervalResultData);
      case PerformanceResultType.distance:
        return _formatDistance(result as DistanceResultData);
      case PerformanceResultType.duration:
        return _formatDuration(result as DurationResultData);
      case PerformanceResultType.endurance:
        return _formatEndurance(result as EnduranceResultData);
      case PerformanceResultType.rounds:
        return _formatRounds(result as RoundsResultData);
      case PerformanceResultType.circuit:
        return _formatCircuit(result as CircuitResultData);
      case PerformanceResultType.customMetric:
        return _formatCustom(result as CustomMetricResultData);
    }
  }

  static String _formatCompletion(
    CompletionResultData result,
    TrainingBlockResultStatus status,
  ) {
    if (status == TrainingBlockResultStatus.completed && result.completed) {
      return 'Completed as prescribed';
    }
    if (result.completed) return 'Completed';
    return 'Not completed';
  }

  static String _formatStrength(TrainingBlockResult block) {
    final completedSets = block.exerciseResults
        .expand((exercise) => exercise.setResults.where((set) => set.completed))
        .toList(growable: false);
    if (completedSets.isEmpty) {
      return _statusFallback(block.status);
    }
    return '${completedSets.length} set${completedSets.length == 1 ? '' : 's'} recorded';
  }

  static String _formatAmrap(AmrapResultData result) {
    if (result.rounds == 0 && result.extraReps == 0) {
      return 'Performance recorded';
    }
    return '${result.rounds} rounds + ${result.extraReps} reps';
  }

  static String _formatForTime(ForTimeResultData result) {
    if (result.elapsedSeconds == null) {
      return result.timeCapped ? 'Time capped' : 'Performance recorded';
    }
    final elapsed = EnduranceMetricsCalculator.formatDuration(
      result.elapsedSeconds,
    );
    if (result.timeCapped) return 'Time capped at $elapsed';
    return 'Completed in $elapsed';
  }

  static String _formatInterval(IntervalResultData result) {
    final prescribed = result.prescribedCount;
    final count = prescribed == null
        ? '${result.recordedCount} intervals completed'
        : '${result.recordedCount}/$prescribed intervals';
    final average = IntervalResultMath.formatPace(
      IntervalResultMath.averagePaceSecondsPerKm(result),
    );
    final fastest = IntervalResultMath.formatPace(
      IntervalResultMath.fastest(result)?.paceSecondsPerKm,
    );
    return [
      count,
      if (average.isNotEmpty) 'Avg $average',
      if (fastest.isNotEmpty) 'Fastest $fastest',
    ].join(' · ');
  }

  static String _formatDistance(DistanceResultData result) {
    final parts = <String>[];
    if (result.distance != null) {
      parts.add('${result.distance} ${result.distanceUnit}');
    }
    final duration = EnduranceMetricsCalculator.formatDuration(
      result.durationSeconds,
    );
    if (duration.isNotEmpty) parts.add('in $duration');
    if (parts.isEmpty) return 'Performance recorded';
    return parts.join(' ');
  }

  static String _formatDuration(DurationResultData result) {
    final duration = EnduranceMetricsCalculator.formatDuration(
      result.durationSeconds,
    );
    if (duration.isEmpty) return 'Performance recorded';
    return duration;
  }

  static String _formatEndurance(EnduranceResultData result) {
    final parts = <String>[];
    if (result.distance != null) {
      parts.add('${result.distance} ${result.distanceUnit}');
    }
    final duration = EnduranceMetricsCalculator.formatDuration(
      result.durationSeconds,
    );
    if (duration.isNotEmpty) {
      parts.add('in $duration');
    }
    if (parts.isEmpty && !result.completed) {
      return 'Not completed';
    }
    if (parts.isEmpty) {
      return result.completed ? 'Completed' : 'Performance recorded';
    }

    final summary = parts.join(' ');
    final pace = EnduranceMetricsCalculator.formatPaceOrSpeed(
      distance: result.distance,
      distanceUnit: result.distanceUnit,
      durationSeconds: result.durationSeconds,
    );
    final hr = result.averageHeartRate == null
        ? null
        : 'Avg HR ${result.averageHeartRate} bpm';
    return [summary, pace, hr].whereType<String>().join(' · ');
  }

  static String _formatRounds(RoundsResultData result) {
    return '${result.roundsCompleted} rounds + ${result.extraReps} reps';
  }

  static String _formatCircuit(CircuitResultData result) {
    final complete = result.completedRounds;
    final target = result.targetRounds;
    final recorded = result.recordedCount;
    final prescribed = result.prescribedCount;
    if (result.format == 'emom') {
      return '$recorded/$prescribed stations recorded';
    }
    if (target == null) {
      return '$recorded stations recorded';
    }
    return '$complete/$target rounds · $recorded/$prescribed stations';
  }

  static String _formatCustom(CustomMetricResultData result) {
    if (result.label != null && result.numericValue != null) {
      final unit = result.unit == null ? '' : ' ${result.unit}';
      return '${result.label}: ${result.numericValue}$unit';
    }
    return 'Performance recorded';
  }

  static String _statusFallback(TrainingBlockResultStatus status) {
    return switch (status) {
      TrainingBlockResultStatus.completed => 'Completed',
      TrainingBlockResultStatus.skipped => 'Skipped',
      TrainingBlockResultStatus.inProgress => 'In progress',
      TrainingBlockResultStatus.notStarted => 'Not started',
    };
  }
}
