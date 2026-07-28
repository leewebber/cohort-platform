enum TrainingSessionRecordLifecycleStatus {
  recording,
  completed,
  abandoned,
}

extension TrainingSessionRecordLifecycleStatusX
    on TrainingSessionRecordLifecycleStatus {
  bool get isTerminal {
    return switch (this) {
      TrainingSessionRecordLifecycleStatus.completed ||
      TrainingSessionRecordLifecycleStatus.abandoned =>
        true,
      _ => false,
    };
  }

  bool get allowsExerciseUpdates {
    return this == TrainingSessionRecordLifecycleStatus.recording;
  }
}
