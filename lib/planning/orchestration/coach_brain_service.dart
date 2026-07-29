import '../../../application/ports/coach_brain_orchestrator.dart';
import '../../../application/ports/exercise_policy_engine.dart';
import '../../../application/ports/planning_engine_reader.dart';
import '../../../application/ports/prescription_engine.dart';
import '../../../application/ports/session_blueprint_generator.dart';
import '../../../features/session/models/session_execution_plan.dart';
import '../models/planning_recommendation.dart';
import '../exercise_policy/models/exercise_policy_models.dart';
import '../prescription/models/prescription_models.dart';
import '../prescription/prescription_execution_plan_adapter.dart';
import '../session_blueprint/models/session_blueprint.dart';
import 'models/coach_brain_orchestration_request.dart';
import 'models/planning_context.dart';
import 'models/planning_stage_models.dart';
import 'planning_context_validator.dart';

/// Orchestrates planning pipeline stages (ADR-024). No coaching logic.
class CoachBrainService implements CoachBrainOrchestrator {
  CoachBrainService({
    required PlanningEngineReader planningEngine,
    required SessionBlueprintGenerator blueprintGenerator,
    required ExercisePolicyEngine exercisePolicy,
    required PrescriptionEngine prescriptionEngine,
    PrescriptionExecutionPlanAdapter? executionPlanAdapter,
    PlanningContextValidator? contextValidator,
  }) : _planningEngine = planningEngine,
       _blueprintGenerator = blueprintGenerator,
       _exercisePolicy = exercisePolicy,
       _prescriptionEngine = prescriptionEngine,
       _adapter = executionPlanAdapter ?? const PrescriptionExecutionPlanAdapter(),
       _validator = contextValidator ?? const PlanningContextValidator();

  final PlanningEngineReader _planningEngine;
  final SessionBlueprintGenerator _blueprintGenerator;
  final ExercisePolicyEngine _exercisePolicy;
  final PrescriptionEngine _prescriptionEngine;
  final PrescriptionExecutionPlanAdapter _adapter;
  final PlanningContextValidator _validator;

  PlanningContext run(CoachBrainOrchestrationRequest request) {
    final started = DateTime.now().toUtc();
    final orchId = computeOrchestrationId(request.planningInput);
    var ctx = PlanningContext.initial(
      orchestrationId: orchId,
      input: request.planningInput,
      startedAt: started,
    );

    ctx = _runPlanning(ctx, request);
    if (_shouldStopAfterPlanning(ctx)) {
      return _finalize(ctx, started);
    }

    ctx = _runBlueprint(ctx, request);
    if (_shouldStopAfterBlueprint(ctx)) {
      return _finalize(ctx, started);
    }

    ctx = _runExercisePolicy(ctx, request);
    if (_shouldStopAfterPolicy(ctx)) {
      return _finalize(ctx, started);
    }

    ctx = _runPrescription(ctx);
    if (_shouldStopAfterPrescription(ctx)) {
      return _finalize(ctx, started);
    }

    ctx = _runAdapter(ctx);
    return _finalize(ctx, started);
  }

  PlanningContext _runPlanning(
    PlanningContext ctx,
    CoachBrainOrchestrationRequest request,
  ) {
    final t0 = DateTime.now().toUtc();
    final rec = _planningEngine.createRecommendation(request.planningInput);
    final t1 = DateTime.now().toUtc();

    final status = switch (rec.status) {
      PlanningRecommendationStatus.invalidInput => PlanningStageStatus.failed,
      PlanningRecommendationStatus.infeasible => PlanningStageStatus.failed,
      PlanningRecommendationStatus.insufficientEvidence ||
      PlanningRecommendationStatus.partial =>
        PlanningStageStatus.partial,
      PlanningRecommendationStatus.complete => PlanningStageStatus.succeeded,
    };

    final orchStatus = switch (rec.status) {
      PlanningRecommendationStatus.invalidInput => OrchestrationStatus.invalidInput,
      PlanningRecommendationStatus.infeasible => OrchestrationStatus.failed,
      PlanningRecommendationStatus.partial ||
      PlanningRecommendationStatus.insufficientEvidence =>
        OrchestrationStatus.partial,
      PlanningRecommendationStatus.complete => OrchestrationStatus.inProgress,
    };

    final stage = PlanningStageResult(
      stageId: PlanningStageId.planningEngine,
      status: status,
      startedAt: t0,
      completedAt: t1,
      warnings: rec.warnings.map((w) => w.message).toList(),
      errors: rec.status == PlanningRecommendationStatus.invalidInput
          ? ['Planning input invalid']
          : const [],
    );

    final explain = AggregatedOrchestrationExplainability.empty().merge(
      planning: rec.explainability,
      appendSection: PlanningStageId.planningEngine,
    );

    return ctx.withStage(
      stage: stage,
      completedAt: t1,
      recommendation: rec,
      orchestrationStatus: orchStatus,
      diagnostics: _appendTiming(ctx, stage, _outcomeForStage(status)),
      aggregatedExplainability: explain,
      warnings: rec.warnings.map((w) => w.message).toList(),
      resumeFromStage: _stageOk(status)
          ? PlanningStageId.sessionBlueprint
          : (rec.status == PlanningRecommendationStatus.invalidInput
                ? null
                : PlanningStageId.planningEngine),
    );
  }

