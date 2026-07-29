import '../../../features/session/models/session_execution_plan.dart';
import '../../exercise_policy/models/exercise_policy_models.dart';
import '../../models/planning_input.dart';
import '../../models/planning_recommendation.dart';
import '../../prescription/models/prescription_models.dart';
import '../../session_blueprint/models/session_blueprint.dart';
import 'planning_stage_models.dart';

/// Immutable snapshot after each orchestration step (ADR-024).
class PlanningContext {
  const PlanningContext({
    required this.orchestrationId,
    required this.startedAt,
    required this.completedAt,
    required this.orchestrationStatus,
    required this.input,
    this.recommendation,
    this.sessionBlueprint,
    this.exercisePolicyResult,
    this.prescriptionResult,
    this.sessionExecutionPlan,
    this.stages = const [],
    this.diagnostics = const PipelineDiagnostics(
      outcome: PipelineOutcome.inProgress,
    ),
    this.warnings = const [],
    this.aggregatedExplainability = const AggregatedOrchestrationExplainability.empty(),
    this.resumeFromStage,
  });

  final String orchestrationId;
  final DateTime startedAt;
  final DateTime completedAt;
  final OrchestrationStatus orchestrationStatus;
  final PlanningInput input;
  final PlanningRecommendation? recommendation;
  final SessionBlueprint? sessionBlueprint;
  final ExercisePolicyResult? exercisePolicyResult;
  final PrescriptionResult? prescriptionResult;
  final SessionExecutionPlan? sessionExecutionPlan;
  final List<PlanningStageResult> stages;
  final PipelineDiagnostics diagnostics;
  final List<String> warnings;
  final AggregatedOrchestrationExplainability aggregatedExplainability;
  final PlanningStageId? resumeFromStage;

  String get athleteId => input.athleteId;
  String? get goalId => input.goalContext.goalId;
  String? get primaryTrainingIntentId =>
      prescriptionResult?.primaryTrainingIntentId ??
      exercisePolicyResult?.primaryTrainingIntentId ??
      sessionBlueprint?.primaryTrainingIntentId ??
      recommendation?.trainingIntentRecommendations.firstOrNull?.trainingIntentId;

  String? get sessionArchetypeId =>
      sessionExecutionPlan?.programmeContextLabel ??
      prescriptionResult?.sessionArchetypeId ??
      exercisePolicyResult?.sessionArchetypeId ??
      sessionBlueprint?.sessionArchetype.archetypeId ??
      recommendation?.recommendedSessionArchetype?.archetypeId;

  PlanningContext withStage({
    required PlanningStageResult stage,
    required DateTime completedAt,
    PlanningRecommendation? recommendation,
    SessionBlueprint? sessionBlueprint,
    ExercisePolicyResult? exercisePolicyResult,
    PrescriptionResult? prescriptionResult,
    SessionExecutionPlan? sessionExecutionPlan,
    required OrchestrationStatus orchestrationStatus,
    required PipelineDiagnostics diagnostics,
    required AggregatedOrchestrationExplainability aggregatedExplainability,
    List<String> warnings = const [],
    PlanningStageId? resumeFromStage,
  }) {
    return PlanningContext(
      orchestrationId: orchestrationId,
      startedAt: startedAt,
      completedAt: completedAt,
      orchestrationStatus: orchestrationStatus,
      input: input,
      recommendation: recommendation ?? this.recommendation,
      sessionBlueprint: sessionBlueprint ?? this.sessionBlueprint,
      exercisePolicyResult: exercisePolicyResult ?? this.exercisePolicyResult,
      prescriptionResult: prescriptionResult ?? this.prescriptionResult,
      sessionExecutionPlan: sessionExecutionPlan ?? this.sessionExecutionPlan,
      stages: [...stages, stage],
      diagnostics: diagnostics,
      warnings: [...this.warnings, ...warnings],
      aggregatedExplainability: aggregatedExplainability,
      resumeFromStage: resumeFromStage ?? this.resumeFromStage,
    );
  }

