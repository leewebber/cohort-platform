enum SessionOccurrenceLifecycleState {
  scheduled,
  adapted,
  inProgress,
  completed,
  skipped,
  cancelled,
}

extension SessionOccurrenceLifecycleStateX on SessionOccurrenceLifecycleState {
  bool get isTerminal {
    return switch (this) {
      SessionOccurrenceLifecycleState.completed ||
      SessionOccurrenceLifecycleState.skipped ||
      SessionOccurrenceLifecycleState.cancelled => true,
      _ => false,
    };
  }

  bool get allowsExecutionSnapshotAttachment {
    return switch (this) {
      SessionOccurrenceLifecycleState.scheduled ||
      SessionOccurrenceLifecycleState.adapted => true,
      _ => false,
    };
  }
}
