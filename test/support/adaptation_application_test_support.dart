import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/models/protocol_draft.dart';

import 'adaptation_planning_test_support.dart';

AdaptationPlanApplicationResult applyTimedSessionPlan({
  required ProtocolDraft draft,
  required AdaptationConstraintContext constraints,
  PlannedSessionAdaptationInput? input,
}) {
  const planner = SessionAdaptationPlanner();
  const applier = AdaptationPlanApplier();
  final session = input ?? timedPlanningInputFromDraft(draft);
  final evaluation = SessionAdaptationReadOnlyEvaluator().evaluate(
    session: session,
    constraints: constraints.validated(),
  );
  final plan = planner.plan(
    session: session,
    constraints: constraints,
    evaluation: evaluation,
  );
  return applier.apply(
    source: session,
    plan: plan,
    constraints: constraints,
    evaluation: evaluation,
  );
}

bool snapshotSemanticallyEqual(
  AdaptedSessionExecutionSnapshot a,
  AdaptedSessionExecutionSnapshot b,
) {
  if (a.sourceProtocolId != b.sourceProtocolId) return false;
  if (a.retainedBlocks.length != b.retainedBlocks.length) return false;
  if (a.omittedBlocks.length != b.omittedBlocks.length) return false;
  if (a.appliedAdaptationAudit.length != b.appliedAdaptationAudit.length) {
    return false;
  }
  for (var i = 0; i < a.retainedBlocks.length; i++) {
    final ba = a.retainedBlocks[i];
    final bb = b.retainedBlocks[i];
    if (ba.sourceBlockLocalId != bb.sourceBlockLocalId) return false;
    if (ba.adapted != bb.adapted) return false;
    if (ba.exercises.length != bb.exercises.length) return false;
    for (var j = 0; j < ba.exercises.length; j++) {
      if (ba.exercises[j].executionPrescription !=
          bb.exercises[j].executionPrescription) {
        return false;
      }
    }
  }
  return true;
}
