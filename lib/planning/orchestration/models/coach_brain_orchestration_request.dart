import '../../models/planning_input.dart';
import '../../session_blueprint/models/session_blueprint.dart';

/// Input to Coach Brain orchestration (planning + policy context only).
class CoachBrainOrchestrationRequest {
  const CoachBrainOrchestrationRequest({
    required this.planningInput,
    this.blueprintContext = const SessionBlueprintGenerationContext(),
    this.availableEquipmentIds = const [],
    this.environmentId,
    this.isTraveling = false,
  });

  final PlanningInput planningInput;
  final SessionBlueprintGenerationContext blueprintContext;
  final List<String> availableEquipmentIds;
  final String? environmentId;
  final bool isTraveling;

  ExercisePolicyContext get policyContext => ExercisePolicyContext(
    availableEquipmentIds: availableEquipmentIds.isNotEmpty
        ? availableEquipmentIds
        : planningInput.equipmentContext?.availableEquipmentIds ?? const [],
    environmentId:
        environmentId ?? planningInput.environmentContext?.environmentId,
    injuryFlags: planningInput.injuryFlags,
    isTraveling: isTraveling || (planningInput.travelContext?.isTraveling ?? false),
  );
}

/// Policy-layer fields forwarded from [PlanningInput] (orchestrator only).
class ExercisePolicyContext {
  const ExercisePolicyContext({
    this.availableEquipmentIds = const [],
    this.environmentId,
    this.injuryFlags = const [],
    this.isTraveling = false,
  });

  final List<String> availableEquipmentIds;
  final String? environmentId;
  final List<String> injuryFlags;
  final bool isTraveling;
}

String computeOrchestrationId(PlanningInput input) {
  final stamp = input.asOf.toUtc().millisecondsSinceEpoch;
  return 'cohort.orchestration.${input.athleteId}.$stamp';
}
