import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';
import 'package:cohort_platform/application/ports/training_intent_resolution_reader.dart';
import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';

import 'training_intent_recommendation_models.dart';

/// Default resolver using contextual capability → intent mappings.
class TrainingIntentFromGapsService implements TrainingIntentResolutionReader {
  const TrainingIntentFromGapsService(this._knowledge);

  final KnowledgeGraphReader _knowledge;

  @override
  List<TrainingIntentRecommendation> resolveIntentsForGaps({
    required List<CapabilityGap> rankedGaps,
    int maxRecommendationsPerGap = 2,
  }) {
    if (maxRecommendationsPerGap < 1) {
      throw ArgumentError.value(
        maxRecommendationsPerGap,
        'maxRecommendationsPerGap',
      );
    }

    final recommendations = <TrainingIntentRecommendation>[];
    for (final gap in rankedGaps) {
      final mappings = _knowledge.intentsForCapability(gap.capabilityId);
      if (mappings.isEmpty) continue;

      final selected = mappings.take(maxRecommendationsPerGap);
      for (final mapping in selected) {
        final intent = _knowledge.trainingIntentById(mapping.trainingIntentId);
        if (intent == null) continue;

        final score = gap.priorityScore * mapping.suitability;
        recommendations.add(
          TrainingIntentRecommendation(
            trainingIntentId: intent.id,
            trainingIntentLabel: intent.meta.label,
            capabilityId: gap.capabilityId,
            capabilityLabel: gap.capabilityLabel,
            priorityScore: score,
            suitability: mapping.suitability,
            progressionStage: mapping.progressionStage,
            rationale:
                '${gap.rationale} Suggested intent: ${mapping.rationale}',
            mappingId: mapping.id,
            commonSessionArchetypeIds: intent.commonSessionArchetypeIds,
          ),
        );
      }
    }

    recommendations.sort((a, b) {
      final byScore = b.priorityScore.compareTo(a.priorityScore);
      if (byScore != 0) return byScore;
      return a.trainingIntentId.compareTo(b.trainingIntentId);
    });
    return recommendations;
  }
}
