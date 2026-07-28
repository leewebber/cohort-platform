import '../evaluation/adaptation_constraint_context.dart';
import '../evaluation/adaptation_evaluation_result.dart';
import '../evaluation/session_adaptation_read_only_evaluator.dart';
import '../planning/adaptation_plan_result.dart';
import '../planning/adaptation_plan_step.dart';
import '../planning/adaptation_plan_validator.dart';
import '../planning/prescription_reduction_proposal.dart';
import '../planning/session_adaptation_planner.dart';
import '../vocabulary/adaptation_action_type.dart';
import '../vocabulary/adaptation_constraint_scope.dart';
import '../vocabulary/block_priority.dart';
import 'adaptation_plan_application_result.dart';
import 'adapted_session_execution_snapshot.dart';
import 'adapted_session_execution_snapshot_validator.dart';
import 'prescription_execution_snapshot.dart';

/// Applies validated [AdaptationPlanResult] to an immutable execution snapshot.
///
/// Never mutates [PlannedSessionAdaptationInput], [ProtocolDraft], or the plan.
class AdaptationPlanApplier {
  const AdaptationPlanApplier({
    this.planValidator = const AdaptationPlanValidator(),
    this.snapshotValidator = const AdaptedSessionExecutionSnapshotValidator(),
    this.evaluator = const SessionAdaptationReadOnlyEvaluator(),
  });

  final AdaptationPlanValidator planValidator;
  final AdaptedSessionExecutionSnapshotValidator snapshotValidator;
  final SessionAdaptationReadOnlyEvaluator evaluator;

  AdaptationPlanApplicationResult apply({
    required PlannedSessionAdaptationInput source,
    required AdaptationPlanResult plan,
    AdaptationConstraintContext? constraints,
    SessionAdaptationEvaluationResult? evaluation,
  }) {
    if (plan.sourceSessionId.trim() != source.protocolId.trim()) {
      return const AdaptationPlanApplicationResult(
        status: AdaptationPlanApplicationStatus.rejectedSourceMismatch,
        issues: [
          AdaptationPlanApplicationIssue(
            code: AdaptationPlanApplicationIssueCode.sourceSessionMismatch,
          ),
        ],
      );
    }

    final resolvedConstraints =
        constraints ?? AdaptationConstraintContext.empty();
    final resolvedEvaluation = evaluation ??
        evaluator.evaluate(
          session: source,
          constraints: resolvedConstraints.validated(),
        );

    final planValidation = planValidator.validate(
      session: source,
      evaluation: resolvedEvaluation,
      plan: plan,
    );
    if (!planValidation.isValid) {
      return const AdaptationPlanApplicationResult(
        status: AdaptationPlanApplicationStatus.rejectedInvalidPlan,
        issues: [
          AdaptationPlanApplicationIssue(
            code: AdaptationPlanApplicationIssueCode.planValidationFailed,
          ),
        ],
      );
    }

    if (plan.status == AdaptationPlanStatus.noPlanRequired) {
      final snapshot = _buildUnadaptedSnapshot(source: source, plan: plan);
      return _validateAndWrap(source, plan, snapshot);
    }

    if (!plan.isApplicable) {
      return const AdaptationPlanApplicationResult(
        status: AdaptationPlanApplicationStatus.rejectedInvalidPlan,
        issues: [
          AdaptationPlanApplicationIssue(
            code: AdaptationPlanApplicationIssueCode.planNotApplicable,
          ),
        ],
      );
    }

    final state = _ApplicationState.fromSource(source);
    final issues = <AdaptationPlanApplicationIssue>[];
    final sortedSteps = List<AdaptationPlanStep>.from(plan.steps)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    for (final step in sortedSteps) {
      final stepResult = _applyStep(
        source: source,
        state: state,
        step: step,
      );
      if (stepResult != null) {
        issues.add(stepResult);
        return AdaptationPlanApplicationResult(
          status: stepResult.code == AdaptationPlanApplicationIssueCode.unsupportedActionType
              ? AdaptationPlanApplicationStatus.unsupportedPlanStep
              : AdaptationPlanApplicationStatus.applicationFailed,
          issues: issues,
        );
      }
    }

    final snapshot = _buildAdaptedSnapshot(
      source: source,
      plan: plan,
      state: state,
    );
    return _validateAndWrap(source, plan, snapshot);
  }

