import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/adaptation_evaluation_test_support.dart';
import '../support/programme_session_authoring_test_support.dart';

BlockAdaptationEvaluation? blockEvalForType(
  ProtocolDraft draft,
  SessionAdaptationEvaluationResult result,
  SessionBlockType type,
) {
  final block = draft.blocks.cast<SessionBlock?>().firstWhere(
        (b) => b!.blockType == type,
        orElse: () => null,
      );
  if (block == null) return null;
  for (final eval in result.blockResults) {
    if (eval.blockLocalId == block.localId) return eval;
  }
  return null;
}

void main() {
  const evaluator = SessionAdaptationReadOnlyEvaluator();

  group('Milestone 2B Task 1 — read-only adaptation evaluator', () {
    late ProtocolDraft taggedSession;

    setUp(() {
      taggedSession = buildTaggedSessionViaCode(
        protocolId: 'm2b-eval-1',
        programmeVersionId: testProgrammeVersionId,
      );
    });

    test('1 no constraints → noAdaptationRequired', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext.empty(),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.noAdaptationRequired);
      expect(
        result.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.noConstraintConflict,
        ),
        isTrue,
      );
    });

    test('2 time above planned duration → noAdaptationRequired', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(
          availableDurationMin: canonicalPlannedDuration + 10,
        ),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.noAdaptationRequired);
    });

    test('3 time equal to planned duration → noAdaptationRequired', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(
          availableDurationMin: canonicalPlannedDuration,
        ),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.noAdaptationRequired);
    });

    test('4 time below planned but above minimum viable → adaptable', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.adaptable);
      expect(result.primaryIntentPreservable, isTrue);
      expect(
        result.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.insufficientDuration,
        ),
        isTrue,
      );
    });

    test('5 time equal to minimum viable → adaptable', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(
          availableDurationMin: canonicalMinDuration,
        ),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.adaptable);
      expect(result.minimumScope, AdaptationMinimumScope.blockReduction);
    });

    test('6 time below minimum viable → notAdaptable', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(availableDurationMin: 20),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.notAdaptable);
      expect(result.primaryIntentPreservable, isFalse);
    });

    test('7 missing minimum viable duration → insufficientInformation', () {
      final draft = programmeSession(
        protocolId: 'm2b-no-min',
        name: 'No min viable',
        programmeVersionId: testProgrammeVersionId,
        ownerId: 'dev-coach',
        durationMin: 60,
        primarySessionIntent: SessionIntent.upperBodyStrength,
        minimumViableDurationMin: null,
        validateAdaptationMetadata: false,
        blocks: taggedSession.blocks,
      );
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext(availableDurationMin: 40),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.insufficientInformation);
      expect(
        result.missingMetadata,
        contains(AdaptationEvaluationFindingCode.missingMinimumViableDuration),
      );
    });

    test('8 optional removable block available (warm-up derived disposable)', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      final warmUp = blockEvalForType(
        taggedSession,
        result,
        SessionBlockType.warmUp,
      );
      expect(warmUp, isNotNull);
      expect(warmUp!.removalPermittedByPolicy, isTrue);
      expect(warmUp.removalBlockedByEssentialPriority, isFalse);
    });

    test('9 essential block cannot be assumed removable under time pressure', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(availableDurationMin: 45),
      );
      final strength = blockEvalForType(
        taggedSession,
        result,
        SessionBlockType.strength,
      );
      expect(strength!.removalBlockedByEssentialPriority, isTrue);
      expect(
        strength.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.essentialBlockAtRisk,
        ),
        isTrue,
      );
    });

    test('10 explicit policy overrides derived default on strength block', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext.empty(),
      );
      final strength = blockEvalForType(
        taggedSession,
        result,
        SessionBlockType.strength,
      );
      expect(strength!.policySource, AdaptationPolicySource.explicit);
      expect(strength.explicitPolicy, isNotNull);
      expect(
        strength.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.explicitPolicyInUse,
        ),
        isTrue,
      );
    });

    test('11 derived policy identified on warm-up block', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext.empty(),
      );
      final warmUp = blockEvalForType(
        taggedSession,
        result,
        SessionBlockType.warmUp,
      );
      expect(warmUp!.policySource, AdaptationPolicySource.derived);
      expect(
        warmUp.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.derivedPolicyInUse,
        ),
        isTrue,
      );
    });

    test('12 equipment compatible when tokens satisfied', () {
      final draft = taggedSession.copyWith(requiredEquipment: 'barbell,rack');
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext(
          availableEquipment: {'barbell', 'rack', 'dumbbells'},
        ),
      );
      expect(
        result.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.equipmentCompatible,
        ),
        isTrue,
      );
      expect(result.outcome, AdaptationEvaluationOutcome.noAdaptationRequired);
    });

    test('13 equipment mismatch → notAdaptable', () {
      final draft = taggedSession.copyWith(requiredEquipment: 'barbell,rack');
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext(
          availableEquipment: {'dumbbells'},
        ),
      );
      expect(
        result.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.equipmentMismatch,
        ),
        isTrue,
      );
      expect(result.outcome, AdaptationEvaluationOutcome.notAdaptable);
    });

    test('14 missing equipment metadata → unknown not a match', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(
          availableEquipment: {'barbell'},
        ),
      );
      expect(
        result.missingMetadata,
        contains(AdaptationEvaluationFindingCode.equipmentMetadataMissing),
      );
    });

    test('15 movement restriction conflict', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(
          restrictedMovementPatterns: {MovementPattern.horizontalPush},
        ),
      );
      expect(
        result.findings.any(
          (f) =>
              f.code == AdaptationEvaluationFindingCode.movementRestrictionConflict,
        ),
        isTrue,
      );
      expect(result.outcome, AdaptationEvaluationOutcome.notAdaptable);
    });

    test('16 missing movement metadata → unknown', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(
          restrictedMovementPatterns: {MovementPattern.horizontalPush},
        ),
        exerciseMetadataById: const {},
      );
      expect(
        result.missingMetadata,
        contains(AdaptationEvaluationFindingCode.movementMetadataMissing),
      );
    });

    test('17 impact conflict', () {
      final draft = taggedSession.copyWith(physiologicalDemand: 'High impact');
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext(
          maxPermittedImpact: ImpactLevel.low,
        ),
      );
      expect(
        result.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.impactConflict,
        ),
        isTrue,
      );
      expect(result.outcome, AdaptationEvaluationOutcome.notAdaptable);
    });

    test('18 missing primary session intent → insufficientInformation', () {
      final draft = programmeSession(
        protocolId: 'm2b-no-intent',
        name: 'Untagged',
        programmeVersionId: testProgrammeVersionId,
        ownerId: 'dev-coach',
        durationMin: 60,
        primarySessionIntent: null,
        minimumViableDurationMin: 35,
        validateAdaptationMetadata: false,
        blocks: taggedSession.blocks,
      );
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext.empty(),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.insufficientInformation);
      expect(result.primaryIntentKnown, isFalse);
    });

    test('19 multiple simultaneous constraints', () {
      final draft = taggedSession.copyWith(
        requiredEquipment: 'barbell',
        physiologicalDemand: 'High',
      );
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext(
          availableDurationMin: 45,
          availableEquipment: {'dumbbells'},
          maxPermittedImpact: ImpactLevel.low,
        ),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.notAdaptable);
      expect(
        result.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.equipmentMismatch,
        ),
        isTrue,
      );
      expect(
        result.findings.any(
          (f) => f.code == AdaptationEvaluationFindingCode.impactConflict,
        ),
        isTrue,
      );
    });

    test('20 code-authored and builder-authored equivalent evaluations', () {
      const protocolId = 'm2b-equiv-eval';
      final code = buildTaggedSessionViaCode(
        protocolId: protocolId,
        programmeVersionId: testProgrammeVersionId,
      );
      final visual = buildTaggedSessionViaVisualBuilder(
        protocolId: protocolId,
        programmeVersionId: testProgrammeVersionId,
      );
      final constraints = AdaptationConstraintContext(availableDurationMin: 45);
      final codeResult = evaluateDraft(code, constraints: constraints);
      final visualResult = evaluateDraft(visual, constraints: constraints);
      expect(resultEquivalent(codeResult, visualResult), isTrue);
    });

    test('21 evaluator does not mutate session or blocks', () {
      final draft = buildTaggedSessionViaCode(
        protocolId: 'm2b-immutable',
        programmeVersionId: testProgrammeVersionId,
      );
      final beforeBlocks =
          draft.blocks.map((b) => b.toRowMap(sessionId: draft.protocolId)).toList();
      final beforeIntent = draft.primarySessionIntent;
      evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext(availableDurationMin: 30),
      );
      final afterBlocks =
          draft.blocks.map((b) => b.toRowMap(sessionId: draft.protocolId)).toList();
      expect(draft.primarySessionIntent, beforeIntent);
      expect(afterBlocks, beforeBlocks);
    });

    test('22 deterministic output for identical input', () {
      final input = plannedInputFromDraft(taggedSession);
      const constraints = AdaptationConstraintContext(availableDurationMin: 45);
      final first = evaluator.evaluate(session: input, constraints: constraints);
      final second = evaluator.evaluate(session: input, constraints: constraints);
      expect(first.outcome, second.outcome);
      expect(first.minimumScope, second.minimumScope);
      expect(first.expectedFidelity, second.expectedFidelity);
      expect(first.adaptationConfidence, second.adaptationConfidence);
      expect(
        first.findings.map((f) => f.code).toList(),
        second.findings.map((f) => f.code).toList(),
      );
    });

    test('invalid time constraint rejected by validated()', () {
      expect(
        () => AdaptationConstraintContext(availableDurationMin: 0).validated(),
        throwsArgumentError,
      );
    });
  });

  group('AdaptationConfidence assessment', () {
    late ProtocolDraft taggedSession;

    setUp(() {
      taggedSession = buildTaggedSessionViaCode(
        protocolId: 'm2b-confidence-1',
        programmeVersionId: testProgrammeVersionId,
      );
    });

    test('1 fully tagged session, no conflicts → high confidence', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext.empty(),
      );
      expect(result.adaptationConfidence, AdaptationConfidence.high);
      expect(
        result.confidenceFindings,
        contains(AdaptationConfidenceFindingCode.primarySessionIntentPresent),
      );
      expect(
        result.confidenceFindings,
        contains(
          AdaptationConfidenceFindingCode.evaluationConclusionsFullySupported,
        ),
      );
    });

    test('2 confirmed time conflict below minimum viable → high confidence', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(availableDurationMin: 20),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.notAdaptable);
      expect(result.adaptationConfidence, AdaptationConfidence.high);
      expect(
        result.confidenceFindings,
        contains(
          AdaptationConfidenceFindingCode
              .minimumViableDurationPresentForTimeDecision,
        ),
      );
    });

    test('3 missing minimum viable during time constraint → low confidence', () {
      final draft = programmeSession(
        protocolId: 'm2b-conf-min',
        name: 'No min',
        programmeVersionId: testProgrammeVersionId,
        ownerId: 'dev-coach',
        durationMin: 60,
        primarySessionIntent: SessionIntent.upperBodyStrength,
        minimumViableDurationMin: null,
        validateAdaptationMetadata: false,
        blocks: taggedSession.blocks,
      );
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext(availableDurationMin: 40),
      );
      expect(result.adaptationConfidence, AdaptationConfidence.low);
      expect(
        result.confidenceFindings,
        contains(
          AdaptationConfidenceFindingCode
              .minimumViableDurationMissingForTimeDecision,
        ),
      );
    });

    test('4 missing primary intent → low confidence', () {
      final draft = programmeSession(
        protocolId: 'm2b-conf-intent',
        name: 'No intent',
        programmeVersionId: testProgrammeVersionId,
        ownerId: 'dev-coach',
        durationMin: 60,
        primarySessionIntent: null,
        minimumViableDurationMin: 35,
        validateAdaptationMetadata: false,
        blocks: taggedSession.blocks,
      );
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext.empty(),
      );
      expect(result.adaptationConfidence, AdaptationConfidence.low);
      expect(
        result.confidenceFindings,
        contains(AdaptationConfidenceFindingCode.primarySessionIntentMissing),
      );
    });

    test('5 all derived block policies with complete metadata → moderate', () {
      final draft = programmeSession(
        protocolId: 'm2b-conf-derived',
        name: 'Derived only',
        programmeVersionId: testProgrammeVersionId,
        ownerId: 'dev-coach',
        durationMin: 60,
        primarySessionIntent: SessionIntent.upperBodyStrength,
        minimumViableDurationMin: 35,
        blocks: [
          block(type: SessionBlockType.warmUp, content: 'Prep'),
          block(
            type: SessionBlockType.strength,
            linkedExercises: [exerciseLink(exerciseId: 'BP-001', position: 1)],
          ),
          block(type: SessionBlockType.accessory),
        ],
      );
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext.empty(),
      );
      expect(result.adaptationConfidence, AdaptationConfidence.moderate);
      expect(
        result.confidenceFindings,
        contains(
          AdaptationConfidenceFindingCode.derivedBlockAdaptationDefaultsInUse,
        ),
      );
      expect(
        result.confidenceFindings,
        isNot(
          contains(
            AdaptationConfidenceFindingCode.explicitBlockAdaptationMetadataInUse,
          ),
        ),
      );
    });

    test('6 missing irrelevant metadata does not lower confidence', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext.empty(),
        exerciseMetadataById: const {},
      );
      expect(result.adaptationConfidence, AdaptationConfidence.high);
    });

    test('7 missing metadata for active constraint → low confidence', () {
      final result = evaluateDraft(
        taggedSession,
        constraints: AdaptationConstraintContext(
          availableEquipment: {'barbell'},
        ),
      );
      expect(result.adaptationConfidence, AdaptationConfidence.low);
      expect(
        result.confidenceFindings,
        contains(
          AdaptationConfidenceFindingCode.activeConstraintMetadataIncomplete,
        ),
      );
    });

    test('8 confirmed equipment mismatch with complete metadata → high', () {
      final draft = taggedSession.copyWith(requiredEquipment: 'barbell,rack');
      final result = evaluateDraft(
        draft,
        constraints: AdaptationConstraintContext(
          availableEquipment: {'dumbbells'},
        ),
      );
      expect(result.outcome, AdaptationEvaluationOutcome.notAdaptable);
      expect(result.adaptationConfidence, AdaptationConfidence.high);
    });

    test('9 same input returns same confidence', () {
      final input = plannedInputFromDraft(taggedSession);
      const constraints = AdaptationConstraintContext(availableDurationMin: 45);
      final first = evaluator.evaluate(session: input, constraints: constraints);
      final second = evaluator.evaluate(session: input, constraints: constraints);
      expect(first.adaptationConfidence, second.adaptationConfidence);
      expect(first.confidenceFindings, second.confidenceFindings);
    });

    test('10 code vs builder equivalent confidence', () {
      const protocolId = 'm2b-conf-equiv';
      final code = buildTaggedSessionViaCode(
        protocolId: protocolId,
        programmeVersionId: testProgrammeVersionId,
      );
      final visual = buildTaggedSessionViaVisualBuilder(
        protocolId: protocolId,
        programmeVersionId: testProgrammeVersionId,
      );
      final constraints = AdaptationConstraintContext(availableDurationMin: 45);
      final codeResult = evaluateDraft(code, constraints: constraints);
      final visualResult = evaluateDraft(visual, constraints: constraints);
      expect(codeResult.adaptationConfidence, visualResult.adaptationConfidence);
      expect(
        codeResult.confidenceFindings.toSet(),
        visualResult.confidenceFindings.toSet(),
      );
    });
  });
}
