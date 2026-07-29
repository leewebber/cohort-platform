enum WorkoutExecutionRecordLifecycleStatus { recording, completed, abandoned }

extension WorkoutExecutionRecordLifecycleStatusX
    on WorkoutExecutionRecordLifecycleStatus {
  bool get isTerminal {
    return switch (this) {
      WorkoutExecutionRecordLifecycleStatus.completed ||
      WorkoutExecutionRecordLifecycleStatus.abandoned => true,
      _ => false,
    };
  }

  bool get allowsExerciseUpdates {
    return this == WorkoutExecutionRecordLifecycleStatus.recording;
  }
}
