import '../contracts/block_adaptation_policy.dart';
import '../evaluation/adaptation_constraint_context.dart';
import '../evaluation/adaptation_evaluation_result.dart';
import '../evaluation/planned_session_adaptation_input_factory.dart';
import '../evaluation/session_adaptation_read_only_evaluator.dart';
import '../mapping/session_block_type_adaptation_policy.dart';
import '../vocabulary/adaptation_action_type.dart';
import '../vocabulary/adaptation_confidence.dart';
import '../vocabulary/adaptation_constraint_scope.dart';
import '../vocabulary/adaptation_fidelity.dart';
import '../vocabulary/block_priority.dart';
import 'adaptation_plan_result.dart';
import 'adaptation_plan_rationale.dart';
import 'adaptation_plan_step.dart';
import 'adaptation_plan_validator.dart';
import 'prescription_reduction_proposal.dart';

enum _PrescriptionPass { optionalTier, importantTier, essentialTier }

class ResolvedPlannedBlock {
  const ResolvedPlannedBlock({
    required this.input,
    required this.effectivePriority,
    required this.effectivePolicy,
    required this.policySource,
  });

  final PlannedBlockAdaptationInput input;
  final BlockPriority effectivePriority;
  final BlockAdaptationPolicy effectivePolicy;
  final AdaptationPolicySource policySource;
}

/// Deterministic time-constrained adaptation plan generator (no mutation).
class SessionAdaptationPlanner {
  const SessionAdaptationPlanner({
    this.evaluator = const SessionAdaptationReadOnlyEvaluator(),
    this.validator = const AdaptationPlanValidator(),
  });

  final SessionAdaptationReadOnlyEvaluator evaluator;
  final AdaptationPlanValidator validator;

  AdaptationPlanResult plan({
    required PlannedSessionAdaptationInput session,
    required AdaptationConstraintContext constraints,
    SessionAdaptationEvaluationResult? evaluation,
  }) {
    final validatedConstraints = constraints.validated();
    final resolvedEvaluation = evaluation ??
        evaluator.evaluate(
          session: session,
          constraints: validatedConstraints,
        );

    final base = _PlanBuildContext(
      session: session,
      constraints: validatedConstraints,
      evaluation: resolvedEvaluation,
    );

    if (!validatedConstraints.hasTimeConstraint) {
      return _finalize(base, _noPlanRequired(base));
    }

    final available = validatedConstraints.availableDurationMin!;
    final planned = session.plannedDurationMin;
    if (planned == null) {
      return _finalize(
        base,
        _insufficientInformation(
          base,
          findings: [AdaptationPlanRationaleCode.insufficientDurationMetadata],
        ),
      );
    }

    if (available >= planned) {
      return _finalize(base, _noPlanRequired(base));
    }

    final minViable = session.minimumViableDurationMin;
    if (minViable == null) {
      return _finalize(
        base,
        _planWithMissingMinViableThreshold(base, available: available, planned: planned),
      );
    }

    if (available < minViable) {
      return _finalize(
        base,
        _unableBelowMinimumViable(base, available: available, minViable: minViable),
      );
    }

    if (resolvedEvaluation.outcome == AdaptationEvaluationOutcome.notAdaptable ||
        resolvedEvaluation.outcome == AdaptationEvaluationOutcome.insufficientInformation) {
      if (available < minViable) {
        return _finalize(
          base,
          _unableBelowMinimumViable(base, available: available, minViable: minViable),
        );
      }
    }

    final deficit = planned - available;
    return _finalize(
      base,
      _buildTimeConstrainedPlan(base, deficitMinutes: deficit, available: available),
    );
  }

  static ResolvedPlannedBlock resolveBlock(PlannedBlockAdaptationInput block) {
    final blockType =
        PlannedSessionAdaptationInputFactory.blockTypeFromDb(block.blockTypeDbValue);
    final derivedPriority =
        SessionBlockTypeAdaptationPolicy.defaultPriority(blockType);
    final derivedPolicy =
        SessionBlockTypeAdaptationPolicy.defaultAdaptationPolicy(blockType);
    final explicitPolicy = block.explicitPolicy;
    return ResolvedPlannedBlock(
      input: block,
      effectivePriority: block.explicitPriority ?? derivedPriority,
      effectivePolicy: explicitPolicy ?? derivedPolicy,
      policySource: explicitPolicy != null
          ? AdaptationPolicySource.explicit
          : AdaptationPolicySource.derived,
    );
  }

