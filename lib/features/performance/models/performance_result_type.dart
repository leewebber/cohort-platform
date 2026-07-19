enum PerformanceResultType {
  completion,
  strength,
  amrap,
  forTime,
  interval,
  distance,
  duration,
  endurance,
  rounds,
  customMetric,
}

extension PerformanceResultTypeDb on PerformanceResultType {
  String get dbValue {
    switch (this) {
      case PerformanceResultType.completion:
        return 'completion';
      case PerformanceResultType.strength:
        return 'strength';
      case PerformanceResultType.amrap:
        return 'amrap';
      case PerformanceResultType.forTime:
        return 'for_time';
      case PerformanceResultType.interval:
        return 'interval';
      case PerformanceResultType.distance:
        return 'distance';
      case PerformanceResultType.duration:
        return 'duration';
      case PerformanceResultType.endurance:
        return 'endurance';
      case PerformanceResultType.rounds:
        return 'rounds';
      case PerformanceResultType.customMetric:
        return 'custom_metric';
    }
  }

  static PerformanceResultType fromDb(String? value) {
    switch (value?.trim()) {
      case 'strength':
        return PerformanceResultType.strength;
      case 'amrap':
        return PerformanceResultType.amrap;
      case 'for_time':
        return PerformanceResultType.forTime;
      case 'interval':
        return PerformanceResultType.interval;
      case 'distance':
        return PerformanceResultType.distance;
      case 'duration':
        return PerformanceResultType.duration;
      case 'endurance':
        return PerformanceResultType.endurance;
      case 'rounds':
        return PerformanceResultType.rounds;
      case 'custom_metric':
        return PerformanceResultType.customMetric;
      case 'completion':
      default:
        return PerformanceResultType.completion;
    }
  }
}

enum BlockCaptureMode {
  auto,
  strength,
  amrap,
  forTime,
  interval,
  endurance,
  rounds,
  completion,
  customMetric,
}

extension BlockCaptureModeDb on BlockCaptureMode {
  String get dbValue {
    switch (this) {
      case BlockCaptureMode.auto:
        return 'auto';
      case BlockCaptureMode.strength:
        return 'strength';
      case BlockCaptureMode.amrap:
        return 'amrap';
      case BlockCaptureMode.forTime:
        return 'for_time';
      case BlockCaptureMode.interval:
        return 'interval';
      case BlockCaptureMode.endurance:
        return 'endurance';
      case BlockCaptureMode.rounds:
        return 'rounds';
      case BlockCaptureMode.completion:
        return 'completion';
      case BlockCaptureMode.customMetric:
        return 'custom_metric';
    }
  }

  static BlockCaptureMode fromDb(String? value) {
    switch (value?.trim()) {
      case 'strength':
        return BlockCaptureMode.strength;
      case 'amrap':
        return BlockCaptureMode.amrap;
      case 'for_time':
        return BlockCaptureMode.forTime;
      case 'interval':
        return BlockCaptureMode.interval;
      case 'endurance':
        return BlockCaptureMode.endurance;
      case 'rounds':
        return BlockCaptureMode.rounds;
      case 'completion':
        return BlockCaptureMode.completion;
      case 'custom_metric':
        return BlockCaptureMode.customMetric;
      case 'auto':
      default:
        return BlockCaptureMode.auto;
    }
  }
}
