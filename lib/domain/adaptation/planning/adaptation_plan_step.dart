import '../evaluation/adaptation_evaluation_result.dart';
import '../vocabulary/adaptation_action_type.dart';
import '../vocabulary/adaptation_constraint_scope.dart';
import '../vocabulary/adaptation_fidelity.dart';
import 'adaptation_plan_rationale.dart';
import 'prescription_reduction_proposal.dart';

class AdaptationPlanStep {
  const AdaptationPlanStep({
    required this.sequence,
    required this.actionType,
    required this.targetScope,
    required this.targetId,
    required this.rationaleCode,
    required this.requiredStep,
    required this.policySource,
    this.blockLocalId,
    this.blockPosition,
    this.exerciseLinkLocalId,
    this.originalValueReference,
    this.proposedValueReference,
    this.expectedTimeSavingMinutes,
    this.expectedTimeSavingUnknown = false,
    this.effectOnFidelity,
    this.prescriptionReduction,
  });

  final int sequence;
  final AdaptationActionType actionType;
  final AdaptationConstraintScope targetScope;
  final String targetId;
  final String? blockLocalId;
  final int? blockPosition;
  final String? exerciseLinkLocalId;
  final String? originalValueReference;
  final String? proposedValueReference;
  final AdaptationPlanRationaleCode rationaleCode;
  final int? expectedTimeSavingMinutes;
  final bool expectedTimeSavingUnknown;
  final AdaptationFidelity? effectOnFidelity;
  final bool requiredStep;
  final AdaptationPolicySource policySource;
  final PrescriptionReductionProposal? prescriptionReduction;
}

class ProtectedAdaptationElement {
  const ProtectedAdaptationElement({
    required this.blockLocalId,
    required this.rationaleCode,
    this.blockPosition,
  });

  final String blockLocalId;
  final int? blockPosition;
  final AdaptationPlanRationaleCode rationaleCode;
}