  AdaptationPlanResult _finalize(
    _PlanBuildContext base,
    _MutablePlan draft,
  ) {
    final validation = validator.validate(
      session: base.session,
      evaluation: base.evaluation,
      plan: draft.toResult(base),
    );
    final result = draft.toResult(
      base,
      forceNotApplicable: !validation.isValid,
    );
    return result;
  }

  _MutablePlan _noPlanRequired(_PlanBuildContext base) {
    final draft = _MutablePlan(
      status: AdaptationPlanStatus.noPlanRequired,
      planFindings: [AdaptationPlanRationaleCode.noAdaptationRequired],
    );
    draft.exactDurationFeasibilityConfirmed = true;
    return draft;
  }

  _MutablePlan _insufficientInformation(
    _PlanBuildContext base, {
    required List<AdaptationPlanRationaleCode> findings,
  }) {
    return _MutablePlan(
      status: AdaptationPlanStatus.insufficientInformation,
      planFindings: findings,
    );
  }

  _MutablePlan _unableBelowMinimumViable(
    _PlanBuildContext base, {
    required int available,
    required int minViable,
  }) {
    final draft = _MutablePlan(
      status: AdaptationPlanStatus.unableToPlan,
      planFindings: [
        AdaptationPlanRationaleCode.belowMinimumViableDuration,
        AdaptationPlanRationaleCode.minimumViableDurationProtected,
        AdaptationPlanRationaleCode.primaryIntentAtRisk,
      ],
    );
    draft.unresolvedDurationDeficitMinutes = minViable - available;
    draft.unresolvedConstraints.add(
      AdaptationConstraintContextSummary(
        kind: 'time',
        rationaleCode: AdaptationPlanRationaleCode.unresolvedDurationDeficit,
        detail: 'available=$available min_viable=$minViable',
      ),
    );
    return draft;
  }

  _MutablePlan _planWithMissingMinViableThreshold(
    _PlanBuildContext base, {
    required int available,
    required int planned,
  }) {
    final deficit = planned - available;
    final draft = _buildTimeConstrainedPlan(
      base,
      deficitMinutes: deficit,
      available: available,
      missingMinViable: true,
    );
    draft.status = AdaptationPlanStatus.partialPlan;
    if (!draft.planFindings.contains(
      AdaptationPlanRationaleCode.insufficientDurationMetadata,
    )) {
      draft.planFindings.add(
        AdaptationPlanRationaleCode.insufficientDurationMetadata,
      );
    }
    return draft;
  }

