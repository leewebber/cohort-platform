import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';

/// Orchestrates evaluate → plan → apply without altering domain behaviour.
class SessionAdaptationPipeline {
  const SessionAdaptationPipeline({
    this.evaluator = const SessionAdaptationReadOnlyEvaluator(),
    this.planner = const SessionAdaptationPlanner(),
    this.applier = const AdaptationPlanApplier(),
  });

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
