import 'session_block_type.dart';
import 'workout_format.dart';

/// Coach-configurable performance capture mode persisted on [SessionBlock].
enum BlockPerformanceCaptureMode {
  automatic,
  completion,
  strength,
  endurance,
  amrap,
  forTime,
  intervals,
  rounds,
  customMetric,
}

extension BlockPerformanceCaptureModeDb on BlockPerformanceCaptureMode {
  String get dbValue {
    switch (this) {
      case BlockPerformanceCaptureMode.automatic:
        return 'auto';
      case BlockPerformanceCaptureMode.completion:
        return 'completion';
      case BlockPerformanceCaptureMode.strength:
        return 'strength';
      case BlockPerformanceCaptureMode.endurance:
        return 'endurance';
      case BlockPerformanceCaptureMode.amrap:
        return 'amrap';
      case BlockPerformanceCaptureMode.forTime:
        return 'for_time';
      case BlockPerformanceCaptureMode.intervals:
        return 'interval';
      case BlockPerformanceCaptureMode.rounds:
        return 'rounds';
      case BlockPerformanceCaptureMode.customMetric:
        return 'custom_metric';
    }
  }

  String get coachLabel {
    switch (this) {
      case BlockPerformanceCaptureMode.automatic:
        return 'Automatic';
      case BlockPerformanceCaptureMode.completion:
        return 'Completion';
      case BlockPerformanceCaptureMode.strength:
        return 'Strength';
      case BlockPerformanceCaptureMode.endurance:
        return 'Endurance';
      case BlockPerformanceCaptureMode.amrap:
        return 'AMRAP';
      case BlockPerformanceCaptureMode.forTime:
        return 'For Time';
      case BlockPerformanceCaptureMode.intervals:
        return 'Intervals';
      case BlockPerformanceCaptureMode.rounds:
        return 'Rounds';
      case BlockPerformanceCaptureMode.customMetric:
        return 'Custom metric';
    }
  }

  static BlockPerformanceCaptureMode fromDb(String? value) {
    switch (value?.trim()) {
      case 'completion':
        return BlockPerformanceCaptureMode.completion;
      case 'strength':
        return BlockPerformanceCaptureMode.strength;
      case 'endurance':
        return BlockPerformanceCaptureMode.endurance;
      case 'amrap':
        return BlockPerformanceCaptureMode.amrap;
      case 'for_time':
        return BlockPerformanceCaptureMode.forTime;
      case 'interval':
        return BlockPerformanceCaptureMode.intervals;
      case 'rounds':
        return BlockPerformanceCaptureMode.rounds;
      case 'custom_metric':
        return BlockPerformanceCaptureMode.customMetric;
      case 'auto':
      default:
        return BlockPerformanceCaptureMode.automatic;
    }
  }

  static BlockPerformanceCaptureMode resolveDefault({
    required SessionBlockType blockType,
    required WorkoutFormat workoutFormat,
  }) {
    switch (workoutFormat) {
      case WorkoutFormat.amrap:
        return BlockPerformanceCaptureMode.amrap;
      case WorkoutFormat.forTime:
        return BlockPerformanceCaptureMode.forTime;
      case WorkoutFormat.intervals:
      case WorkoutFormat.tabata:
      case WorkoutFormat.emom:
        return BlockPerformanceCaptureMode.intervals;
      case WorkoutFormat.rounds:
        return BlockPerformanceCaptureMode.rounds;
      case WorkoutFormat.none:
      case WorkoutFormat.other:
        break;
    }

    return switch (blockType) {
      SessionBlockType.strength ||
      SessionBlockType.accessory =>
        BlockPerformanceCaptureMode.strength,
      SessionBlockType.warmUp ||
      SessionBlockType.core ||
      SessionBlockType.coolDown =>
        BlockPerformanceCaptureMode.completion,
      SessionBlockType.conditioning => BlockPerformanceCaptureMode.completion,
      SessionBlockType.skill => BlockPerformanceCaptureMode.completion,
      SessionBlockType.custom => BlockPerformanceCaptureMode.automatic,
    };
  }
}
