import 'package:cohort_platform/knowledge/gap_analysis/capability_evidence_models.dart';
import 'package:cohort_platform/knowledge/training_intent/training_intent_recommendation_models.dart';

/// Maps ranked capability gaps to training intents (no programme generation).
abstract interface class TrainingIntentResolutionReader {
  List<TrainingIntentRecommendation> resolveIntentsForGaps({
    required List<CapabilityGap> rankedGaps,
    int maxRecommendationsPerGap,
  });
}
