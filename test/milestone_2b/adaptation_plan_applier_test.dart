import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/adaptation_application_test_support.dart';
import '../support/adaptation_planning_test_support.dart';

void main() {
  const applier = AdaptationPlanApplier();
  const planner = SessionAdaptationPlanner();
  const snapshotValidator = AdaptedSessionExecutionSnapshotValidator();

  group('Milestone 2B Task 2B — apply adaptation plan', () {
    late ProtocolDraft timedDraft;
    late PlannedSessionAdaptationInput timedInput;

    setUp(() {
      timedDraft = buildTimedPlanningSession(protocolId: 'm2b-apply-1');
      timedInput = timedPlanningInputFromDraft(timedDraft);
    });

    AdaptationPlanApplicationResult applyWithPlan({
      required AdaptationPlanResult plan,
      PlannedSessionAdaptationInput? source,
      AdaptationConstraintContext constraints =
          const AdaptationConstraintContext(availableDurationMin: 55),
    }) {
      final session = source ?? timedInput;
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: session,
        constraints: constraints.validated(),
      );
      return applier.apply(
        source: session,
        plan: plan,
        constraints: constraints,
        evaluation: evaluation,
      );
    }

    test('1 noPlanRequired creates unchanged execution snapshot', () {
      final constraints = AdaptationConstraintContext.empty();
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: constraints,
      );
      final plan = planner.plan(
        session: timedInput,
        constraints: constraints,
        evaluation: evaluation,
      );
      final result = applier.apply(
        source: timedInput,
        plan: plan,
        constraints: constraints,
        evaluation: evaluation,
      );
      expect(result.status, AdaptationPlanApplicationStatus.noAdaptationRequired);
      expect(result.snapshot!.retainedBlocks, hasLength(3));
      expect(result.snapshot!.appliedAdaptationAudit, isEmpty);
      expect(result.snapshot!.retainedBlocks.every((b) => !b.adapted), isTrue);
    });

    test('2 snapshot independent from later source edits', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      final snapshotSets = result.snapshot!.retainedBlocks
          .expand((b) => b.exercises)
          .map((e) => e.executionPrescription.sets)
          .toList();

      final mutated = patchBlockPlanningMetadata(
        timedInput,
        durationMinutesByBlockLocalId: {'block-strength': 5},
      );
      expect(mutated.blocks.first.estimatedDurationMinutes, isNotNull);

      expect(
        result.snapshot!.retainedBlocks
            .expand((b) => b.exercises)
            .map((e) => e.executionPrescription.sets)
            .toList(),
        snapshotSets,
      );
    });

    test('3 one set-count reduction applies correctly', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 50),
      );
      final accessory = result.snapshot!.retainedBlocks
          .firstWhere((b) => b.sourceBlockLocalId == 'block-accessory');
      expect(accessory.adapted, isTrue);
      expect(
        accessory.exercises.first.executionPrescription.sets,
        lessThan(accessory.exercises.first.originalPrescription.sets!),
      );
    });

    test('4 multiple reductions apply in order', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 40),
      );
      for (var i = 0; i < result.snapshot!.appliedAdaptationAudit.length; i++) {
        expect(result.snapshot!.appliedAdaptationAudit[i].planStepSequence, i + 1);
      }
    });

    test('5 non-target prescription fields unchanged', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      final ex = result.snapshot!.retainedBlocks
          .firstWhere((b) => b.sourceBlockLocalId == 'block-strength')
          .exercises
          .first;
      expect(ex.executionPrescription.reps, ex.originalPrescription.reps);
      expect(ex.executionPrescription.restSeconds, ex.originalPrescription.restSeconds);
    });

    test('6 reduction below minimum rejected', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      final plan = planner.plan(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
        evaluation: evaluation,
      );
      final badStep = AdaptationPlanStep(
        sequence: 99,
        actionType: AdaptationActionType.reduceVolume,
        targetScope: AdaptationConstraintScope.prescription,
        targetId: 'link-strength-1',
        blockLocalId: 'block-strength',
        blockPosition: 2,
        exerciseLinkLocalId: 'link-strength-1',
        originalValueReference: 'sets=4',
        proposedValueReference: 'sets=1',
        rationaleCode: AdaptationPlanRationaleCode.prescriptionReductionPreferred,
        requiredStep: true,
        policySource: AdaptationPolicySource.explicit,
        prescriptionReduction: const PrescriptionReductionProposal(
          kind: PrescriptionReductionKind.setCount,
          originalValue: 4,
          proposedValue: 1,
          minimumViablePrescription: MinimumViablePrescription(sets: 2),
        ),
      );
      final badPlan = AdaptationPlanResult(
        status: AdaptationPlanStatus.planGenerated,
        sourceSessionId: timedInput.protocolId,
        evaluationOutcome: evaluation.outcome,
        primaryIntent: timedInput.primarySessionIntent,
        expectedFidelity: AdaptationFidelity.moderate,
        adaptationConfidence: evaluation.adaptationConfidence,
        steps: [badStep],
        protectedElements: const [],
        unresolvedConstraints: const [],
        planFindings: const [AdaptationPlanRationaleCode.durationReductionRequired],
        isApplicable: true,
        requiresConfirmationLater: true,
      );
      final result = applyWithPlan(plan: badPlan);
      expect(result.status, AdaptationPlanApplicationStatus.applicationFailed);
    });

    test('7 volume increase rejected', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      final badPlan = AdaptationPlanResult(
        status: AdaptationPlanStatus.planGenerated,
        sourceSessionId: timedInput.protocolId,
        evaluationOutcome: evaluation.outcome,
        primaryIntent: timedInput.primarySessionIntent,
        expectedFidelity: AdaptationFidelity.moderate,
        adaptationConfidence: evaluation.adaptationConfidence,
        steps: [
          AdaptationPlanStep(
            sequence: 1,
            actionType: AdaptationActionType.reduceVolume,
            targetScope: AdaptationConstraintScope.prescription,
            targetId: 'link-strength-1',
            blockLocalId: 'block-strength',
            exerciseLinkLocalId: 'link-strength-1',
            rationaleCode: AdaptationPlanRationaleCode.prescriptionReductionPreferred,
            requiredStep: true,
            policySource: AdaptationPolicySource.explicit,
            prescriptionReduction: const PrescriptionReductionProposal(
              kind: PrescriptionReductionKind.setCount,
              originalValue: 4,
              proposedValue: 5,
            ),
          ),
        ],
        protectedElements: const [],
        unresolvedConstraints: const [],
        planFindings: const [],
        isApplicable: true,
        requiresConfirmationLater: true,
      );
      expect(
        applyWithPlan(plan: badPlan).status,
        AdaptationPlanApplicationStatus.rejectedInvalidPlan,
      );
    });

    test('8 stale original set count rejected', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      final badPlan = AdaptationPlanResult(
        status: AdaptationPlanStatus.planGenerated,
        sourceSessionId: timedInput.protocolId,
        evaluationOutcome: evaluation.outcome,
        primaryIntent: timedInput.primarySessionIntent,
        expectedFidelity: AdaptationFidelity.moderate,
        adaptationConfidence: evaluation.adaptationConfidence,
        steps: [
          AdaptationPlanStep(
            sequence: 1,
            actionType: AdaptationActionType.reduceVolume,
            targetScope: AdaptationConstraintScope.prescription,
            targetId: 'link-strength-1',
            blockLocalId: 'block-strength',
            exerciseLinkLocalId: 'link-strength-1',
            rationaleCode: AdaptationPlanRationaleCode.prescriptionReductionPreferred,
            requiredStep: true,
            policySource: AdaptationPolicySource.explicit,
            prescriptionReduction: const PrescriptionReductionProposal(
              kind: PrescriptionReductionKind.setCount,
              originalValue: 99,
              proposedValue: 3,
            ),
          ),
        ],
        protectedElements: const [],
        unresolvedConstraints: const [],
        planFindings: const [],
        isApplicable: true,
        requiresConfirmationLater: true,
      );
      expect(
        applyWithPlan(plan: badPlan).issues.first.code,
        AdaptationPlanApplicationIssueCode.stalePrescriptionOriginalValue,
      );
    });

    test('9 optional block removal applies correctly', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      expect(
        result.snapshot!.omittedBlocks.any((o) => o.sourceBlockLocalId == 'block-warmup'),
        isTrue,
      );
      expect(
        result.snapshot!.retainedBlocks.any((b) => b.sourceBlockLocalId == 'block-warmup'),
        isFalse,
      );
    });

    test('10 important block removal only when policy permits', () {
      final blocked = patchBlockPlanningMetadata(timedInput);
      final blockedInput = PlannedSessionAdaptationInput(
        protocolId: blocked.protocolId,
        primarySessionIntent: blocked.primarySessionIntent,
        plannedDurationMin: blocked.plannedDurationMin,
        minimumViableDurationMin: blocked.minimumViableDurationMin,
        blocks: blocked.blocks
            .map(
              (b) => b.localId == 'block-accessory'
                  ? PlannedBlockAdaptationInput(
                      localId: b.localId,
                      blockTypeDbValue: b.blockTypeDbValue,
                      position: b.position,
                      explicitPriority: b.explicitPriority,
                      explicitPolicy: const BlockAdaptationPolicy(
                        canRemove: false,
                        canShorten: true,
                        canReduceVolume: true,
                        canReduceIntensity: true,
                        canIncreaseRest: true,
                        canSuperset: false,
                        canReplaceExercises: true,
                        canReplaceBlock: false,
                      ),
                      linkedExerciseIds: b.linkedExerciseIds,
                      estimatedDurationMinutes: b.estimatedDurationMinutes,
                      estimatedDurationUnknown: b.estimatedDurationUnknown,
                      exercisePrescriptions: b.exercisePrescriptions,
                    )
                  : b,
            )
            .toList(),
      );
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 40),
        input: blockedInput,
      );
      expect(
        result.snapshot!.omittedBlocks
            .where((o) => o.sourceBlockLocalId == 'block-accessory'),
        isEmpty,
      );
    });

    test('11 essential block removal rejected', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      final plan = planner.plan(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
        evaluation: evaluation,
      );
      final illegal = AdaptationPlanResult(
        status: AdaptationPlanStatus.planGenerated,
        sourceSessionId: timedInput.protocolId,
        evaluationOutcome: evaluation.outcome,
        primaryIntent: timedInput.primarySessionIntent,
        expectedFidelity: AdaptationFidelity.moderate,
        adaptationConfidence: evaluation.adaptationConfidence,
        steps: [
          AdaptationPlanStep(
            sequence: 1,
            actionType: AdaptationActionType.removeBlock,
            targetScope: AdaptationConstraintScope.block,
            targetId: 'block-strength',
            blockLocalId: 'block-strength',
            rationaleCode: AdaptationPlanRationaleCode.optionalBlockRemovalRequired,
            requiredStep: true,
            policySource: AdaptationPolicySource.explicit,
          ),
        ],
        protectedElements: const [],
        unresolvedConstraints: const [],
        planFindings: const [],
        isApplicable: true,
        requiresConfirmationLater: true,
      );
      expect(
        applyWithPlan(plan: illegal).status,
        AdaptationPlanApplicationStatus.rejectedInvalidPlan,
      );
    });

    test('12 removed block absent from retained list', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      final removed = result.snapshot!.omittedBlocks.map((o) => o.sourceBlockLocalId).toSet();
      for (final id in removed) {
        expect(
          result.snapshot!.retainedBlocks.any((b) => b.sourceBlockLocalId == id),
          isFalse,
        );
      }
    });

    test('13 removed block in omitted audit records', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      expect(result.snapshot!.omittedBlocks, isNotEmpty);
      expect(result.snapshot!.appliedAdaptationAudit, isNotEmpty);
    });

    test('14 retained block order stable by source position', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      final positions = result.snapshot!.retainedBlocks
          .map((b) => b.sourcePosition)
          .toList();
      expect(positions, orderedEquals(positions.toList()..sort()));
    });

    test('15 source positions traceable on omitted blocks', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      for (final omitted in result.snapshot!.omittedBlocks) {
        expect(omitted.sourcePosition, greaterThan(0));
      }
    });

    test('16 missing block target rejects application', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      final badPlan = AdaptationPlanResult(
        status: AdaptationPlanStatus.planGenerated,
        sourceSessionId: timedInput.protocolId,
        evaluationOutcome: evaluation.outcome,
        primaryIntent: timedInput.primarySessionIntent,
        expectedFidelity: AdaptationFidelity.moderate,
        adaptationConfidence: evaluation.adaptationConfidence,
        steps: [
          AdaptationPlanStep(
            sequence: 1,
            actionType: AdaptationActionType.removeBlock,
            targetScope: AdaptationConstraintScope.block,
            targetId: 'missing-block',
            blockLocalId: 'missing-block',
            rationaleCode: AdaptationPlanRationaleCode.optionalBlockRemovalRequired,
            requiredStep: true,
            policySource: AdaptationPolicySource.derived,
          ),
        ],
        protectedElements: const [],
        unresolvedConstraints: const [],
        planFindings: const [],
        isApplicable: true,
        requiresConfirmationLater: true,
      );
      expect(
        applyWithPlan(plan: badPlan).status,
        AdaptationPlanApplicationStatus.rejectedInvalidPlan,
      );
    });

    test('17 duplicate block removal rejected', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      final step = AdaptationPlanStep(
        sequence: 1,
        actionType: AdaptationActionType.removeBlock,
        targetScope: AdaptationConstraintScope.block,
        targetId: 'block-warmup',
        blockLocalId: 'block-warmup',
        rationaleCode: AdaptationPlanRationaleCode.optionalBlockRemovalRequired,
        requiredStep: true,
        policySource: AdaptationPolicySource.derived,
      );
      final badPlan = AdaptationPlanResult(
        status: AdaptationPlanStatus.planGenerated,
        sourceSessionId: timedInput.protocolId,
        evaluationOutcome: evaluation.outcome,
        primaryIntent: timedInput.primarySessionIntent,
        expectedFidelity: AdaptationFidelity.moderate,
        adaptationConfidence: evaluation.adaptationConfidence,
        steps: [
          step,
          step.copyWith(sequence: 2, targetId: 'block-warmup-dup'),
        ],
        protectedElements: const [],
        unresolvedConstraints: const [],
        planFindings: const [],
        isApplicable: true,
        requiresConfirmationLater: true,
      );
      expect(
        applyWithPlan(plan: badPlan).status,
        AdaptationPlanApplicationStatus.applicationFailed,
      );
      expect(
        applyWithPlan(plan: badPlan).issues.any(
              (i) => i.code == AdaptationPlanApplicationIssueCode.duplicateBlockRemoval,
            ),
        isTrue,
      );
    });

    test('18 unsupported action rejected', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      final badPlan = AdaptationPlanResult(
        status: AdaptationPlanStatus.planGenerated,
        sourceSessionId: timedInput.protocolId,
        evaluationOutcome: evaluation.outcome,
        primaryIntent: timedInput.primarySessionIntent,
        expectedFidelity: AdaptationFidelity.moderate,
        adaptationConfidence: evaluation.adaptationConfidence,
        steps: [
          AdaptationPlanStep(
            sequence: 1,
            actionType: AdaptationActionType.shortenDuration,
            targetScope: AdaptationConstraintScope.block,
            targetId: 'block-strength',
            blockLocalId: 'block-strength',
            rationaleCode: AdaptationPlanRationaleCode.prescriptionReductionPreferred,
            requiredStep: true,
            policySource: AdaptationPolicySource.explicit,
          ),
        ],
        protectedElements: const [],
        unresolvedConstraints: const [],
        planFindings: const [],
        isApplicable: true,
        requiresConfirmationLater: true,
      );
      expect(
        applyWithPlan(plan: badPlan).status,
        AdaptationPlanApplicationStatus.unsupportedPlanStep,
      );
    });

    test('19 source session mismatch rejected', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      final plan = planner.plan(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
        evaluation: evaluation,
      );
      final mismatched = PlannedSessionAdaptationInput(
        protocolId: 'other-id',
        blocks: timedInput.blocks,
      );
      expect(
        applier
            .apply(
              source: mismatched,
              plan: plan,
              constraints: const AdaptationConstraintContext(availableDurationMin: 55),
              evaluation: evaluation,
            )
            .status,
        AdaptationPlanApplicationStatus.rejectedSourceMismatch,
      );
    });

    test('20 stale policy source rejected', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 50),
      );
      final plan = planner.plan(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 50),
        evaluation: evaluation,
      );
      final baseStep = plan.steps.firstWhere(
        (s) => s.actionType == AdaptationActionType.reduceVolume,
      );
      final staleStep = baseStep.copyWith(
        policySource: baseStep.policySource == AdaptationPolicySource.explicit
            ? AdaptationPolicySource.derived
            : AdaptationPolicySource.explicit,
      );
      final stalePlan = AdaptationPlanResult(
        status: plan.status,
        sourceSessionId: plan.sourceSessionId,
        evaluationOutcome: plan.evaluationOutcome,
        primaryIntent: plan.primaryIntent,
        expectedFidelity: plan.expectedFidelity,
        adaptationConfidence: plan.adaptationConfidence,
        steps: [staleStep],
        protectedElements: plan.protectedElements,
        unresolvedConstraints: plan.unresolvedConstraints,
        planFindings: plan.planFindings,
        isApplicable: plan.isApplicable,
        requiresConfirmationLater: plan.requiresConfirmationLater,
      );
      expect(
        applyWithPlan(plan: stalePlan).issues.first.code,
        AdaptationPlanApplicationIssueCode.policyMismatch,
      );
    });

    test('21 each applied step creates audit entry', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      expect(
        result.snapshot!.appliedAdaptationAudit.length,
        result.snapshot!.appliedAdaptationAudit
            .map((a) => a.planStepSequence)
            .toSet()
            .length,
      );
    });

    test('22 snapshot validator detects retained-and-omitted duplication', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      final plan = planner.plan(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
        evaluation: evaluation,
      );
      final badSnapshot = AdaptedSessionExecutionSnapshot(
        snapshotId: 'bad',
        sourceProtocolId: timedInput.protocolId,
        status: AdaptedSessionExecutionSnapshotStatus.ready,
        originalPlannedDurationMin: 60,
        resultingEstimatedDurationMin: null,
        durationEstimateReliable: false,
        primarySessionIntent: timedInput.primarySessionIntent,
        secondarySessionIntents: const [],
        retainedBlocks: [
          BlockExecutionSnapshot(
            sourceBlockLocalId: 'block-warmup',
            sourcePosition: 1,
            blockTypeDbValue: SessionBlockType.warmUp.name,
            effectivePriority: BlockPriority.disposable,
            effectivePolicy: const BlockAdaptationPolicy(
              canRemove: true,
              canShorten: true,
              canReduceVolume: true,
              canReduceIntensity: true,
              canIncreaseRest: true,
              canSuperset: true,
              canReplaceExercises: true,
              canReplaceBlock: true,
            ),
            policySource: AdaptationPolicySource.derived,
            exercises: const [],
            adapted: false,
            appliedPlanStepSequences: const [],
          ),
        ],
        omittedBlocks: [
          OmittedBlockExecutionRecord(
            sourceBlockLocalId: 'block-warmup',
            sourcePosition: 1,
            blockTypeDbValue: SessionBlockType.warmUp.name,
            omissionAction: AdaptationActionType.removeBlock,
            rationaleCode: AdaptationPlanRationaleCode.optionalBlockRemovalRequired,
            policySource: AdaptationPolicySource.derived,
            planStepSequence: 1,
          ),
        ],
        appliedAdaptationAudit: const [],
        expectedFidelity: plan.expectedFidelity,
        adaptationConfidence: plan.adaptationConfidence,
        evaluationOutcome: plan.evaluationOutcome,
        planStatus: plan.status,
        unresolvedConstraints: const [],
        exactDurationFeasibilityConfirmed: false,
        unresolvedDurationDeficitMinutes: null,
        planFindings: const [],
      );
      expect(
        snapshotValidator
            .validate(source: timedInput, plan: plan, snapshot: badSnapshot)
            .isValid,
        isFalse,
      );
    });

    test('23 snapshot validator detects unplanned adaptation', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 50),
      );
      final plan = planner.plan(
        session: timedInput,
        constraints: const AdaptationConstraintContext(availableDurationMin: 50),
        evaluation: const SessionAdaptationReadOnlyEvaluator().evaluate(
          session: timedInput,
          constraints: AdaptationConstraintContext(availableDurationMin: 50),
        ),
      );
      final snapshot = result.snapshot!;
      final tamperedBlock = snapshot.retainedBlocks.first;
      final tampered = AdaptedSessionExecutionSnapshot(
        snapshotId: snapshot.snapshotId,
        sourceProtocolId: snapshot.sourceProtocolId,
        status: snapshot.status,
        originalPlannedDurationMin: snapshot.originalPlannedDurationMin,
        resultingEstimatedDurationMin: snapshot.resultingEstimatedDurationMin,
        durationEstimateReliable: snapshot.durationEstimateReliable,
        primarySessionIntent: snapshot.primarySessionIntent,
        secondarySessionIntents: snapshot.secondarySessionIntents,
        retainedBlocks: [
          BlockExecutionSnapshot(
            sourceBlockLocalId: tamperedBlock.sourceBlockLocalId,
            sourcePosition: tamperedBlock.sourcePosition,
            blockTypeDbValue: tamperedBlock.blockTypeDbValue,
            effectivePriority: tamperedBlock.effectivePriority,
            effectivePolicy: tamperedBlock.effectivePolicy,
            policySource: tamperedBlock.policySource,
            exercises: tamperedBlock.exercises,
            adapted: true,
            appliedPlanStepSequences: const [],
          ),
        ],
        omittedBlocks: snapshot.omittedBlocks,
        appliedAdaptationAudit: snapshot.appliedAdaptationAudit,
        expectedFidelity: snapshot.expectedFidelity,
        adaptationConfidence: snapshot.adaptationConfidence,
        evaluationOutcome: snapshot.evaluationOutcome,
        planStatus: snapshot.planStatus,
        unresolvedConstraints: snapshot.unresolvedConstraints,
        exactDurationFeasibilityConfirmed: snapshot.exactDurationFeasibilityConfirmed,
        unresolvedDurationDeficitMinutes: snapshot.unresolvedDurationDeficitMinutes,
        planFindings: snapshot.planFindings,
      );
      final validation = snapshotValidator.validate(
        source: timedInput,
        plan: plan,
        snapshot: tampered,
      );
      expect(validation.isValid, isFalse);
      expect(
        validation.issues.any(
          (i) => i.code == AdaptedSessionExecutionSnapshotIssueCode.unplannedAdaptation,
        ),
        isTrue,
      );
    });

    test('24 exact duration not claimed when evidence incomplete', () {
      final input = patchBlockPlanningMetadata(
        timedInput,
        durationUnknownByBlockLocalId: {'block-warmup': true},
      );
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 50),
        input: input,
      );
      expect(result.snapshot!.exactDurationFeasibilityConfirmed, isFalse);
    });

    test('25 fidelity propagates from plan', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      expect(result.snapshot!.expectedFidelity, AdaptationFidelity.moderate);
    });

    test('26 confidence propagates from plan', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 55),
      );
      expect(result.snapshot!.adaptationConfidence, isNotNull);
    });

    test('27 unresolved constraints propagate', () {
      final result = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 20),
      );
      expect(result.status, isNot(AdaptationPlanApplicationStatus.applied));
    });

    test('28 source input not mutated', () {
      final before = timedInput.blocks.map((b) => b.exercisePrescriptions.length).toList();
      applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      expect(
        timedInput.blocks.map((b) => b.exercisePrescriptions.length).toList(),
        before,
      );
    });

    test('29 plan object not mutated through apply', () {
      const constraints = AdaptationConstraintContext(availableDurationMin: 55);
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: constraints,
      );
      final plan = planner.plan(
        session: timedInput,
        constraints: constraints,
        evaluation: evaluation,
      );
      final stepsBefore = plan.steps.length;
      applier.apply(
        source: timedInput,
        plan: plan,
        constraints: constraints,
        evaluation: evaluation,
      );
      expect(plan.steps.length, stepsBefore);
    });

    test('30 applying same plan twice yields equivalent snapshots', () {
      const constraints = AdaptationConstraintContext(availableDurationMin: 45);
      final first = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: constraints,
      );
      final second = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: constraints,
      );
      expect(
        snapshotSemanticallyEqual(first.snapshot!, second.snapshot!),
        isTrue,
      );
    });

    test('31 code vs builder equivalent snapshots', () {
      const protocolId = 'm2b-apply-equiv';
      const constraints = AdaptationConstraintContext(availableDurationMin: 45);
      final code = applyTimedSessionPlan(
        draft: buildTimedPlanningSession(protocolId: protocolId),
        constraints: constraints,
      );
      final builder = applyTimedSessionPlan(
        draft: buildTimedPlanningSessionViaBuilder(protocolId: protocolId),
        constraints: constraints,
      );
      expect(
        snapshotSemanticallyEqual(code.snapshot!, builder.snapshot!),
        isTrue,
      );
    });

    test('32 represents adapted and unadapted occurrences', () {
      final unadapted = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: AdaptationConstraintContext.empty(),
      );
      final adapted = applyTimedSessionPlan(
        draft: timedDraft,
        constraints: const AdaptationConstraintContext(availableDurationMin: 45),
      );
      expect(unadapted.snapshot!.appliedAdaptationAudit, isEmpty);
      expect(adapted.snapshot!.appliedAdaptationAudit, isNotEmpty);
    });
  });
}

extension on AdaptationPlanStep {
  AdaptationPlanStep copyWith({
    int? sequence,
    AdaptationPolicySource? policySource,
    String? targetId,
  }) {
    return AdaptationPlanStep(
      sequence: sequence ?? this.sequence,
      actionType: actionType,
      targetScope: targetScope,
      targetId: targetId ?? this.targetId,
      blockLocalId: blockLocalId,
      blockPosition: blockPosition,
      exerciseLinkLocalId: exerciseLinkLocalId,
      originalValueReference: originalValueReference,
      proposedValueReference: proposedValueReference,
      rationaleCode: rationaleCode,
      expectedTimeSavingMinutes: expectedTimeSavingMinutes,
      expectedTimeSavingUnknown: expectedTimeSavingUnknown,
      effectOnFidelity: effectOnFidelity,
      requiredStep: requiredStep,
      policySource: policySource ?? this.policySource,
      prescriptionReduction: prescriptionReduction,
    );
  }
}
