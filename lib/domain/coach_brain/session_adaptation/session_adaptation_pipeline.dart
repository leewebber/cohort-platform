import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';

/// Orchestrates evaluate → plan → apply without altering domain behaviour.
class SessionAdaptationPipeline {
  SessionAdaptationPipeline({
    this.evaluator = const SessionAdaptationReadOnlyEvaluator(),
    SessionAdaptationPlanner? planner,
    this.applier = const AdaptationPlanApplier(),
    KnowledgeGraphReader? knowledge,
  }) : planner = planner ?? SessionAdaptationPlanner(knowledge: knowledge);

  final SessionAdaptationReadOnlyEvaluator evaluator;
  final SessionAdaptationPlanner planner;
  final AdaptationPlanApplier applier;

  SessionAdaptationPipelineRun run({
    required PlannedSessionAdaptationInput plannedSession,
    required AdaptationConstraintContext constraints,
  }) {
    final validatedConstraints = constraints.validated();
    final evaluation = evaluator.evaluate(
      session: plannedSession,
      constraints: validatedConstraints,
    );
    final plan = planner.plan(
      session: plannedSession,
      constraints: constraints,
      evaluation: evaluation,
    );
    final application = applier.apply(
      source: plannedSession,
      plan: plan,
      constraints: constraints,
      evaluation: evaluation,
    );
    return SessionAdaptationPipelineRun(
      evaluation: evaluation,
      plan: plan,
      application: application,
    );
  }
}

class SessionAdaptationPipelineRun {
  const SessionAdaptationPipelineRun({
    required this.evaluation,
    required this.plan,
    required this.application,
  });

  final SessionAdaptationEvaluationResult evaluation;
  final AdaptationPlanResult plan;
  final AdaptationPlanApplicationResult application;
}