  PlanningContext _runBlueprint(
    PlanningContext ctx,
    CoachBrainOrchestrationRequest request,
  ) {
    final rec = ctx.recommendation!;
    final t0 = DateTime.now().toUtc();
    final bp = _blueprintGenerator.generate(
      rec,
      context: request.blueprintContext,
    );
    final t1 = DateTime.now().toUtc();

    final status = switch (bp.status) {
      SessionBlueprintStatus.invalidRecommendation => PlanningStageStatus.failed,
      SessionBlueprintStatus.infeasible => PlanningStageStatus.failed,
      SessionBlueprintStatus.partial => PlanningStageStatus.partial,
      SessionBlueprintStatus.complete => PlanningStageStatus.succeeded,
    };

    final stage = PlanningStageResult(
      stageId: PlanningStageId.sessionBlueprint,
      status: status,
      startedAt: t0,
      completedAt: t1,
      warnings: bp.warnings.map((w) => w.message).toList(),
      errors: status == PlanningStageStatus.failed
          ? ['Session blueprint ${bp.status.name}']
          : const [],
    );

    final explain = ctx.aggregatedExplainability.merge(
      blueprint: bp.explainability,
      appendSection: PlanningStageId.sessionBlueprint,
    );

    return ctx.withStage(
      stage: stage,
      completedAt: t1,
      sessionBlueprint: bp,
      orchestrationStatus: status == PlanningStageStatus.failed
          ? OrchestrationStatus.failed
          : (status == PlanningStageStatus.partial
                ? OrchestrationStatus.partial
                : ctx.orchestrationStatus),
      diagnostics: _appendTiming(ctx, stage, _outcomeForStage(status)),
      aggregatedExplainability: explain,
      resumeFromStage: _stageOk(status)
          ? PlanningStageId.exercisePolicy
          : PlanningStageId.sessionBlueprint,
    );
  }

  PlanningContext _runExercisePolicy(
    PlanningContext ctx,
    CoachBrainOrchestrationRequest request,
  ) {
    final bp = ctx.sessionBlueprint!;
    final t0 = DateTime.now().toUtc();
    final policy = _exercisePolicy.evaluate(
      ExercisePolicyRequest(
        blueprint: bp,
        availableEquipmentIds: request.policyContext.availableEquipmentIds,
        environmentId: request.policyContext.environmentId,
        injuryFlags: request.policyContext.injuryFlags,
        isTraveling: request.policyContext.isTraveling,
      ),
    );
    final t1 = DateTime.now().toUtc();

    final status = switch (policy.status) {
      MovementSelectionStatus.invalidBlueprint => PlanningStageStatus.failed,
      MovementSelectionStatus.infeasible => PlanningStageStatus.failed,
      MovementSelectionStatus.partial => PlanningStageStatus.partial,
      MovementSelectionStatus.complete => PlanningStageStatus.succeeded,
    };

    final stage = PlanningStageResult(
      stageId: PlanningStageId.exercisePolicy,
      status: status,
      startedAt: t0,
      completedAt: t1,
      warnings: policy.warnings,
      errors: status == PlanningStageStatus.failed
          ? ['Exercise policy ${policy.status.name}']
          : const [],
    );

    final explain = ctx.aggregatedExplainability.merge(
      exercisePolicy: policy.explainability,
      appendSection: PlanningStageId.exercisePolicy,
    );

    return ctx.withStage(
      stage: stage,
      completedAt: t1,
      exercisePolicyResult: policy,
      orchestrationStatus: status == PlanningStageStatus.failed
          ? OrchestrationStatus.failed
          : (status == PlanningStageStatus.partial
                ? OrchestrationStatus.partial
                : ctx.orchestrationStatus),
      diagnostics: _appendTiming(ctx, stage, _outcomeForStage(status)),
      aggregatedExplainability: explain,
      resumeFromStage: _stageOk(status)
          ? PlanningStageId.prescription
          : PlanningStageId.exercisePolicy,
    );
  }

  PlanningContext _runPrescription(PlanningContext ctx) {
    final bp = ctx.sessionBlueprint!;
    final plan = ctx.exercisePolicyResult!.executionPlan;
    final t0 = DateTime.now().toUtc();
    final rx = _prescriptionEngine.prescribe(
      PrescriptionRequest(executionPlan: plan, blueprint: bp),
    );
    final t1 = DateTime.now().toUtc();

    final status = switch (rx.status) {
      PrescriptionStatus.invalidInput => PlanningStageStatus.failed,
      PrescriptionStatus.infeasible => PlanningStageStatus.failed,
      PrescriptionStatus.partial => PlanningStageStatus.partial,
      PrescriptionStatus.complete => PlanningStageStatus.succeeded,
    };

    final stage = PlanningStageResult(
      stageId: PlanningStageId.prescription,
      status: status,
      startedAt: t0,
      completedAt: t1,
      warnings: rx.warnings.map((w) => w.message).toList(),
      errors: status == PlanningStageStatus.failed
          ? ['Prescription ${rx.status.name}']
          : const [],
    );

    final explain = ctx.aggregatedExplainability.merge(
      prescription: rx.explainability,
      appendSection: PlanningStageId.prescription,
    );

    return ctx.withStage(
      stage: stage,
      completedAt: t1,
      prescriptionResult: rx,
      orchestrationStatus: status == PlanningStageStatus.failed
          ? OrchestrationStatus.failed
          : (status == PlanningStageStatus.partial
                ? OrchestrationStatus.partial
                : ctx.orchestrationStatus),
      diagnostics: _appendTiming(ctx, stage, _outcomeForStage(status)),
      aggregatedExplainability: explain,
      resumeFromStage: _stageOk(status)
          ? PlanningStageId.executionPlanAdapter
          : PlanningStageId.prescription,
    );
  }