  _MutablePlan _buildTimeConstrainedPlan(
    _PlanBuildContext base, {
    required int deficitMinutes,
    required int available,
    bool missingMinViable = false,
  }) {
    final draft = _MutablePlan(
      status: AdaptationPlanStatus.planGenerated,
      planFindings: [AdaptationPlanRationaleCode.durationReductionRequired],
      expectedFidelity: AdaptationFidelity.moderate,
    );

    var remaining = deficitMinutes;
    final resolvedBlocks = base.session.blocks.map(resolveBlock).toList()
      ..sort(_interventionSort);

    for (final block in resolvedBlocks) {
      if (block.effectivePriority == BlockPriority.essential) {
        draft.protectedElements.add(
          ProtectedAdaptationElement(
            blockLocalId: block.input.localId,
            blockPosition: block.input.position,
            rationaleCode: AdaptationPlanRationaleCode.essentialBlockProtected,
          ),
        );
      }
    }

    var sequence = 1;
    var exactFeasibility = true;
    final removedBlockIds = <String>{};
    final workingSetsByLink = <String, int>{
      for (final block in resolvedBlocks)
        for (final rx in block.input.exercisePrescriptions)
          if (rx.sets != null) rx.exerciseLinkLocalId: rx.sets!,
    };

    while (remaining > 0) {
      var progress = false;

      for (final pass in _PrescriptionPass.values) {
        if (remaining <= 0) break;
        for (final block in resolvedBlocks) {
          if (remaining <= 0) break;
          if (removedBlockIds.contains(block.input.localId)) continue;
          if (!_matchesPrescriptionPass(block, pass)) continue;
          final saved = _tryPrescriptionReduction(
            draft: draft,
            block: block,
            remaining: remaining,
            sequence: sequence,
            workingSetsByLink: workingSetsByLink,
          );
          if (saved != null) {
            sequence = saved.nextSequence;
            remaining -= saved.minutesSaved ?? remaining;
            progress = true;
            if (!saved.exactSaving) exactFeasibility = false;
            if (remaining <= 0) break;
          }
        }
      }

      if (remaining <= 0) break;

      for (final block in resolvedBlocks) {
        if (remaining <= 0) break;
        if (removedBlockIds.contains(block.input.localId)) continue;
        if (_isEssential(block)) continue;
        if (!block.effectivePolicy.canRemove) {
          draft.planFindings.add(
            AdaptationPlanRationaleCode.removalPreventedByPolicy,
          );
          continue;
        }
        if (!_isOptionalTier(block)) continue;
        final removal = _tryRemoveBlock(
          draft: draft,
          block: block,
          sequence: sequence,
        );
        if (removal != null) {
          removedBlockIds.add(block.input.localId);
          sequence = removal.nextSequence;
          if (removal.minutesSaved != null) {
            remaining -= removal.minutesSaved!;
          } else {
            exactFeasibility = false;
          }
          progress = true;
          if (remaining <= 0) break;
        }
      }

      if (remaining <= 0) break;

      for (final block in resolvedBlocks) {
        if (remaining <= 0) break;
        if (removedBlockIds.contains(block.input.localId)) continue;
        if (_isEssential(block)) continue;
        if (!block.effectivePolicy.canRemove) {
          draft.planFindings.add(
            AdaptationPlanRationaleCode.removalPreventedByPolicy,
          );
          continue;
        }
        if (_isOptionalTier(block)) continue;
        final removal = _tryRemoveBlock(
          draft: draft,
          block: block,
          sequence: sequence,
          rationale: AdaptationPlanRationaleCode.importantBlockReductionRequired,
        );
        if (removal != null) {
          removedBlockIds.add(block.input.localId);
          sequence = removal.nextSequence;
          if (removal.minutesSaved != null) {
            remaining -= removal.minutesSaved!;
          } else {
            exactFeasibility = false;
          }
          progress = true;
        }
      }

      if (remaining <= 0) break;

      if (!progress) break;
    }

    if (remaining > 0) {
      draft.status = AdaptationPlanStatus.partialPlan;
      draft.unresolvedDurationDeficitMinutes = remaining;
      draft.planFindings.add(AdaptationPlanRationaleCode.unresolvedDurationDeficit);
      exactFeasibility = false;
    } else if (!exactFeasibility) {
      draft.status = AdaptationPlanStatus.partialPlan;
      draft.planFindings.add(
        AdaptationPlanRationaleCode.exactDurationCannotBeConfirmed,
      );
    }

    draft.exactDurationFeasibilityConfirmed =
        exactFeasibility &&
            remaining <= 0 &&
            !draft.steps.any((step) => step.expectedTimeSavingUnknown);
    draft.requiresConfirmationLater = draft.steps.isNotEmpty;

    if (draft.steps.isEmpty && remaining > 0) {
      draft.status = AdaptationPlanStatus.unableToPlan;
      draft.planFindings.add(AdaptationPlanRationaleCode.unresolvedDurationDeficit);
    }

    if (base.evaluation.primaryIntentPreservable) {
      draft.planFindings.add(AdaptationPlanRationaleCode.primaryIntentPreserved);
    } else {
      draft.planFindings.add(AdaptationPlanRationaleCode.primaryIntentAtRisk);
    }

    if (missingMinViable) {
      draft.adaptationConfidence = AdaptationConfidence.low;
    }

    return draft;
  }

  bool _isEssential(ResolvedPlannedBlock block) =>
      block.effectivePriority == BlockPriority.essential;

  bool _isOptionalTier(ResolvedPlannedBlock block) {
    return switch (block.effectivePriority) {
      BlockPriority.optional || BlockPriority.disposable => true,
      _ => false,
    };
  }

  int _interventionSort(ResolvedPlannedBlock a, ResolvedPlannedBlock b) {
    final tier = _tierRank(a.effectivePriority).compareTo(_tierRank(b.effectivePriority));
    if (tier != 0) return tier;
    return b.input.position.compareTo(a.input.position);
  }

