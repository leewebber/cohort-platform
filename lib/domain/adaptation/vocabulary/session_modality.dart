/// How a session is primarily expressed (format / modality family).
enum SessionModality {
  strength,
  hypertrophy,
  running,
  intervals,
  conditioning,
  hybrid,
  mobility,
  recovery,
  skill,
  benchmark,
  custom,
}

extension SessionModalityDb on SessionModality {
  String get dbValue => name;

  static SessionModality? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final modality in SessionModality.values) {
      if (modality.dbValue == normalized) return modality;
    }
    return null;
  }
}
