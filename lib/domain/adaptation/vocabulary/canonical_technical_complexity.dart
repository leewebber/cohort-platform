/// Canonical technical complexity (replaces free-text protocol/exercise labels).
enum CanonicalTechnicalComplexity { beginner, intermediate, advanced }

extension CanonicalTechnicalComplexityDb on CanonicalTechnicalComplexity {
  String get dbValue => name;

  static CanonicalTechnicalComplexity? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final level in CanonicalTechnicalComplexity.values) {
      if (level.dbValue == normalized) return level;
    }
    return null;
  }

  /// Maps legacy [ProtocolMetadataVocabulary.technicalComplexities] strings.
  static CanonicalTechnicalComplexity? fromLegacyLabel(String? label) {
    if (label == null || label.trim().isEmpty) return null;
    return fromDb(label.trim().toLowerCase());
  }
}
