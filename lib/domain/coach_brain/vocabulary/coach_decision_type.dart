/// Canonical coaching decision categories routed by [CoachDecisionRouter].
enum CoachDecisionType {
  sessionAdaptation,
  exerciseSubstitution,
  prescriptionScaling,
  rescheduling,
  extraTraining,
}

extension CoachDecisionTypeDb on CoachDecisionType {
  String get dbValue {
    return switch (this) {
      CoachDecisionType.sessionAdaptation => 'session_adaptation',
      CoachDecisionType.exerciseSubstitution => 'exercise_substitution',
      CoachDecisionType.prescriptionScaling => 'prescription_scaling',
      CoachDecisionType.rescheduling => 'rescheduling',
      CoachDecisionType.extraTraining => 'extra_training',
    };
  }

  static CoachDecisionType? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final type in CoachDecisionType.values) {
      if (type.dbValue == normalized) return type;
    }
    return null;
  }
}