  PlanningContext _runAdapter(PlanningContext ctx) {
    final t0 = DateTime.now().toUtc();
    final m7 = _adapter.toExecutionPlan(
      result: ctx.prescriptionResult!,
      semanticPlan: ctx.exercisePolicyResult!.executionPlan,
    );
    final t1 = DateTime.now().toUtc();

    const status = PlanningStageStatus.succeeded;
    final stage = PlanningStageResult(
      stageId: PlanningStageId.executionPlanAdapter,
      status: status,
      startedAt: t0,
      completedAt: t1,
    );

    final orchStatus = ctx.orchestrationStatus == OrchestrationStatus.partial
        ? OrchestrationStatus.partial
        : OrchestrationStatus.complete;

    return ctx.withStage(
      stage: stage,
      completedAt: t1,
      sessionExecutionPlan: m7,
      orchestrationStatus: orchStatus,
      diagnostics: _appendTiming(
        ctx,
        stage,
        orchStatus == OrchestrationStatus.complete
            ? PipelineOutcome.success
            : PipelineOutcome.partialSuccess,
      ),
      aggregatedExplainability: ctx.aggregatedExplainability,
      resumeFromStage: null,
    );
  }

  bool _shouldStopAfterPlanning(PlanningContext ctx) {
    final rec = ctx.recommendation!;
    return rec.status == PlanningRecommendationStatus.invalidInput ||
        rec.status == PlanningRecommendationStatus.infeasible;
  }

  bool _shouldStopAfterBlueprint(PlanningContext ctx) {
    final bp = ctx.sessionBlueprint!;
    return bp.status == SessionBlueprintStatus.invalidRecommendation ||
        bp.status == SessionBlueprintStatus.infeasible;
  }

  bool _shouldStopAfterPolicy(PlanningContext ctx) {
    final p = ctx.exercisePolicyResult!;
    return p.status == MovementSelectionStatus.invalidBlueprint ||
        p.status == MovementSelectionStatus.infeasible;
  }

  bool _shouldStopAfterPrescription(PlanningContext ctx) {
    final rx = ctx.prescriptionResult!;
    return rx.status == PrescriptionStatus.invalidInput ||
        rx.status == PrescriptionStatus.infeasible;
  }

  PipelineDiagnostics _appendTiming(
    PlanningContext ctx,
    PlanningStageResult stage,
    PipelineOutcome outcome,
  ) {
    return ctx.diagnostics.copyWith(
      outcome: outcome,
      stageTimings: [...ctx.diagnostics.stageTimings, stage.timing],
      failedStageId: stage.status == PlanningStageStatus.failed
          ? stage.stageId
          : ctx.diagnostics.failedStageId,
    );
  }

  PipelineOutcome _outcomeForStage(PlanningStageStatus status) {
    return switch (status) {
      PlanningStageStatus.succeeded => PipelineOutcome.success,
      PlanningStageStatus.partial => PipelineOutcome.partialSuccess,
      PlanningStageStatus.failed => PipelineOutcome.failed,
      _ => PipelineOutcome.inProgress,
    };
  }

  bool _stageOk(PlanningStageStatus status) =>
      status == PlanningStageStatus.succeeded ||
      status == PlanningStageStatus.partial;

  PlanningContext _finalize(PlanningContext ctx, DateTime started) {
    final validation = _validator.validate(ctx);
    var diagnostics = ctx.diagnostics;
    if (!validation.isValid) {
      diagnostics = diagnostics.copyWith(
        validationMessages: validation.messages,
      );
    }
    return PlanningContext(
      orchestrationId: ctx.orchestrationId,
      startedAt: started,
      completedAt: ctx.completedAt,
      orchestrationStatus: ctx.orchestrationStatus,
      input: ctx.input,
      recommendation: ctx.recommendation,
      sessionBlueprint: ctx.sessionBlueprint,
      exercisePolicyResult: ctx.exercisePolicyResult,
      prescriptionResult: ctx.prescriptionResult,
      sessionExecutionPlan: ctx.sessionExecutionPlan,
      stages: ctx.stages,
      diagnostics: diagnostics,
      warnings: ctx.warnings,
      aggregatedExplainability: ctx.aggregatedExplainability,
      resumeFromStage: ctx.resumeFromStage,
    );
  }
}
