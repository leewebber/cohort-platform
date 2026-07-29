import 'package:cohort_platform/planning/models/planning_input.dart';
import 'package:cohort_platform/planning/models/planning_recommendation.dart';

/// Read-only planning merge (ADR-023); no sessions, exercises, or persistence.
abstract interface class PlanningEngineReader {
  PlanningRecommendation createRecommendation(PlanningInput input);
}
