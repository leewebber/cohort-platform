enum WorkoutPlayerExecutionStatus {
  ready,
  active,
  paused,
  completed,
  abandoned,
}

extension WorkoutPlayerExecutionStatusX on WorkoutPlayerExecutionStatus {
  bool get isTerminal {
    return switch (this) {
      WorkoutPlayerExecutionStatus.completed ||
      WorkoutPlayerExecutionStatus.abandoned =>
        true,
      _ => false,
    };
  }

  bool get allowsNavigation {
    return this == WorkoutPlayerExecutionStatus.active;
  }
}
