import '../../../models/session_block_type.dart';
import '../../../models/workout_format.dart';
import '../../session/models/session_execution_plan.dart';
import 'performance_result_data.dart';
import 'performance_result_type.dart';

class BlockCaptureModeResolver {
  const BlockCaptureModeResolver._();

  static BlockCaptureMode resolveForBlock(SessionExecutionBlock block) {
    return resolve(
      blockType: block.blockType,
      workoutFormat: block.workoutFormat,
      linkedExerciseCount: block.linkedExercises.length,
      content: block.content,
      hasTimer: block.hasTimer,
    );
  }

  static BlockCaptureMode resolve({
    required SessionBlockType blockType,
    required WorkoutFormat workoutFormat,
    required int linkedExerciseCount,
    String content = '',
    bool hasTimer = false,
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

    if (linkedExerciseCount > 0 &&
        _hasStructuredStrengthPrescription(content)) {
      return BlockCaptureMode.strength;
    }

    if (blockType == SessionBlockType.custom &&
        _hasStructuredEndurancePrescription(content)) {
      return BlockCaptureMode.endurance;
    }

    if (_isSimpleCompletionBlock(blockType)) {
      return BlockCaptureMode.completion;
    }

    if (blockType == SessionBlockType.custom &&
        linkedExerciseCount == 0 &&
        (hasTimer || _hasStructuredEndurancePrescription(content))) {
      return BlockCaptureMode.endurance;
    }

    return BlockCaptureMode.completion;
  }

  /// Legacy converter emits these labels from structured step metadata.
  static bool _hasStructuredStrengthPrescription(String content) {
    return _hasStructuredLabel(content, 'Sets') ||
        _hasStructuredLabel(content, 'Reps') ||
        _hasStructuredLabel(content, 'Load');
  }

  static bool _hasStructuredEndurancePrescription(String content) {
    return _hasStructuredLabel(content, 'Duration') ||
        _hasStructuredLabel(content, 'Distance');
  }

  static bool _hasStructuredLabel(String content, String label) {
    return RegExp('^$label:\\s*\\S', multiLine: true).hasMatch(content.trim());
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
