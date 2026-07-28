/// Deterministic session-adaptation failures surfaced by Coach Brain.
enum SessionAdaptationCoachDecisionFailureCode {
  missingContext,
  wrongDecisionType,
  unableToPlan,
  planNotApplicable,
  rejectedInvalidPlan,
  rejectedSourceMismatch,
  applicationFailed,
  unsupportedPlanStep,
}
