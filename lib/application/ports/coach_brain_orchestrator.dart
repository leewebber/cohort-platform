import '../../planning/orchestration/models/coach_brain_orchestration_request.dart';
import '../../planning/orchestration/models/planning_context.dart';

/// Coach Brain planning orchestration port (ADR-024).
abstract interface class CoachBrainOrchestrator {
  PlanningContext run(CoachBrainOrchestrationRequest request);
}
