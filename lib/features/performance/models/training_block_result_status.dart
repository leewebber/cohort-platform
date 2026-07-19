enum TrainingBlockResultStatus {
  notStarted,
  inProgress,
  completed,
  skipped,
}

extension TrainingBlockResultStatusDb on TrainingBlockResultStatus {
  String get dbValue {
    switch (this) {
      case TrainingBlockResultStatus.notStarted:
        return 'not_started';
      case TrainingBlockResultStatus.inProgress:
        return 'in_progress';
      case TrainingBlockResultStatus.completed:
        return 'completed';
      case TrainingBlockResultStatus.skipped:
        return 'skipped';
    }
  }

  static TrainingBlockResultStatus fromDb(String? value) {
    switch (value?.trim()) {
      case 'in_progress':
        return TrainingBlockResultStatus.inProgress;
      case 'completed':
        return TrainingBlockResultStatus.completed;
      case 'skipped':
        return TrainingBlockResultStatus.skipped;
      case 'not_started':
      default:
        return TrainingBlockResultStatus.notStarted;
    }
  }

  String get displayLabel {
    switch (this) {
      case TrainingBlockResultStatus.notStarted:
        return 'Not started';
      case TrainingBlockResultStatus.inProgress:
        return 'In progress';
      case TrainingBlockResultStatus.completed:
        return 'Completed';
      case TrainingBlockResultStatus.skipped:
        return 'Skipped';
    }
  }
}
