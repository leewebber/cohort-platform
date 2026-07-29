import '../../planning/models/planning_recommendation.dart';
import '../../planning/session_blueprint/models/session_blueprint.dart';

/// Generates semantic [SessionBlueprint] from [PlanningRecommendation] (ADR-027).
abstract interface class SessionBlueprintGenerator {
  SessionBlueprint generate(
    PlanningRecommendation recommendation, {
    SessionBlueprintGenerationContext context,
  });
}