  AdaptationPlanApplicationResult _validateAndWrap(
    PlannedSessionAdaptationInput source,
    AdaptationPlanResult plan,
    AdaptedSessionExecutionSnapshot snapshot,
  ) {
    final validation = snapshotValidator.validate(
      source: source,
      plan: plan,
      snapshot: snapshot,
    );
    if (!validation.isValid) {
      return AdaptationPlanApplicationResult(
        status: AdaptationPlanApplicationStatus.applicationFailed,
        issues: validation.issues
            .map(
              (issue) => AdaptationPlanApplicationIssue(
                code: AdaptationPlanApplicationIssueCode.snapshotValidationFailed,
                detail: issue.code.name,
              ),
            )
            .toList(growable: false),
      );
    }

    final status = plan.status == AdaptationPlanStatus.noPlanRequired
        ? AdaptationPlanApplicationStatus.noAdaptationRequired
        : AdaptationPlanApplicationStatus.applied;

    return AdaptationPlanApplicationResult(
      status: status,
      snapshot: snapshot,
    );
  }

  AdaptationPlanApplicationIssue? _applyStep({
    required PlannedSessionAdaptationInput source,
    required _ApplicationState state,
    required AdaptationPlanStep step,
  }) {
    return switch (step.actionType) {
      AdaptationActionType.reduceVolume => _applyReduceVolume(source, state, step),
      AdaptationActionType.removeBlock => _applyRemoveBlock(source, state, step),
      _ => AdaptationPlanApplicationIssue(
          code: AdaptationPlanApplicationIssueCode.unsupportedActionType,
          planStepSequence: step.sequence,
        ),
    };
  }

  AdaptationPlanApplicationIssue? _applyReduceVolume(
    PlannedSessionAdaptationInput source,
    _ApplicationState state,
    AdaptationPlanStep step,
  ) {
    final reduction = step.prescriptionReduction;
    if (reduction == null ||
        reduction.kind != PrescriptionReductionKind.setCount) {
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.unsupportedActionType,
        planStepSequence: step.sequence,
      );
    }