  int _tierRank(BlockPriority priority) {
    return switch (priority) {
      BlockPriority.disposable => 0,
      BlockPriority.optional => 1,
      BlockPriority.secondary => 2,
      BlockPriority.primary => 3,
      BlockPriority.essential => 4,
    };
  }

  bool _matchesPrescriptionPass(
    ResolvedPlannedBlock block,
    _PrescriptionPass pass,
  ) {
    return switch (pass) {
      _PrescriptionPass.optionalTier => _isOptionalTier(block),
      _PrescriptionPass.importantTier =>
        !_isOptionalTier(block) && !_isEssential(block),
      _PrescriptionPass.essentialTier => _isEssential(block),
    };
  }

  _StepProgress? _tryPrescriptionReduction({
    required _MutablePlan draft,
    required ResolvedPlannedBlock block,
    required int remaining,
    required int sequence,
    required Map<String, int> workingSetsByLink,
  }) {
    if (!block.effectivePolicy.canReduceVolume) {
      return null;
    }

    for (final prescription in block.input.exercisePrescriptions) {
      if (!prescription.supportsStructuredReduction) {
        draft.planFindings.add(
          AdaptationPlanRationaleCode.unsupportedPrescriptionStructure,
        );
        continue;
      }
      final sets = workingSetsByLink[prescription.exerciseLinkLocalId] ??
          prescription.sets;
      if (sets == null || sets <= 1) continue;

      final minSets = block.input.policyMinimumViablePrescription?.sets ??
          block.effectivePolicy.minimumViablePrescription?.sets ??
          1;
      if (sets <= minSets) {
        draft.planFindings.add(
          AdaptationPlanRationaleCode.reductionPreventedByPolicy,
        );
        continue;
      }

      final proposed = sets - 1;
      final reduction = PrescriptionReductionProposal(
        kind: PrescriptionReductionKind.setCount,
        originalValue: sets,
        proposedValue: proposed,
        minimumViablePrescription: block.input.policyMinimumViablePrescription ??
            block.effectivePolicy.minimumViablePrescription,
      );
      if (!reduction.isValid) continue;

      final minutesSaved = _minutesSavedForSetReduction(block.input, 1);
      final exact = minutesSaved != null;
      final appliedSaving = minutesSaved ?? remaining;

      draft.steps.add(
        AdaptationPlanStep(
          sequence: sequence,
          actionType: AdaptationActionType.reduceVolume,
          targetScope: AdaptationConstraintScope.prescription,
          targetId: prescription.exerciseLinkLocalId,
          blockLocalId: block.input.localId,
          blockPosition: block.input.position,
          exerciseLinkLocalId: prescription.exerciseLinkLocalId,
          originalValueReference: 'sets=$sets',
          proposedValueReference: 'sets=$proposed',
          rationaleCode: _isOptionalTier(block)
              ? AdaptationPlanRationaleCode.prescriptionReductionPreferred
              : AdaptationPlanRationaleCode.importantBlockReductionRequired,
          expectedTimeSavingMinutes: minutesSaved,
          expectedTimeSavingUnknown: !exact,
          effectOnFidelity: AdaptationFidelity.moderate,
          requiredStep: true,
          policySource: block.policySource,
          prescriptionReduction: reduction,
        ),
      );
      _recordPolicyFinding(draft, block.policySource);
      workingSetsByLink[prescription.exerciseLinkLocalId] = proposed;
      return _StepProgress(
        nextSequence: sequence + 1,
        minutesSaved: appliedSaving,
        exactSaving: exact,
      );
    }
    return null;
  }

  _StepProgress? _tryRemoveBlock({
    required _MutablePlan draft,
    required ResolvedPlannedBlock block,
    required int sequence,
    AdaptationPlanRationaleCode rationale =
        AdaptationPlanRationaleCode.optionalBlockRemovalRequired,
  }) {
    if (!block.effectivePolicy.canRemove) {
      draft.planFindings.add(AdaptationPlanRationaleCode.removalPreventedByPolicy);
      return null;
    }
    if (_isEssential(block)) {
      return null;
    }

    final duration = block.input.estimatedDurationMinutes;
    final durationUnknown = block.input.estimatedDurationUnknown || duration == null;

    draft.steps.add(
      AdaptationPlanStep(
        sequence: sequence,
        actionType: AdaptationActionType.removeBlock,
        targetScope: AdaptationConstraintScope.block,
        targetId: block.input.localId,
        blockLocalId: block.input.localId,
        blockPosition: block.input.position,
        originalValueReference: 'present',
        proposedValueReference: 'removed',
        rationaleCode: rationale,
        expectedTimeSavingMinutes: duration,
        expectedTimeSavingUnknown: durationUnknown,
        effectOnFidelity: _isOptionalTier(block)
            ? AdaptationFidelity.high
            : AdaptationFidelity.moderate,
        requiredStep: true,
        policySource: block.policySource,
      ),
    );
    _recordPolicyFinding(draft, block.policySource);
    return _StepProgress(
      nextSequence: sequence + 1,
      minutesSaved: durationUnknown ? null : duration,
      exactSaving: !durationUnknown,
    );
  }

