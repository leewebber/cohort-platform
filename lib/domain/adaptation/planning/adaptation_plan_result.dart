import '../evaluation/adaptation_evaluation_result.dart';
import '../vocabulary/adaptation_confidence.dart';
import '../vocabulary/adaptation_fidelity.dart';
import '../vocabulary/session_intent.dart';
import 'adaptation_plan_rationale.dart';
import 'adaptation_plan_step.dart';

enum AdaptationPlanStatus {
  noPlanRequired,
  planGenerated,
  partialPlan,
  unableToPlan,
  insufficientInformation,
}

class AdaptationPlanResult {
  const AdaptationPlanResult({
    required this.status,
    required this.sourceSessionId,
    required this.evaluationOutcome,
    required this.primaryIntent,
    required this.expectedFidelity,
    required this.adaptationConfidence,
    required this.steps,
    required this.protectedElements,
    required this.unresolvedConstraints,
    required this.planFindings,
    required this.isApplicable,
    required this.requiresConfirmationLater,
    this.unresolvedDurationDeficitMinutes,
    this.exactDurationFeasibilityConfirmed = false,
  });

  final AdaptationPlanStatus status;
  final String sourceSessionId;
  final AdaptationEvaluationOutcome evaluationOutcome;
  final SessionIntent? primaryIntent;
  final AdaptationFidelity expectedFidelity;
  final AdaptationConfidence adaptationConfidence;
  final List<AdaptationPlanStep> steps;
  final List<ProtectedAdaptationElement> protectedElements;
  final List<AdaptationConstraintContextSummary> unresolvedConstraints;
  final List<AdaptationPlanRationaleCode> planFindings;
  final bool isApplicable;
  final bool requiresConfirmationLater;
  final int? unresolvedDurationDeficitMinutes;
  final bool exactDurationFeasibilityConfirmed;
}

/// Lightweight unresolved constraint marker (not a full constraint row).
class AdaptationConstraintContextSummary {
  const AdaptationConstraintContextSummary({
    required this.kind,
    required this.rationaleCode,
    this.detail,
  });

  final String kind;
  final AdaptationPlanRationaleCode rationaleCode;
  final String? detail;
}
