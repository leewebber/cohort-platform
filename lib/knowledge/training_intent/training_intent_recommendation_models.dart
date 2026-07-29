/// Ranked training intent suggestion derived from a capability gap (no exercises).
class TrainingIntentRecommendation {
  const TrainingIntentRecommendation({
    required this.trainingIntentId,
    required this.trainingIntentLabel,
    required this.capabilityId,
    required this.capabilityLabel,
    required this.priorityScore,
    required this.suitability,
    required this.progressionStage,
    required this.rationale,
    this.mappingId,
    this.commonSessionArchetypeIds = const [],
  });

  final String trainingIntentId;
  final String trainingIntentLabel;
  final String capabilityId;
  final String capabilityLabel;
  final double priorityScore;
  final double suitability;
  final String progressionStage;
  final String rationale;
  final String? mappingId;
  final List<String> commonSessionArchetypeIds;
}
