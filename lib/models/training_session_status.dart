enum TrainingSessionStatus {
  planned,
  inProgress,
  completed,
  skipped,
  cancelled,
}

extension TrainingSessionStatusDb on TrainingSessionStatus {
  String get dbValue {
    switch (this) {
      case TrainingSessionStatus.planned:
        return 'planned';
      case TrainingSessionStatus.inProgress:
        return 'in_progress';
      case TrainingSessionStatus.completed:
        return 'completed';
      case TrainingSessionStatus.skipped:
        return 'skipped';
      case TrainingSessionStatus.cancelled:
        return 'cancelled';
    }
  }

  static TrainingSessionStatus fromDb(String? value) {
    switch (value?.trim()) {
      case 'in_progress':
        return TrainingSessionStatus.inProgress;
      case 'completed':
        return TrainingSessionStatus.completed;
      case 'skipped':
        return TrainingSessionStatus.skipped;
      case 'cancelled':
        return TrainingSessionStatus.cancelled;
      case 'planned':
      default:
        return TrainingSessionStatus.planned;
    }
  }
}
