/// How reliable a read-only adaptation evaluation conclusion is.
///
/// Distinct from [AdaptationFidelity], which describes intent preservation
/// of a possible adapted session — not evaluator evidence quality.
///
/// Assigned only by [SessionAdaptationReadOnlyEvaluator] from structured
/// [AdaptationConfidenceFindingCode] signals (see evaluator docs).
enum AdaptationConfidence { high, moderate, low }

extension AdaptationConfidenceDb on AdaptationConfidence {
  String get dbValue => name;

  static AdaptationConfidence? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final level in AdaptationConfidence.values) {
      if (level.dbValue == normalized) return level;
    }
    return null;
  }
}
