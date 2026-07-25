/// How strongly a constraint should affect candidate elimination vs ranking.
enum AdaptationConstraintSeverity {
  mild,
  moderate,
  severe,
}

extension AdaptationConstraintSeverityDb on AdaptationConstraintSeverity {
  String get dbValue => name;

  static AdaptationConstraintSeverity? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final severity in AdaptationConstraintSeverity.values) {
      if (severity.dbValue == normalized) return severity;
    }
    return null;
  }
}
