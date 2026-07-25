import '../contracts/adaptation_constraint_kind.dart';
import '../mapping/session_block_type_adaptation_policy.dart';
import '../vocabulary/adaptation_action_type.dart';
import '../vocabulary/adaptation_confidence.dart';
import '../vocabulary/adaptation_fidelity.dart';
import '../vocabulary/block_priority.dart';
import '../vocabulary/impact_level.dart';
import '../vocabulary/training_environment.dart';
import 'adaptation_constraint_context.dart';
import 'adaptation_evaluation_result.dart';
import 'planned_session_adaptation_input_factory.dart';

/// Deterministic, read-only feasibility analysis for planned sessions.
///
/// Does not mutate sessions, generate adapted plans, or persist results.
class SessionAdaptationReadOnlyEvaluator {
  const SessionAdaptationReadOnlyEvaluator();

  SessionAdaptationEvaluationResult evaluate({
    required PlannedSessionAdaptationInput session,
    required AdaptationConstraintContext constraints,
  }) {
    final validatedConstraints = constraints.validated();
    final findings = <AdaptationEvaluationFinding>[];
    final missingMetadata = <AdaptationEvaluationFindingCode>{};
    final diagnostics = _EvaluationDiagnostics();

    if (validatedConstraints.isEmpty) {
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.noConstraintConflict,
          confidence: AdaptationFindingConfidence.confirmedCompatible,
        ),
      );
    }

    final primaryKnown = session.primarySessionIntent != null;
    if (!primaryKnown) {
      missingMetadata.add(AdaptationEvaluationFindingCode.missingSessionIntent);
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.missingSessionIntent,
          confidence: AdaptationFindingConfidence.unknown,
          message: 'Primary session intent is not authored.',
        ),
      );
    }

    for (final extension in validatedConstraints.extensions) {
      if (extension.kind == AdaptationConstraintKind.unknown) {
        findings.add(
          const AdaptationEvaluationFinding(
            code: AdaptationEvaluationFindingCode.noConstraintConflict,
            confidence: AdaptationFindingConfidence.unknown,
            message: 'Unsupported constraint extension ignored.',
          ),
        );
      }
    }

    final timeAnalysis = _analyzeTime(session, validatedConstraints, findings, missingMetadata);
    final blockResults = _evaluateBlocks(session, timeAnalysis, findings);
    _evaluateEquipment(session, validatedConstraints, findings, missingMetadata);
    _evaluateEnvironment(
      session,
      validatedConstraints,
      findings,
      missingMetadata,
      diagnostics,
    );
    _evaluateImpact(session, validatedConstraints, findings, missingMetadata, diagnostics);
    _evaluateMovementRestrictions(
      session,
      validatedConstraints,
      findings,
      missingMetadata,
    );

    final actionSets = _deriveActionPermissions(
      session: session,
      blockResults: blockResults,
      timeAnalysis: timeAnalysis,
      findings: findings,
    );

    final primaryPreservable = primaryKnown &&
        timeAnalysis.primaryIntentPreservable &&
        !findings.any(
          (f) =>
              f.confidence == AdaptationFindingConfidence.confirmedIncompatible &&
              (f.code == AdaptationEvaluationFindingCode.insufficientDuration ||
                  f.code == AdaptationEvaluationFindingCode.impactConflict ||
                  f.code == AdaptationEvaluationFindingCode.movementRestrictionConflict),
        );

    final expectedFidelity = _expectedFidelity(
      primaryKnown: primaryKnown,
      primaryPreservable: primaryPreservable,
      timeAnalysis: timeAnalysis,
      missingMetadata: missingMetadata,
    );

    final outcome = _deriveOutcome(
      constraints: validatedConstraints,
      timeAnalysis: timeAnalysis,
      primaryKnown: primaryKnown,
      primaryPreservable: primaryPreservable,
      missingMetadata: missingMetadata,
      findings: findings,
      expectedFidelity: expectedFidelity,
    );

    final confidenceAssessment = _deriveAdaptationConfidence(
      session: session,
      constraints: validatedConstraints,
      timeAnalysis: timeAnalysis,
      primaryKnown: primaryKnown,
      missingMetadata: missingMetadata,
      blockResults: blockResults,
      diagnostics: diagnostics,
    );

    return SessionAdaptationEvaluationResult(
      outcome: outcome,
      primaryIntentKnown: primaryKnown,
      primaryIntentPreservable: primaryPreservable,
      minimumScope: timeAnalysis.minimumScope,
      expectedFidelity: expectedFidelity,
      adaptationConfidence: confidenceAssessment.level,
      permittedAdaptationActions: actionSets.permitted,
      blockedAdaptationActions: actionSets.blocked,
      findings: List.unmodifiable(findings),
      missingMetadata: missingMetadata.toList()..sort((a, b) => a.name.compareTo(b.name)),
      confidenceFindings: confidenceAssessment.findings,
      blockResults: blockResults,
    );
  }

  _TimeAnalysis _analyzeTime(
    PlannedSessionAdaptationInput session,
    AdaptationConstraintContext constraints,
    List<AdaptationEvaluationFinding> findings,
    Set<AdaptationEvaluationFindingCode> missingMetadata,
  ) {
    final available = constraints.availableDurationMin;
    final planned = session.plannedDurationMin;
    final minViable = session.minimumViableDurationMin;

    if (available == null) {
      return _TimeAnalysis(
        requiresShortening: false,
        primaryIntentPreservable: session.primarySessionIntent != null,
        minimumScope: AdaptationMinimumScope.none,
      );
    }

    if (planned == null) {
      missingMetadata.add(AdaptationEvaluationFindingCode.missingMinimumViableDuration);
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.missingMinimumViableDuration,
          confidence: AdaptationFindingConfidence.unknown,
          message: 'Planned duration unknown; time comparison is uncertain.',
        ),
      );
      return _TimeAnalysis(
        requiresShortening: true,
        primaryIntentPreservable: false,
        minimumScope: AdaptationMinimumScope.blockReduction,
      );
    }

    if (available >= planned) {
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.timeFeasibleWithoutShortening,
          confidence: AdaptationFindingConfidence.confirmedCompatible,
        ),
      );
      return _TimeAnalysis(
        requiresShortening: false,
        primaryIntentPreservable: true,
        minimumScope: AdaptationMinimumScope.none,
      );
    }

    if (minViable == null) {
      missingMetadata.add(AdaptationEvaluationFindingCode.missingMinimumViableDuration);
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.missingMinimumViableDuration,
          confidence: AdaptationFindingConfidence.unknown,
          message:
              'Available time is below planned duration; minimum viable duration is not authored.',
        ),
      );
      return _TimeAnalysis(
        requiresShortening: true,
        primaryIntentPreservable: false,
        minimumScope: AdaptationMinimumScope.blockReduction,
      );
    }

    if (available >= minViable) {
      findings.add(
        AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.insufficientDuration,
          confidence: AdaptationFindingConfidence.unknown,
          message:
              'Available $available min is below planned $planned min but at or above minimum viable $minViable min; shortening may be possible.',
        ),
      );
      return _TimeAnalysis(
        requiresShortening: true,
        primaryIntentPreservable: true,
        minimumScope: AdaptationMinimumScope.blockReduction,
      );
    }

    findings.add(
      AdaptationEvaluationFinding(
        code: AdaptationEvaluationFindingCode.insufficientDuration,
        confidence: AdaptationFindingConfidence.confirmedIncompatible,
        message:
            'Available $available min is below minimum viable $minViable min.',
      ),
    );
    return _TimeAnalysis(
      requiresShortening: true,
      primaryIntentPreservable: false,
      minimumScope: AdaptationMinimumScope.sessionReplacement,
    );
  }

  List<BlockAdaptationEvaluation> _evaluateBlocks(
    PlannedSessionAdaptationInput session,
    _TimeAnalysis timeAnalysis,
    List<AdaptationEvaluationFinding> findings,
  ) {
    return session.blocks.map((block) {
      final blockType =
          PlannedSessionAdaptationInputFactory.blockTypeFromDb(block.blockTypeDbValue);
      final derivedPriority =
          SessionBlockTypeAdaptationPolicy.defaultPriority(blockType);
      final derivedPolicy =
          SessionBlockTypeAdaptationPolicy.defaultAdaptationPolicy(blockType);
      final explicitPriority = block.explicitPriority;
      final explicitPolicy = block.explicitPolicy;
      final policySource = explicitPolicy != null
          ? AdaptationPolicySource.explicit
          : AdaptationPolicySource.derived;
      final effectivePriority = explicitPriority ?? derivedPriority;
      final effectivePolicy = explicitPolicy ?? derivedPolicy;

      final blockFindings = <AdaptationEvaluationFinding>[
        AdaptationEvaluationFinding(
          code: policySource == AdaptationPolicySource.explicit
              ? AdaptationEvaluationFindingCode.explicitPolicyInUse
              : AdaptationEvaluationFindingCode.derivedPolicyInUse,
          confidence: AdaptationFindingConfidence.confirmedCompatible,
          blockLocalId: block.localId,
        ),
      ];

      final removalPermitted = effectivePolicy.canRemove;
      final essentialBlocksNotRemovable =
          effectivePriority == BlockPriority.essential;

      if (!removalPermitted) {
        blockFindings.add(
          AdaptationEvaluationFinding(
            code: AdaptationEvaluationFindingCode.adaptationPolicyPreventsRemoval,
            confidence: AdaptationFindingConfidence.confirmedIncompatible,
            blockLocalId: block.localId,
          ),
        );
      }

      if (essentialBlocksNotRemovable && timeAnalysis.requiresShortening) {
        blockFindings.add(
          AdaptationEvaluationFinding(
            code: AdaptationEvaluationFindingCode.essentialBlockAtRisk,
            confidence: AdaptationFindingConfidence.confirmedIncompatible,
            blockLocalId: block.localId,
            message: 'Essential block cannot be assumed removable under time pressure.',
          ),
        );
        findings.add(blockFindings.last);
      }

      findings.addAll(blockFindings);

      return BlockAdaptationEvaluation(
        blockLocalId: block.localId,
        effectivePriority: effectivePriority,
        explicitPriority: explicitPriority,
        effectivePolicy: effectivePolicy,
        explicitPolicy: explicitPolicy,
        policySource: policySource,
        removalPermittedByPolicy: removalPermitted,
        removalBlockedByEssentialPriority: essentialBlocksNotRemovable,
        findings: blockFindings,
      );
    }).toList(growable: false);
  }

  void _evaluateEquipment(
    PlannedSessionAdaptationInput session,
    AdaptationConstraintContext constraints,
    List<AdaptationEvaluationFinding> findings,
    Set<AdaptationEvaluationFindingCode> missingMetadata,
  ) {
    if (!constraints.hasEquipmentConstraint) return;

    if (session.requiredEquipmentTokens.isEmpty) {
      missingMetadata.add(AdaptationEvaluationFindingCode.equipmentMetadataMissing);
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.equipmentMetadataMissing,
          confidence: AdaptationFindingConfidence.unknown,
        ),
      );
      return;
    }

    final available = constraints.availableEquipment
        .map(_normalizeToken)
        .toSet();
    for (final required in session.requiredEquipmentTokens) {
      if (!available.contains(_normalizeToken(required))) {
        findings.add(
          AdaptationEvaluationFinding(
            code: AdaptationEvaluationFindingCode.equipmentMismatch,
            confidence: AdaptationFindingConfidence.confirmedIncompatible,
            message: 'Missing required equipment: $required',
          ),
        );
        return;
      }
    }

    findings.add(
      const AdaptationEvaluationFinding(
        code: AdaptationEvaluationFindingCode.equipmentCompatible,
        confidence: AdaptationFindingConfidence.confirmedCompatible,
      ),
    );
  }

  void _evaluateEnvironment(
    PlannedSessionAdaptationInput session,
    AdaptationConstraintContext constraints,
    List<AdaptationEvaluationFinding> findings,
    Set<AdaptationEvaluationFindingCode> missingMetadata,
    _EvaluationDiagnostics diagnostics,
  ) {
    final env = constraints.trainingEnvironment;
    if (env == null) return;

    final hasSessionEnvMetadata = (session.sessionEnvironmentLabel != null &&
            session.sessionEnvironmentLabel!.trim().isNotEmpty) ||
        session.hotelFriendly != null ||
        session.indoorFriendly != null;

    if (!hasSessionEnvMetadata) {
      missingMetadata.add(AdaptationEvaluationFindingCode.environmentMetadataMissing);
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.environmentMetadataMissing,
          confidence: AdaptationFindingConfidence.unknown,
        ),
      );
      return;
    }

    final compatible = _environmentCompatible(session, env);
    if (session.sessionEnvironmentLabel != null &&
        session.sessionEnvironmentLabel!.trim().isNotEmpty) {
      diagnostics.environmentCompatibilityUsesLabelHeuristic = true;
    }
    findings.add(
      AdaptationEvaluationFinding(
        code: compatible
            ? AdaptationEvaluationFindingCode.environmentCompatible
            : AdaptationEvaluationFindingCode.environmentMismatch,
        confidence: compatible
            ? AdaptationFindingConfidence.confirmedCompatible
            : AdaptationFindingConfidence.confirmedIncompatible,
      ),
    );
  }

  void _evaluateImpact(
    PlannedSessionAdaptationInput session,
    AdaptationConstraintContext constraints,
    List<AdaptationEvaluationFinding> findings,
    Set<AdaptationEvaluationFindingCode> missingMetadata,
    _EvaluationDiagnostics diagnostics,
  ) {
    final max = constraints.maxPermittedImpact;
    if (max == null) return;

    final sessionImpact = session.sessionImpact;
    if (sessionImpact == null) {
      missingMetadata.add(AdaptationEvaluationFindingCode.impactMetadataMissing);
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.impactMetadataMissing,
          confidence: AdaptationFindingConfidence.unknown,
        ),
      );
      return;
    }

    if (session.physiologicalDemandLabel != null &&
        session.physiologicalDemandLabel!.trim().isNotEmpty) {
      diagnostics.sessionImpactInferredFromDemandLabel = true;
    }

    if (_impactRank(sessionImpact) > _impactRank(max)) {
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.impactConflict,
          confidence: AdaptationFindingConfidence.confirmedIncompatible,
        ),
      );
    }
  }

  void _evaluateMovementRestrictions(
    PlannedSessionAdaptationInput session,
    AdaptationConstraintContext constraints,
    List<AdaptationEvaluationFinding> findings,
    Set<AdaptationEvaluationFindingCode> missingMetadata,
  ) {
    if (!constraints.hasMovementRestrictions) return;

    var evaluatedAny = false;
    for (final block in session.blocks) {
      for (final exerciseId in block.linkedExerciseIds) {
        if (constraints.excludedExerciseIds.contains(exerciseId)) {
          findings.add(
            AdaptationEvaluationFinding(
              code: AdaptationEvaluationFindingCode.movementRestrictionConflict,
              confidence: AdaptationFindingConfidence.confirmedIncompatible,
              exerciseId: exerciseId,
              blockLocalId: block.localId,
            ),
          );
          evaluatedAny = true;
          continue;
        }

        final metadata = session.exerciseMetadataById[exerciseId];
        if (metadata == null) {
          continue;
        }
        evaluatedAny = true;

        for (final pattern in metadata.movementPatterns) {
          if (constraints.restrictedMovementPatterns.contains(pattern)) {
            findings.add(
              AdaptationEvaluationFinding(
                code: AdaptationEvaluationFindingCode.movementRestrictionConflict,
                confidence: AdaptationFindingConfidence.confirmedIncompatible,
                exerciseId: exerciseId,
                blockLocalId: block.localId,
              ),
            );
          }
        }

        final region = metadata.bodyRegion?.trim().toLowerCase();
        if (region != null &&
            region.isNotEmpty &&
            constraints.restrictedBodyRegions
                .map((r) => r.toLowerCase())
                .contains(region)) {
          findings.add(
            AdaptationEvaluationFinding(
              code: AdaptationEvaluationFindingCode.movementRestrictionConflict,
              confidence: AdaptationFindingConfidence.confirmedIncompatible,
              exerciseId: exerciseId,
              blockLocalId: block.localId,
            ),
          );
        }
      }
    }

    if (!evaluatedAny &&
        session.blocks.any((b) => b.linkedExerciseIds.isNotEmpty)) {
      missingMetadata.add(AdaptationEvaluationFindingCode.movementMetadataMissing);
      findings.add(
        const AdaptationEvaluationFinding(
          code: AdaptationEvaluationFindingCode.movementMetadataMissing,
          confidence: AdaptationFindingConfidence.unknown,
        ),
      );
    }
  }

  _ActionSets _deriveActionPermissions({
    required PlannedSessionAdaptationInput session,
    required List<BlockAdaptationEvaluation> blockResults,
    required _TimeAnalysis timeAnalysis,
    required List<AdaptationEvaluationFinding> findings,
  }) {
    final permitted = <AdaptationActionType>{};
    final blocked = <AdaptationActionType>{};

    for (final type in AdaptationActionType.values) {
      permitted.add(type);
    }

    if (!timeAnalysis.requiresShortening) {
      blocked.addAll({
        AdaptationActionType.shortenDuration,
        AdaptationActionType.removeBlock,
        AdaptationActionType.replaceBlock,
        AdaptationActionType.replaceSession,
      });
    }

    final anyRemovableBlock = blockResults.any(
      (b) =>
          b.removalPermittedByPolicy &&
          !b.removalBlockedByEssentialPriority &&
          b.effectivePriority != BlockPriority.essential,
    );

    if (!anyRemovableBlock) {
      blocked.add(AdaptationActionType.removeBlock);
    }

    for (final block in blockResults) {
      final policy = block.effectivePolicy;
      if (!policy.canReduceVolume) blocked.add(AdaptationActionType.reduceVolume);
      if (!policy.canReduceIntensity) {
        blocked.add(AdaptationActionType.reduceIntensity);
      }
      if (!policy.canIncreaseRest) blocked.add(AdaptationActionType.increaseRest);
      if (!policy.canReplaceExercises) {
        blocked.add(AdaptationActionType.swapExercise);
      }
      if (!policy.canReplaceBlock) blocked.add(AdaptationActionType.replaceBlock);
      if (!policy.canRemove) blocked.add(AdaptationActionType.removeBlock);
    }

    if (findings.any(
      (f) => f.code == AdaptationEvaluationFindingCode.adaptationPolicyPreventsRemoval,
    )) {
      blocked.add(AdaptationActionType.removeBlock);
    }

    permitted.removeAll(blocked);

    return _ActionSets(
      permitted: permitted.toList()
        ..sort((a, b) => a.preferenceOrder.compareTo(b.preferenceOrder)),
      blocked: blocked.toList()
        ..sort((a, b) => a.preferenceOrder.compareTo(b.preferenceOrder)),
    );
  }

  AdaptationFidelity _expectedFidelity({
    required bool primaryKnown,
    required bool primaryPreservable,
    required _TimeAnalysis timeAnalysis,
    required Set<AdaptationEvaluationFindingCode> missingMetadata,
  }) {
    if (!primaryKnown ||
        missingMetadata.contains(AdaptationEvaluationFindingCode.missingMinimumViableDuration)) {
      return AdaptationFidelity.compromised;
    }
    if (!primaryPreservable) return AdaptationFidelity.low;
    if (timeAnalysis.requiresShortening) return AdaptationFidelity.moderate;
    return AdaptationFidelity.full;
  }

  AdaptationEvaluationOutcome _deriveOutcome({
    required AdaptationConstraintContext constraints,
    required _TimeAnalysis timeAnalysis,
    required bool primaryKnown,
    required bool primaryPreservable,
    required Set<AdaptationEvaluationFindingCode> missingMetadata,
    required List<AdaptationEvaluationFinding> findings,
    required AdaptationFidelity expectedFidelity,
  }) {
    if (!primaryKnown) {
      return AdaptationEvaluationOutcome.insufficientInformation;
    }

    if (missingMetadata.contains(
          AdaptationEvaluationFindingCode.missingMinimumViableDuration,
        ) &&
        timeAnalysis.requiresShortening) {
      return AdaptationEvaluationOutcome.insufficientInformation;
    }

    final hardIncompatible = findings.any(
      (f) =>
          f.confidence == AdaptationFindingConfidence.confirmedIncompatible &&
          f.code != AdaptationEvaluationFindingCode.insufficientDuration &&
          f.code != AdaptationEvaluationFindingCode.adaptationPolicyPreventsRemoval &&
          f.code != AdaptationEvaluationFindingCode.essentialBlockAtRisk,
    );

    if (hardIncompatible) {
      return AdaptationEvaluationOutcome.notAdaptable;
    }

    if (timeAnalysis.minimumScope == AdaptationMinimumScope.sessionReplacement) {
      return AdaptationEvaluationOutcome.notAdaptable;
    }

    if (constraints.isEmpty && !timeAnalysis.requiresShortening) {
      return AdaptationEvaluationOutcome.noAdaptationRequired;
    }

    if (!timeAnalysis.requiresShortening) {
      return AdaptationEvaluationOutcome.noAdaptationRequired;
    }

    if (expectedFidelity == AdaptationFidelity.low ||
        expectedFidelity == AdaptationFidelity.compromised) {
      return AdaptationEvaluationOutcome.adaptableWithReducedFidelity;
    }

    return AdaptationEvaluationOutcome.adaptable;
  }

  /// Deterministic [AdaptationConfidence] from metadata completeness and
  /// constraint evidence (not from [AdaptationFidelity] or outcome alone).
  ///
  /// **Low:** missing primary intent; time shortening without minimum viable
  /// duration (or planned duration when time is active); any active-constraint
  /// metadata gap (equipment, environment, impact, movement); or two or more
  /// such gaps ([AdaptationConfidenceFindingCode.multipleMaterialUnknowns]).
  ///
  /// **High:** primary intent present; no active-constraint metadata gaps; time
  /// fields sufficient when a time constraint applies; and at least one block
  /// carries explicit adaptation metadata (derived-only block defaults cap at
  /// moderate — they do not force low). Confirmed incompatibilities with
  /// complete metadata remain high confidence.
  ///
  /// **Moderate:** all other supported cases (e.g. derived block defaults with
  /// otherwise complete session metadata).
  _ConfidenceAssessment _deriveAdaptationConfidence({
    required PlannedSessionAdaptationInput session,
    required AdaptationConstraintContext constraints,
    required _TimeAnalysis timeAnalysis,
    required bool primaryKnown,
    required Set<AdaptationEvaluationFindingCode> missingMetadata,
    required List<BlockAdaptationEvaluation> blockResults,
    required _EvaluationDiagnostics diagnostics,
  }) {
    final confidenceFindings = <AdaptationConfidenceFindingCode>[];

    if (primaryKnown) {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode.primarySessionIntentPresent,
      );
    } else {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode.primarySessionIntentMissing,
      );
    }

    final timeConstraintActive = constraints.hasTimeConstraint;
    if (timeConstraintActive) {
      if (session.plannedDurationMin == null) {
        confidenceFindings.add(
          AdaptationConfidenceFindingCode.plannedDurationMissingForTimeDecision,
        );
      }
      if (timeAnalysis.requiresShortening) {
        if (session.minimumViableDurationMin != null) {
          confidenceFindings.add(
            AdaptationConfidenceFindingCode
                .minimumViableDurationPresentForTimeDecision,
          );
        } else {
          confidenceFindings.add(
            AdaptationConfidenceFindingCode
                .minimumViableDurationMissingForTimeDecision,
          );
        }
      }
    }

    final activeMetadataGaps = _activeConstraintMetadataGaps(
      constraints,
      missingMetadata,
    );
    if (activeMetadataGaps.isEmpty) {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode.activeConstraintMetadataComplete,
      );
    } else {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode.activeConstraintMetadataIncomplete,
      );
    }

    final anyExplicitBlock = blockResults.any(
      (b) =>
          b.explicitPolicy != null ||
          b.explicitPriority != null ||
          b.policySource == AdaptationPolicySource.explicit,
    );
    final allBlocksFullyDerived = blockResults.isNotEmpty &&
        blockResults.every(
          (b) =>
              b.explicitPolicy == null &&
              b.explicitPriority == null &&
              b.policySource == AdaptationPolicySource.derived,
        );

    if (anyExplicitBlock) {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode.explicitBlockAdaptationMetadataInUse,
      );
    }
    if (blockResults.any((b) => b.policySource == AdaptationPolicySource.derived)) {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode.derivedBlockAdaptationDefaultsInUse,
      );
    }

    if (diagnostics.sessionImpactInferredFromDemandLabel) {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode
            .sessionImpactInferredFromPhysiologicalDemandLabel,
      );
    }
    if (diagnostics.environmentCompatibilityUsesLabelHeuristic) {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode.environmentCompatibilityUsesLabelHeuristic,
      );
    }

    final lowConfidence = !primaryKnown ||
        (timeConstraintActive && session.plannedDurationMin == null) ||
        (timeAnalysis.requiresShortening &&
            session.minimumViableDurationMin == null) ||
        activeMetadataGaps.isNotEmpty;

    if (activeMetadataGaps.length >= 2) {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode.multipleMaterialUnknowns,
      );
    }

    if (lowConfidence) {
      return _ConfidenceAssessment(
        level: AdaptationConfidence.low,
        findings: _sortedConfidenceFindings(confidenceFindings),
      );
    }

    final highConfidence = primaryKnown &&
        (!timeConstraintActive ||
            (session.plannedDurationMin != null &&
                (!timeAnalysis.requiresShortening ||
                    session.minimumViableDurationMin != null))) &&
        activeMetadataGaps.isEmpty &&
        (anyExplicitBlock || !allBlocksFullyDerived);

    if (highConfidence) {
      confidenceFindings.add(
        AdaptationConfidenceFindingCode.evaluationConclusionsFullySupported,
      );
      return _ConfidenceAssessment(
        level: AdaptationConfidence.high,
        findings: _sortedConfidenceFindings(confidenceFindings),
      );
    }

    return _ConfidenceAssessment(
      level: AdaptationConfidence.moderate,
      findings: _sortedConfidenceFindings(confidenceFindings),
    );
  }

  Set<AdaptationEvaluationFindingCode> _activeConstraintMetadataGaps(
    AdaptationConstraintContext constraints,
    Set<AdaptationEvaluationFindingCode> missingMetadata,
  ) {
    final gaps = <AdaptationEvaluationFindingCode>{};
    if (constraints.hasEquipmentConstraint &&
        missingMetadata.contains(
          AdaptationEvaluationFindingCode.equipmentMetadataMissing,
        )) {
      gaps.add(AdaptationEvaluationFindingCode.equipmentMetadataMissing);
    }
    if (constraints.hasEnvironmentConstraint &&
        missingMetadata.contains(
          AdaptationEvaluationFindingCode.environmentMetadataMissing,
        )) {
      gaps.add(AdaptationEvaluationFindingCode.environmentMetadataMissing);
    }
    if (constraints.hasImpactConstraint &&
        missingMetadata.contains(
          AdaptationEvaluationFindingCode.impactMetadataMissing,
        )) {
      gaps.add(AdaptationEvaluationFindingCode.impactMetadataMissing);
    }
    if (constraints.hasMovementRestrictions &&
        missingMetadata.contains(
          AdaptationEvaluationFindingCode.movementMetadataMissing,
        )) {
      gaps.add(AdaptationEvaluationFindingCode.movementMetadataMissing);
    }
    return gaps;
  }

  List<AdaptationConfidenceFindingCode> _sortedConfidenceFindings(
    List<AdaptationConfidenceFindingCode> findings,
  ) {
    final unique = findings.toSet().toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(unique);
  }

  bool _environmentCompatible(
    PlannedSessionAdaptationInput session,
    TrainingEnvironment environment,
  ) {
    return switch (environment) {
      TrainingEnvironment.home =>
        session.indoorFriendly == true ||
            _envLabelContains(session.sessionEnvironmentLabel, ['home', 'anywhere']),
      TrainingEnvironment.hotelRoom => session.hotelFriendly == true,
      TrainingEnvironment.hotelGym =>
        session.hotelFriendly == true ||
            _envLabelContains(session.sessionEnvironmentLabel, ['hotel']),
      TrainingEnvironment.commercialGym ||
      TrainingEnvironment.fullGym =>
        _envLabelContains(
          session.sessionEnvironmentLabel,
          ['gym', 'full gym', 'commercial', 'anywhere'],
        ),
      TrainingEnvironment.outdoors ||
      TrainingEnvironment.track ||
      TrainingEnvironment.trail =>
        _envLabelContains(
          session.sessionEnvironmentLabel,
          ['outdoor', 'track', 'trail', 'anywhere'],
        ),
      TrainingEnvironment.anywhere => true,
    };
  }

  bool _envLabelContains(String? label, List<String> tokens) {
    final normalized = _normalizeToken(label ?? '');
    if (normalized.isEmpty) return false;
    return tokens.any((token) => normalized.contains(_normalizeToken(token)));
  }

  String _normalizeToken(String value) {
    return value.trim().toLowerCase().replaceAll('_', ' ');
  }

  int _impactRank(ImpactLevel level) {
    return switch (level) {
      ImpactLevel.veryLow => 0,
      ImpactLevel.low => 1,
      ImpactLevel.moderate => 2,
      ImpactLevel.high => 3,
      ImpactLevel.veryHigh => 4,
    };
  }
}

class _TimeAnalysis {
  const _TimeAnalysis({
    required this.requiresShortening,
    required this.primaryIntentPreservable,
    required this.minimumScope,
  });

  final bool requiresShortening;
  final bool primaryIntentPreservable;
  final AdaptationMinimumScope minimumScope;
}

class _ActionSets {
  const _ActionSets({required this.permitted, required this.blocked});

  final List<AdaptationActionType> permitted;
  final List<AdaptationActionType> blocked;
}

class _ConfidenceAssessment {
  const _ConfidenceAssessment({
    required this.level,
    required this.findings,
  });

  final AdaptationConfidence level;
  final List<AdaptationConfidenceFindingCode> findings;
}

class _EvaluationDiagnostics {
  bool environmentCompatibilityUsesLabelHeuristic = false;
  bool sessionImpactInferredFromDemandLabel = false;
}
