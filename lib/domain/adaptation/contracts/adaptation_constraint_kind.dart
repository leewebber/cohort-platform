/// Domain constraint kinds (superset of athlete [AdaptationReason]).
enum AdaptationConstraintKind {
  recovery,
  environment,
  equipment,
  time,
  programmePolicy,
  painOrDiscomfort,
  unknown,
}

extension AdaptationConstraintKindDb on AdaptationConstraintKind {
  String get dbValue {
    return switch (this) {
      AdaptationConstraintKind.recovery => 'recovery',
      AdaptationConstraintKind.environment => 'environment',
      AdaptationConstraintKind.equipment => 'equipment',
      AdaptationConstraintKind.time => 'time',
      AdaptationConstraintKind.programmePolicy => 'programme_policy',
      AdaptationConstraintKind.painOrDiscomfort => 'pain_or_discomfort',
      AdaptationConstraintKind.unknown => 'unknown',
    };
  }

  static AdaptationConstraintKind fromDb(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AdaptationConstraintKind.unknown;
    }
    final normalized = value.trim().toLowerCase();
    for (final kind in AdaptationConstraintKind.values) {
      if (kind.dbValue == normalized) return kind;
    }
    return AdaptationConstraintKind.unknown;
  }
}
