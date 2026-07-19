import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/training_session_record.dart';
import '../models/training_block_result_status.dart';
import 'endurance_metrics_calculator.dart';

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

    final summaries = <String>[];
    for (final set in completedSets.take(3)) {
      final parts = <String>[];
      if (set.reps != null) parts.add('${set.reps} reps');
      if (set.load != null) {
        parts.add('${set.load}${set.loadUnit == null ? '' : ' ${set.loadUnit}'}');
      }
      if (parts.isNotEmpty) summaries.add(parts.join(' · '));
    }

    if (summaries.isEmpty) {
      return '${completedSets.length} set${completedSets.length == 1 ? '' : 's'} logged';
    }

    final prefix = '${completedSets.length} set${completedSets.length == 1 ? '' : 's'} logged';
    if (summaries.length == 1) return '$prefix · ${summaries.first}';
    return '$prefix · ${summaries.take(2).join('; ')}';
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
    final elapsed =
        EnduranceMetricsCalculator.formatDuration(result.elapsedSeconds);
    if (result.timeCapped) return 'Time capped at $elapsed';
    return 'Completed in $elapsed';
  }

  static String _formatInterval(IntervalResultData result) {
    if (result.totalIntervals != null) {
      return '${result.intervalsCompleted} of ${result.totalIntervals} intervals completed';
    }
    return '${result.intervalsCompleted} intervals completed';
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
    final duration =
        EnduranceMetricsCalculator.formatDuration(result.durationSeconds);
    if (duration.isEmpty) return 'Performance recorded';
    return duration;
  }

  static String _formatEndurance(EnduranceResultData result) {
    final parts = <String>[];
    if (result.distance != null) {
      parts.add('${result.distance} ${result.distanceUnit}');
    }
    final duration =
        EnduranceMetricsCalculator.formatDuration(result.durationSeconds);
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
