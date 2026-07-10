/// Similarity output from [ProtocolSimilarityService].
class ProtocolSimilarityResult {
  const ProtocolSimilarityResult({
    required this.sourceProtocolId,
    required this.candidateProtocolId,
    required this.score,
    required this.reasons,
  });

  final String sourceProtocolId;
  final String candidateProtocolId;

  /// Overall similarity on a 0–100 scale.
  final double score;

  /// Human-readable reasons for strong matches.
  final List<String> reasons;

  @override
  String toString() {
    return 'ProtocolSimilarityResult('
        'sourceProtocolId: $sourceProtocolId, '
        'candidateProtocolId: $candidateProtocolId, '
        'score: $score, '
        'reasons: $reasons'
        ')';
  }
}