    final blockId = step.blockLocalId;
    if (blockId == null || !state.retained.containsKey(blockId)) {
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.unknownBlockTarget,
        planStepSequence: step.sequence,
      );
    }

    final blockState = state.retained[blockId]!;
    final resolved = SessionAdaptationPlanner.resolveBlock(blockState.input);
    if (step.policySource != blockState.policySource) {
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.policyMismatch,
        planStepSequence: step.sequence,
      );
    }

    if (!resolved.effectivePolicy.canReduceVolume) {
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.policyMismatch,
        planStepSequence: step.sequence,
      );
    }

    final linkId = step.exerciseLinkLocalId ?? step.targetId;
    final exercise = blockState.exercises[linkId];
    if (exercise == null) {
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.unknownExerciseTarget,
        planStepSequence: step.sequence,
      );
    }

    final currentSets = exercise.execution.sets;
    if (currentSets == null || currentSets != reduction.originalValue) {
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.stalePrescriptionOriginalValue,
        planStepSequence: step.sequence,
        detail: 'expected=${reduction.originalValue} actual=$currentSets',
      );
    }

    if (reduction.proposedValue >= reduction.originalValue ||
        reduction.proposedValue <= 0 ||
        !reduction.isValid) {
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.prescriptionVolumeIncrease,
        planStepSequence: step.sequence,
      );
    }

    final minSets = blockState.input.policyMinimumViablePrescription?.sets ??
        resolved.effectivePolicy.minimumViablePrescription?.sets ??
        1;
    if (reduction.proposedValue < minSets) {
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.prescriptionBelowMinimum,
        planStepSequence: step.sequence,
      );
    }

    blockState.exercises[linkId] = _ExerciseState(
      linkLocalId: linkId,
      exerciseId: exercise.exerciseId,
      original: exercise.original,
      execution: exercise.execution.copyWith(sets: reduction.proposedValue),
      adapted: true,
      stepSequences: [...exercise.stepSequences, step.sequence],
    );
    blockState.adapted = true;
    blockState.stepSequences.add(step.sequence);

    state.audit.add(
      AdaptationStepAuditEntry(
        planStepSequence: step.sequence,
        actionType: step.actionType,
        targetScopeDbValue: step.targetScope.dbValue,
        targetId: step.targetId,
        blockLocalId: blockId,
        exerciseLinkLocalId: linkId,
        rationaleCode: step.rationaleCode,
        originalValueReference: step.originalValueReference,
        appliedValueReference: step.proposedValueReference,
        expectedTimeSavingMinutes: step.expectedTimeSavingMinutes,
        expectedTimeSavingUnknown: step.expectedTimeSavingUnknown,
        policySource: step.policySource,
        effectOnFidelity: step.effectOnFidelity,
        applicationStatus: AdaptationStepApplicationStatus.applied,
      ),
    );
    return null;
  }

  AdaptationPlanApplicationIssue? _applyRemoveBlock(
    PlannedSessionAdaptationInput source,
    _ApplicationState state,
    AdaptationPlanStep step,
  ) {
    final blockId = step.blockLocalId ?? step.targetId;
    if (!state.retained.containsKey(blockId)) {
      if (state.omittedIds.contains(blockId)) {
        return AdaptationPlanApplicationIssue(
          code: AdaptationPlanApplicationIssueCode.duplicateBlockRemoval,
          planStepSequence: step.sequence,
        );
      }
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.unknownBlockTarget,
        planStepSequence: step.sequence,
      );
    }

    final blockState = state.retained.remove(blockId)!;
    final resolved = SessionAdaptationPlanner.resolveBlock(blockState.input);

    if (resolved.effectivePriority == BlockPriority.essential) {
      state.retained[blockId] = blockState;
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.essentialBlockRemoval,
        planStepSequence: step.sequence,
      );
    }

    if (!resolved.effectivePolicy.canRemove) {
      state.retained[blockId] = blockState;
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.removalNotPermitted,
        planStepSequence: step.sequence,
      );
    }

    if (step.policySource != blockState.policySource) {
      state.retained[blockId] = blockState;
      return AdaptationPlanApplicationIssue(
        code: AdaptationPlanApplicationIssueCode.policyMismatch,
        planStepSequence: step.sequence,
      );
    }

    state.omittedIds.add(blockId);
    state.omitted.add(
      OmittedBlockExecutionRecord(
        sourceBlockLocalId: blockId,
        sourcePosition: blockState.input.position,
        blockTypeDbValue: blockState.input.blockTypeDbValue,
        omissionAction: AdaptationActionType.removeBlock,
        rationaleCode: step.rationaleCode,
        policySource: step.policySource,
        planStepSequence: step.sequence,
        capturedExercises: blockState.exercises.values
            .map(
              (e) => ExerciseExecutionSnapshot(
                exerciseLinkLocalId: e.linkLocalId,
                exerciseId: e.exerciseId,
                originalPrescription: e.original,
                executionPrescription: e.execution,
                adapted: e.adapted,
                appliedPlanStepSequences: List.unmodifiable(e.stepSequences),
              ),
            )
            .toList(growable: false),
      ),
    );

    state.audit.add(
      AdaptationStepAuditEntry(
        planStepSequence: step.sequence,
        actionType: step.actionType,
        targetScopeDbValue: step.targetScope.dbValue,
        targetId: step.targetId,
        blockLocalId: blockId,
        rationaleCode: step.rationaleCode,
        originalValueReference: step.originalValueReference,
        appliedValueReference: step.proposedValueReference,
        expectedTimeSavingMinutes: step.expectedTimeSavingMinutes,
        expectedTimeSavingUnknown: step.expectedTimeSavingUnknown,
        policySource: step.policySource,
        effectOnFidelity: step.effectOnFidelity,
        applicationStatus: AdaptationStepApplicationStatus.applied,
      ),
    );
    return null;
  }

  AdaptedSessionExecutionSnapshot _buildUnadaptedSnapshot({
    required PlannedSessionAdaptationInput source,
    required AdaptationPlanResult plan,
  }) {
    final state = _ApplicationState.fromSource(source);
    return _buildAdaptedSnapshot(source: source, plan: plan, state: state);
  }

  AdaptedSessionExecutionSnapshot _buildAdaptedSnapshot({
    required PlannedSessionAdaptationInput source,
    required AdaptationPlanResult plan,
    required _ApplicationState state,
  }) {
    final retained = state.retained.values.toList()
      ..sort((a, b) => a.input.position.compareTo(b.input.position));

    final retainedSnapshots = retained
        .map(
          (block) => BlockExecutionSnapshot(
            sourceBlockLocalId: block.input.localId,
            sourcePosition: block.input.position,
            blockTypeDbValue: block.input.blockTypeDbValue,
            effectivePriority: SessionAdaptationPlanner.resolveBlock(block.input)
                .effectivePriority,
            effectivePolicy: SessionAdaptationPlanner.resolveBlock(block.input)
                .effectivePolicy,
            policySource: block.policySource,
            exercises: block.exercises.values
                .map(
                  (e) => ExerciseExecutionSnapshot(
                    exerciseLinkLocalId: e.linkLocalId,
                    exerciseId: e.exerciseId,
                    originalPrescription: e.original,
                    executionPrescription: e.execution,
                    adapted: e.adapted,
                    appliedPlanStepSequences: List.unmodifiable(e.stepSequences),
                  ),
                )
                .toList(growable: false),
            adapted: block.adapted,
            appliedPlanStepSequences: List.unmodifiable(block.stepSequences),
          ),
        )
        .toList(growable: false);

    final duration = _estimateResultingDuration(retained, state.audit);

    return AdaptedSessionExecutionSnapshot(
      snapshotId: _deterministicSnapshotId(source, plan),
      sourceProtocolId: source.protocolId,
      status: AdaptedSessionExecutionSnapshotStatus.ready,
      originalPlannedDurationMin: source.plannedDurationMin,
      resultingEstimatedDurationMin: duration.minutes,
      durationEstimateReliable: duration.reliable,
      primarySessionIntent: source.primarySessionIntent,
      secondarySessionIntents: source.secondarySessionIntents,
      retainedBlocks: retainedSnapshots,
      omittedBlocks: List.unmodifiable(state.omitted),
      appliedAdaptationAudit: List.unmodifiable(state.audit),
      expectedFidelity: plan.expectedFidelity,
      adaptationConfidence: plan.adaptationConfidence,
      evaluationOutcome: plan.evaluationOutcome,
      planStatus: plan.status,
      unresolvedConstraints: plan.unresolvedConstraints,
      exactDurationFeasibilityConfirmed: plan.exactDurationFeasibilityConfirmed &&
          duration.reliable,
      unresolvedDurationDeficitMinutes: plan.unresolvedDurationDeficitMinutes,
      planFindings: plan.planFindings,
    );
  }

  _DurationEstimate _estimateResultingDuration(
    List<_BlockState> retained,
    List<AdaptationStepAuditEntry> audit,
  ) {
    var total = 0;
    var reliable = true;
    for (final block in retained) {
      final minutes = block.input.estimatedDurationMinutes;
      if (minutes == null || block.input.estimatedDurationUnknown) {
        reliable = false;
        continue;
      }
      var blockMinutes = minutes;
      for (final entry in audit) {
        if (entry.blockLocalId == block.input.localId &&
            !entry.expectedTimeSavingUnknown &&
            entry.expectedTimeSavingMinutes != null) {
          blockMinutes -= entry.expectedTimeSavingMinutes!;
        }
      }
      total += blockMinutes.clamp(0, minutes);
    }
    if (retained.isEmpty) {
      reliable = false;
    }
    return _DurationEstimate(
      minutes: reliable ? total : null,
      reliable: reliable,
    );
  }

  String _deterministicSnapshotId(
    PlannedSessionAdaptationInput source,
    AdaptationPlanResult plan,
  ) {
    final stepSig = plan.steps
        .map((s) => '${s.sequence}:${s.actionType.name}:${s.targetId}')
        .join('|');
    return '${source.protocolId}::${plan.status.name}::$stepSig';
  }
}

