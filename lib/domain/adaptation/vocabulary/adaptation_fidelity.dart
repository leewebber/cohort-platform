/// How well an adaptation preserved session intent.
enum AdaptationFidelity { full, high, moderate, low, compromised }

extension AdaptationFidelityDb on AdaptationFidelity {
  String get dbValue => name;

  static AdaptationFidelity? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final fidelity in AdaptationFidelity.values) {
      if (fidelity.dbValue == normalized) return fidelity;
    }
    return null;
  }
}
