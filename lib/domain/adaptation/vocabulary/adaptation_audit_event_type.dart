/// Canonical audit outcomes for programme-backed adaptations (persisted).
///
/// Maps 1:1 to legacy [ProgrammeAdaptationType] until a unified rename migration.
enum AdaptationAuditEventType {
  loadProgression,
  protocolSubstitution,
}

extension AdaptationAuditEventTypeDb on AdaptationAuditEventType {
  String get dbValue {
    return switch (this) {
      AdaptationAuditEventType.loadProgression => 'load_progression',
      AdaptationAuditEventType.protocolSubstitution => 'protocol_substitution',
    };
  }

  static AdaptationAuditEventType? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final type in AdaptationAuditEventType.values) {
      if (type.dbValue == normalized) return type;
    }
    return null;
  }
}