class _DurationEstimate {
  const _DurationEstimate({required this.minutes, required this.reliable});
  final int? minutes;
  final bool reliable;
}

class _ExerciseState {
  _ExerciseState({
    required this.linkLocalId,
    required this.exerciseId,
    required this.original,
    required this.execution,
    required this.adapted,
    required this.stepSequences,
  });

  final String linkLocalId;
  final String exerciseId;
  final PrescriptionExecutionSnapshot original;
  final PrescriptionExecutionSnapshot execution;
  final bool adapted;
  final List<int> stepSequences;
}

class _BlockState {
  _BlockState({
    required this.input,
    required this.policySource,
    required this.exercises,
  });

  final PlannedBlockAdaptationInput input;
  final AdaptationPolicySource policySource;
  final Map<String, _ExerciseState> exercises;
  bool adapted = false;
  final List<int> stepSequences = [];
}

class _ApplicationState {
  _ApplicationState({
    required this.retained,
    required this.omitted,
    required this.omittedIds,
    required this.audit,
  });

  final Map<String, _BlockState> retained;
  final List<OmittedBlockExecutionRecord> omitted;
  final Set<String> omittedIds;
  final List<AdaptationStepAuditEntry> audit;

  factory _ApplicationState.fromSource(PlannedSessionAdaptationInput source) {
    final retained = <String, _BlockState>{};
    final blocks = List<PlannedBlockAdaptationInput>.from(source.blocks)
      ..sort((a, b) => a.position.compareTo(b.position));

    for (final block in blocks) {
      final exercises = <String, _ExerciseState>{};
      for (final rx in block.exercisePrescriptions) {
        final snap = PrescriptionExecutionSnapshot(
          sets: rx.sets,
          reps: rx.reps,
          restSeconds: rx.restSeconds,
        );
        exercises[rx.exerciseLinkLocalId] = _ExerciseState(
          linkLocalId: rx.exerciseLinkLocalId,
          exerciseId: rx.exerciseId,
          original: snap,
          execution: snap,
          adapted: false,
          stepSequences: [],
        );
      }
      retained[block.localId] = _BlockState(
        input: block,
        policySource: block.explicitPolicy != null
            ? AdaptationPolicySource.explicit
            : AdaptationPolicySource.derived,
        exercises: exercises,
      );
    }

    return _ApplicationState(
      retained: retained,
      omitted: [],
      omittedIds: {},
      audit: [],
    );
  }
}
