import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';
import '../../session/models/session_execution_plan.dart';
import 'performance_result_data.dart';
import 'performance_result_type.dart';

class BlockCaptureModeResolver {
  const BlockCaptureModeResolver._();

  static BlockCaptureMode resolve({
    required SessionBlockType blockType,
    required WorkoutFormat workoutFormat,
    required int linkedExerciseCount,
  }) {
    switch (workoutFormat) {
      case WorkoutFormat.amrap:
        return BlockCaptureMode.amrap;
      case WorkoutFormat.forTime:
        return BlockCaptureMode.forTime;
      case WorkoutFormat.intervals:
      case WorkoutFormat.tabata:
      case WorkoutFormat.emom:
        return BlockCaptureMode.interval;
      case WorkoutFormat.rounds:
        return BlockCaptureMode.rounds;
      case WorkoutFormat.none:
      case WorkoutFormat.other:
        break;
    }

    if (_isStrengthStyle(blockType) && linkedExerciseCount > 0) {
      return BlockCaptureMode.strength;
    }

    if (blockType == SessionBlockType.custom &&
        linkedExerciseCount == 0 &&
        workoutFormat == WorkoutFormat.none) {
      return BlockCaptureMode.endurance;
    }

    if (_isSimpleCompletionBlock(blockType)) {
      return BlockCaptureMode.completion;
    }

    return BlockCaptureMode.completion;
  }

  static PerformanceResultType resultTypeFor(BlockCaptureMode mode) {
    switch (mode) {
      case BlockCaptureMode.strength:
        return PerformanceResultType.strength;
      case BlockCaptureMode.amrap:
        return PerformanceResultType.amrap;
      case BlockCaptureMode.forTime:
        return PerformanceResultType.forTime;
      case BlockCaptureMode.interval:
        return PerformanceResultType.interval;
      case BlockCaptureMode.endurance:
        return PerformanceResultType.distance;
      case BlockCaptureMode.rounds:
        return PerformanceResultType.rounds;
      case BlockCaptureMode.customMetric:
        return PerformanceResultType.customMetric;
      case BlockCaptureMode.completion:
      case BlockCaptureMode.auto:
        return PerformanceResultType.completion;
    }
  }

  static PerformanceResultData initialResultData(
    BlockCaptureMode mode,
    SessionExecutionBlock block,
  ) {
    switch (mode) {
      case BlockCaptureMode.amrap:
        return const AmrapResultData();
      case BlockCaptureMode.forTime:
        return const ForTimeResultData();
      case BlockCaptureMode.interval:
        return IntervalResultData(
          totalIntervals: block.timerConfiguration?.rounds,
        );
      case BlockCaptureMode.endurance:
        return const DistanceResultData();
      case BlockCaptureMode.rounds:
        return const RoundsResultData();
      case BlockCaptureMode.customMetric:
        return const CustomMetricResultData();
      case BlockCaptureMode.strength:
        return const StrengthResultData();
      case BlockCaptureMode.completion:
      case BlockCaptureMode.auto:
        return const CompletionResultData();
    }
  }

  static bool _isStrengthStyle(SessionBlockType blockType) {
    return blockType == SessionBlockType.strength ||
        blockType == SessionBlockType.accessory ||
        blockType == SessionBlockType.skill;
  }

  static bool _isSimpleCompletionBlock(SessionBlockType blockType) {
    return blockType == SessionBlockType.warmUp ||
        blockType == SessionBlockType.core ||
        blockType == SessionBlockType.coolDown ||
        blockType == SessionBlockType.conditioning;
  }
}
