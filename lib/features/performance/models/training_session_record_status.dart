enum TrainingSessionRecordStatus {
  inProgress,
  completed,
  partiallyCompleted,
  abandoned,
}

extension TrainingSessionRecordStatusDb on TrainingSessionRecordStatus {
  String get dbValue {
    switch (this) {
      case TrainingSessionRecordStatus.inProgress:
        return 'in_progress';
      case TrainingSessionRecordStatus.completed:
        return 'completed';
      case TrainingSessionRecordStatus.partiallyCompleted:
        return 'partially_completed';
      case TrainingSessionRecordStatus.abandoned:
        return 'abandoned';
    }
  }

  static TrainingSessionRecordStatus fromDb(String? value) {
    switch (value?.trim()) {
      case 'completed':
        return TrainingSessionRecordStatus.completed;
      case 'partially_completed':
        return TrainingSessionRecordStatus.partiallyCompleted;
      case 'abandoned':
        return TrainingSessionRecordStatus.abandoned;
      case 'in_progress':
      default:
        return TrainingSessionRecordStatus.inProgress;
    }
  }

  String get displayLabel {
    switch (this) {
      case TrainingSessionRecordStatus.inProgress:
        return 'In progress';
      case TrainingSessionRecordStatus.completed:
        return 'Completed';
      case TrainingSessionRecordStatus.partiallyCompleted:
        return 'Partially completed';
      case TrainingSessionRecordStatus.abandoned:
        return 'Abandoned';
    }
  }

  bool get isTerminal =>
      this != TrainingSessionRecordStatus.inProgress;
}
