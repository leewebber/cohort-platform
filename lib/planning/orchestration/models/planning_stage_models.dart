enum PlanningStageId {
  planningEngine,
  sessionBlueprint,
  exercisePolicy,
  prescription,
  executionPlanAdapter,
}

enum PlanningStageStatus {
  pending,
  succeeded,
  partial,
  failed,
  skipped,
}

class PlanningStageTiming {
  const PlanningStageTiming({
    required this.stageId,
    required this.startedAt,
    required this.completedAt,
  });

  final PlanningStageId stageId;
  final DateTime startedAt;
  final DateTime completedAt;

  Duration get duration => completedAt.difference(startedAt);
}

class PlanningStageResult {
  const PlanningStageResult({
    required this.stageId,
    required this.status,
    required this.startedAt,
    required this.completedAt,
    this.warnings = const [],
    this.errors = const [],
  });

  final PlanningStageId stageId;
  final PlanningStageStatus status;
  final DateTime startedAt;
  final DateTime completedAt;
  final List<String> warnings;
  final List<String> errors;

  PlanningStageTiming get timing => PlanningStageTiming(
    stageId: stageId,
    startedAt: startedAt,
    completedAt: completedAt,
  );

  bool get isSuccess =>
      status == PlanningStageStatus.succeeded ||
      status == PlanningStageStatus.partial;
}

/// Alias for documentation — stage identity is [PlanningStageId].
typedef PlanningStage = PlanningStageId;
