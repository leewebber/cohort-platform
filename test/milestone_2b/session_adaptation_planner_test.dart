import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/adaptation_evaluation_test_support.dart';
import '../support/adaptation_planning_test_support.dart';
import '../support/programme_session_authoring_test_support.dart';

void main() {
  const planner = SessionAdaptationPlanner();
  const planValidator = AdaptationPlanValidator();

  group('Milestone 2B Task 2A — adaptation plan generation', () {
    late ProtocolDraft timedDraft;
    late PlannedSessionAdaptationInput timedInput;

    setUp(() {
      timedDraft = buildTimedPlanningSession(protocolId: 'm2b-plan-1');
      timedInput = timedPlanningInputFromDraft(timedDraft);
    });

    test('1 no constraint → noPlanRequired', () {
      final plan = planner.plan(
        session: timedInput,
        constraints: AdaptationConstraintContext.empty(),
      );
      expect(plan.status, AdaptationPlanStatus.noPlanRequired);
      expect(plan.isApplicable, isTrue);
    });

    test('2 available above planned → noPlanRequired', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 70),
      );
      expect(plan.status, AdaptationPlanStatus.noPlanRequired);
    });

    test('3 available equal planned → noPlanRequired', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 60),
      );
      expect(plan.status, AdaptationPlanStatus.noPlanRequired);
    });

    test('4 slight shortening via prescription reduction', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 55),
      );
      expect(plan.steps, isNotEmpty);
      expect(
        plan.steps.first.actionType,
        AdaptationActionType.reduceVolume,
      );
      expect(plan.status, AdaptationPlanStatus.planGenerated);
    });

    test('5 optional tier reduction before removal', () {
      final input = patchBlockPlanningMetadata(
        timedInput,
        durationMinutesByBlockLocalId: {'block-warmup': 10},
      );
      final plan = planner.plan(
        session: input,
        constraints: AdaptationConstraintContext(availableDurationMin: 52),
      );
      expect(
        plan.steps.any((s) => s.actionType == AdaptationActionType.removeBlock),
        isFalse,
      );
    });

    test('6 shortening via optional block removal when needed', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      expect(
        plan.steps.any((s) => s.actionType == AdaptationActionType.removeBlock),
        isTrue,
      );
    });

    test('7 important block reduced when policy permits', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 50),
      );
      expect(
        plan.steps.any(
          (s) =>
              s.blockLocalId == 'block-accessory' &&
              s.actionType == AdaptationActionType.reduceVolume,
        ),
        isTrue,
      );
    });

    test('8 important block removal blocked by policy', () {
      final draft = buildTimedPlanningSession(protocolId: 'm2b-plan-no-remove');
      final input = patchBlockPlanningMetadata(
        timedPlanningInputFromDraft(draft),
      );
      final blockedInput = PlannedSessionAdaptationInput(
        protocolId: input.protocolId,
        primarySessionIntent: input.primarySessionIntent,
        plannedDurationMin: input.plannedDurationMin,
        minimumViableDurationMin: input.minimumViableDurationMin,
        blocks: input.blocks
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
      final plan = planner.plan(
        session: blockedInput,
        constraints: AdaptationConstraintContext(availableDurationMin: 40),
      );
      expect(
        plan.steps.where(
          (s) =>
              s.blockLocalId == 'block-accessory' &&
              s.actionType == AdaptationActionType.removeBlock,
        ),
        isEmpty,
      );
    });

    test('9 essential block protected', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      expect(
        plan.protectedElements.any((p) => p.blockLocalId == 'block-strength'),
        isTrue,
      );
    });

    test('10 essential block never removed to hit time', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 30),
      );
      expect(
        plan.steps.where(
          (s) =>
              s.blockLocalId == 'block-strength' &&
              s.actionType == AdaptationActionType.removeBlock,
        ),
        isEmpty,
      );
    });

    test('11 explicit policy recorded on strength block step', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 36),
      );
      final strengthStep = plan.steps.cast<AdaptationPlanStep?>().firstWhere(
            (s) =>
                s?.blockLocalId == 'block-strength' &&
                s?.actionType == AdaptationActionType.reduceVolume,
            orElse: () => null,
          );
      expect(strengthStep, isNotNull);
      expect(strengthStep!.policySource, AdaptationPolicySource.explicit);
      expect(
        plan.planFindings,
        contains(AdaptationPlanRationaleCode.explicitPolicyApplied),
      );
    });

    test('12 derived policy recorded for warm-up removal step', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      final warmStep = plan.steps.cast<AdaptationPlanStep?>().firstWhere(
            (s) => s?.blockLocalId == 'block-warmup',
            orElse: () => null,
          );
      if (warmStep != null) {
        expect(warmStep.policySource, AdaptationPolicySource.derived);
      }
      expect(
        plan.planFindings,
        contains(AdaptationPlanRationaleCode.derivedPolicyApplied),
      );
    });

    test('13 available equal minimum viable generates plan', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 35),
      );
      expect(
        plan.status == AdaptationPlanStatus.planGenerated ||
            plan.status == AdaptationPlanStatus.partialPlan,
        isTrue,
      );
      expect(plan.steps, isNotEmpty);
    });

    test('14 below minimum viable → unableToPlan', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 20),
      );
      expect(plan.status, AdaptationPlanStatus.unableToPlan);
      expect(plan.isApplicable, isFalse);
    });

    test('15 missing minimum viable duration', () {
      final draft = timedDraft.copyWith(minimumViableDurationMin: null);
      final input = timedPlanningInputFromDraft(draft).copyWithMinViable(null);
      final plan = planner.plan(
        session: input,
        constraints: AdaptationConstraintContext(availableDurationMin: 50),
      );
      expect(
        plan.status == AdaptationPlanStatus.partialPlan ||
            plan.status == AdaptationPlanStatus.insufficientInformation,
        isTrue,
      );
    });

    test('16 unknown block duration → partial not false exact success', () {
      final input = patchBlockPlanningMetadata(
        timedInput,
        durationUnknownByBlockLocalId: {
          for (final b in timedInput.blocks) b.localId: false,
          'block-warmup': true,
        },
        durationMinutesByBlockLocalId: {
          'block-strength': 32,
          'block-accessory': 18,
        },
      );
      final plan = planner.plan(
        session: input,
        constraints: AdaptationConstraintContext(availableDurationMin: 40),
      );
      expect(plan.exactDurationFeasibilityConfirmed, isFalse);
    });

    test('17 unsupported prescription structure reported', () {
      final input = patchBlockPlanningMetadata(
        timedInput,
        durationMinutesByBlockLocalId: {'block-warmup': 10},
      );
      final warmOnly = PlannedSessionAdaptationInput(
        protocolId: input.protocolId,
        primarySessionIntent: input.primarySessionIntent,
        plannedDurationMin: input.plannedDurationMin,
        minimumViableDurationMin: input.minimumViableDurationMin,
        blocks: input.blocks
            .map(
              (b) => b.localId == 'block-warmup'
                  ? PlannedBlockAdaptationInput(
                      localId: b.localId,
                      blockTypeDbValue: b.blockTypeDbValue,
                      position: b.position,
                      estimatedDurationMinutes: 10,
                      estimatedDurationUnknown: false,
                      exercisePrescriptions: const [
                        PlannedExercisePrescriptionInput(
                          exerciseLinkLocalId: 'link-wu-1',
                          exerciseId: 'WU-001',
                          supportsStructuredReduction: false,
                        ),
                      ],
                    )
                  : b,
            )
            .toList(),
      );
      final plan = planner.plan(
        session: warmOnly,
        constraints: AdaptationConstraintContext(availableDurationMin: 58),
      );
      expect(
        plan.planFindings,
        contains(AdaptationPlanRationaleCode.unsupportedPrescriptionStructure),
      );
    });

    test('18 steps ordered by sequence', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 40),
      );
      for (var i = 0; i < plan.steps.length; i++) {
        expect(plan.steps[i].sequence, i + 1);
      }
    });

    test('19 prefers reduction over removal for small deficit', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 57),
      );
      expect(plan.steps.first.actionType, AdaptationActionType.reduceVolume);
      expect(
        plan.steps.any((s) => s.actionType == AdaptationActionType.removeBlock),
        isFalse,
      );
    });

    test('20 planner does not increase prescription', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 55),
      );
      for (final step in plan.steps) {
        final reduction = step.prescriptionReduction;
        if (reduction != null) {
          expect(reduction.proposedValue, lessThan(reduction.originalValue));
        }
      }
    });

    test('21 no contradictory actions per target', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      final validation = planValidator.validate(
        session: timedInput,
        evaluation: evaluation,
        plan: plan,
      );
      expect(
        validation.issues.where(
          (i) =>
              i.code == AdaptationPlanValidationIssueCode.contradictoryTargetActions,
        ),
        isEmpty,
      );
    });

    test('22 valid plan passes validation', () {
      final plan = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 55),
      );
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: AdaptationConstraintContext(availableDurationMin: 55),
      );
      expect(
        planValidator.validate(
          session: timedInput,
          evaluation: evaluation,
          plan: plan,
        ).isValid,
        isTrue,
      );
    });

    test('23 validator rejects illegal essential block removal', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      final illegalPlan = AdaptationPlanResult(
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
        planFindings: const [AdaptationPlanRationaleCode.durationReductionRequired],
        isApplicable: true,
        requiresConfirmationLater: true,
      );
      expect(
        planValidator.validate(
          session: timedInput,
          evaluation: evaluation,
          plan: illegalPlan,
        ).isValid,
        isFalse,
      );
    });

    test('24 code vs builder equivalent plans', () {
      const protocolId = 'm2b-plan-equiv';
      const constraints = AdaptationConstraintContext(availableDurationMin: 45);
      final codeInput = timedPlanningInputFromDraft(
        buildTimedPlanningSession(protocolId: protocolId),
      );
      final builderInput = timedPlanningInputFromDraft(
        buildTimedPlanningSessionViaBuilder(protocolId: protocolId),
      );
      final codePlan = planner.plan(session: codeInput, constraints: constraints);
      final builderPlan = planner.plan(
        session: builderInput,
        constraints: constraints,
      );
      expect(planEquivalent(codePlan, builderPlan), isTrue);
    });

    test('25 planner does not mutate session input', () {
      final input = timedPlanningInputFromDraft(timedDraft);
      final before = input.blocks.map((b) => b.exercisePrescriptions.length).toList();
      planner.plan(
        session: input,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      final after = input.blocks.map((b) => b.exercisePrescriptions.length).toList();
      expect(after, before);
    });

    test('26 same input returns identical plan', () {
      const constraints = AdaptationConstraintContext(availableDurationMin: 45);
      final first = planner.plan(session: timedInput, constraints: constraints);
      final second = planner.plan(session: timedInput, constraints: constraints);
      expect(planEquivalent(first, second), isTrue);
    });

    test('27 evaluation confidence propagated', () {
      final evaluation = const SessionAdaptationReadOnlyEvaluator().evaluate(
        session: timedInput,
        constraints: AdaptationConstraintContext(availableDurationMin: 55),
      );
      final plan = planner.plan(
        session: timedInput,
        constraints: AdaptationConstraintContext(availableDurationMin: 55),
        evaluation: evaluation,
      );
      expect(plan.adaptationConfidence, evaluation.adaptationConfidence);
    });

    test('28 fidelity degrades with heavier interventions', () {
      final light = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 58),
      );
      final heavy = planDraft(
        timedDraft,
        constraints: AdaptationConstraintContext(availableDurationMin: 35),
      );
      expect(
        heavy.expectedFidelity.index >= light.expectedFidelity.index,
        isTrue,
      );
    });

    test('29 unknown metadata avoids exact duration claim', () {
      final input = patchBlockPlanningMetadata(
        timedInput,
        durationUnknownByBlockLocalId: {'block-accessory': true},
      );
      final plan = planner.plan(
        session: input,
        constraints: AdaptationConstraintContext(availableDurationMin: 50),
      );
      expect(plan.exactDurationFeasibilityConfirmed, isFalse);
    });
  });
}

extension on PlannedSessionAdaptationInput {
  PlannedSessionAdaptationInput copyWithMinViable(int? min) {
    return PlannedSessionAdaptationInput(
      protocolId: protocolId,
      primarySessionIntent: primarySessionIntent,
      secondarySessionIntents: secondarySessionIntents,
      plannedDurationMin: plannedDurationMin,
      minimumViableDurationMin: min,
      requiredEquipmentTokens: requiredEquipmentTokens,
      blocks: blocks,
      exerciseMetadataById: exerciseMetadataById,
    );
  }
}