  void _recordPolicyFinding(_MutablePlan draft, AdaptationPolicySource source) {
    draft.planFindings.add(
      source == AdaptationPolicySource.explicit
          ? AdaptationPlanRationaleCode.explicitPolicyApplied
          : AdaptationPlanRationaleCode.derivedPolicyApplied,
    );
  }

  int? _minutesSavedForSetReduction(
    PlannedBlockAdaptationInput block,
    int setsRemoved,
  ) {
    final total = block.estimatedDurationMinutes;
    PlannedExercisePrescriptionInput? prescription;
    for (final candidate in block.exercisePrescriptions) {
      if (candidate.supportsStructuredReduction &&
          candidate.sets != null &&
          candidate.sets! > 0) {
        prescription = candidate;
        break;
      }
    }
    if (total == null || prescription == null) return null;
    if (block.estimatedDurationUnknown) return null;
    final sets = prescription.sets!;
    if (sets <= 0) return null;
    return ((total / sets) * setsRemoved).ceil().clamp(1, total);
  }
}

class _PlanBuildContext {
  const _PlanBuildContext({
    required this.session,
    required this.constraints,
    required this.evaluation,
  });

  final PlannedSessionAdaptationInput session;
  final AdaptationConstraintContext constraints;
  final SessionAdaptationEvaluationResult evaluation;
}

class _MutablePlan {
  _MutablePlan({
    required this.status,
    this.planFindings = const [],
    this.expectedFidelity,
  });

  AdaptationPlanStatus status;
  final List<AdaptationPlanStep> steps = [];
  final List<ProtectedAdaptationElement> protectedElements = [];
  final List<AdaptationConstraintContextSummary> unresolvedConstraints = [];
  List<AdaptationPlanRationaleCode> planFindings;
  AdaptationFidelity? expectedFidelity;
  AdaptationConfidence? adaptationConfidence;
  bool exactDurationFeasibilityConfirmed = false;
  bool requiresConfirmationLater = false;
  int? unresolvedDurationDeficitMinutes;

  AdaptationPlanResult toResult(
    _PlanBuildContext base, {
    bool forceNotApplicable = false,
  }) {
    final sortedFindings = planFindings.toSet().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final fidelity = expectedFidelity ?? base.evaluation.expectedFidelity;
    final confidence =
        adaptationConfidence ?? base.evaluation.adaptationConfidence;

    final applicable = !forceNotApplicable &&
        (status == AdaptationPlanStatus.noPlanRequired ||
            status == AdaptationPlanStatus.planGenerated ||
            (status == AdaptationPlanStatus.partialPlan && steps.isNotEmpty));

    return AdaptationPlanResult(
      status: status,
      sourceSessionId: base.session.protocolId,
      evaluationOutcome: base.evaluation.outcome,
      primaryIntent: base.session.primarySessionIntent,
      expectedFidelity: fidelity,
      adaptationConfidence: confidence,
      steps: List.unmodifiable(steps),
      protectedElements: List.unmodifiable(protectedElements),
      unresolvedConstraints: List.unmodifiable(unresolvedConstraints),
      planFindings: List.unmodifiable(sortedFindings),
      isApplicable: applicable,
      requiresConfirmationLater: requiresConfirmationLater,
      unresolvedDurationDeficitMinutes: unresolvedDurationDeficitMinutes,
      exactDurationFeasibilityConfirmed: exactDurationFeasibilityConfirmed,
    );
  }
}

class _StepProgress {
  const _StepProgress({
    required this.nextSequence,
    required this.minutesSaved,
    required this.exactSaving,
  });

  final int nextSequence;
  final int? minutesSaved;
  final bool exactSaving;
}