  static PlanningContext initial({
    required String orchestrationId,
    required PlanningInput input,
    required DateTime startedAt,
  }) {
    return PlanningContext(
      orchestrationId: orchestrationId,
      startedAt: startedAt,
      completedAt: startedAt,
      orchestrationStatus: OrchestrationStatus.inProgress,
      input: input,
      diagnostics: PipelineDiagnostics(
        outcome: PipelineOutcome.inProgress,
        stageTimings: const [],
      ),
    );
  }
}

enum OrchestrationStatus {
  inProgress,
  complete,
  partial,
  failed,
  invalidInput,
}

enum PipelineOutcome {
  inProgress,
  success,
  partialSuccess,
  failed,
  invalidInput,
}

class PipelineDiagnostics {
  const PipelineDiagnostics({
    required this.outcome,
    this.stageTimings = const [],
    this.failedStageId,
    this.validationMessages = const [],
  });

  final PipelineOutcome outcome;
  final List<PlanningStageTiming> stageTimings;
  final PlanningStageId? failedStageId;
  final List<String> validationMessages;

  PipelineDiagnostics copyWith({
    PipelineOutcome? outcome,
    List<PlanningStageTiming>? stageTimings,
    PlanningStageId? failedStageId,
    List<String>? validationMessages,
  }) {
    return PipelineDiagnostics(
      outcome: outcome ?? this.outcome,
      stageTimings: stageTimings ?? this.stageTimings,
      failedStageId: failedStageId ?? this.failedStageId,
      validationMessages: validationMessages ?? this.validationMessages,
    );
  }
}

/// Provenance-preserving explainability from each engine (not rewritten).
class AggregatedOrchestrationExplainability {
  const AggregatedOrchestrationExplainability({
    this.planning,
    this.blueprint,
    this.exercisePolicy,
    this.prescription,
    this.sectionOrder = const [],
    this.combinedNarrative = '',
  });

  const AggregatedOrchestrationExplainability.empty()
    : planning = null,
      blueprint = null,
      exercisePolicy = null,
      prescription = null,
      sectionOrder = const [],
      combinedNarrative = '';

  final PlanningExplainability? planning;
  final SessionBlueprintExplainability? blueprint;
  final PolicyExplainability? exercisePolicy;
  final PrescriptionExplainability? prescription;
  final List<PlanningStageId> sectionOrder;
  final String combinedNarrative;

  AggregatedOrchestrationExplainability merge({
    PlanningExplainability? planning,
    SessionBlueprintExplainability? blueprint,
    PolicyExplainability? exercisePolicy,
    PrescriptionExplainability? prescription,
    PlanningStageId? appendSection,
  }) {
    final order = [...sectionOrder];
    if (appendSection != null && !order.contains(appendSection)) {
      order.add(appendSection);
    }
    final narratives = <String>[
      planning?.narrativeSummary ?? this.planning?.narrativeSummary ?? '',
      blueprint?.narrativeSummary ?? this.blueprint?.narrativeSummary ?? '',
      exercisePolicy?.narrativeSummary ??
          this.exercisePolicy?.narrativeSummary ??
          '',
      prescription?.narrativeSummary ??
          this.prescription?.narrativeSummary ??
          '',
    ].where((n) => n.trim().isNotEmpty).toList();

    return AggregatedOrchestrationExplainability(
      planning: planning ?? this.planning,
      blueprint: blueprint ?? this.blueprint,
      exercisePolicy: exercisePolicy ?? this.exercisePolicy,
      prescription: prescription ?? this.prescription,
      sectionOrder: order,
      combinedNarrative: narratives.join(' '),
    );
  }
}

extension _FirstOrNullPlanningIntent on List<PlanningIntentPriority> {
  PlanningIntentPriority? get firstOrNull =>
      isEmpty ? null : first;
}
