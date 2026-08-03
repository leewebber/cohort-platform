import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/domain/coach_brain/session_adaptation/session_adaptation_pipeline.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';

/// Maps a compute-only pipeline run into a first-class programme proposal.
class ProgrammeAdaptationProposalMapper {
  const ProgrammeAdaptationProposalMapper._();

  static ProgrammeAdaptationProposal fromPipelineRun({
    required PreparedExecutionPackage package,
    required AdaptationRequest request,
    required SessionAdaptationPipelineRun run,
    DateTime? proposedAt,
  }) {
    final stamp = proposedAt ?? DateTime.now().toUtc();
    final policyKinds = AdaptationPolicyGate.kindsForDayOf(
      request.reason,
    ).map((k) => k.name).toList(growable: false);

    final provenance = <String>[
      'evaluation:${run.evaluation.outcome.name}',
      'plan:${run.plan.status.name}',
      'application:${run.application.status.name}',
      'pipeline:SessionAdaptationPipeline',
      'adapter:PlanPackageSessionAdaptationAdapter',
    ];

    final identity = _identityFields(package);
    final preservedIntent =
        run.plan.primaryIntent?.name ??
        run.application.snapshot?.primarySessionIntent?.name;

    if (!_isTraceable(package, run)) {
      return _noSafe(
        identity: identity,
        request: request,
        stamp: stamp,
        policyKinds: policyKinds,
        provenance: provenance,
        preservedIntent: preservedIntent,
        noSafeReason: ProgrammeAdaptationNoSafeReason.notTraceableToPrescription,
        message:
            'Cohort could not safely adapt this session because the proposed '
            'changes were not clearly derived from today’s authored '
            'prescription. Your programme and prepared session are unchanged.',
      );
    }

    final planStatus = run.plan.status;
    final application = run.application;
    final noPlanOrNoAdaptation =
        planStatus == AdaptationPlanStatus.noPlanRequired ||
        run.evaluation.outcome ==
            AdaptationEvaluationOutcome.noAdaptationRequired ||
        application.status ==
            AdaptationPlanApplicationStatus.noAdaptationRequired;

    if (noPlanOrNoAdaptation) {
      // The established pipeline currently plans material steps for time
      // constraints. Other reason families must not invent workouts — return
      // typed no-safe-adaptation when no lawful plan steps exist.
      if (request.reason != AdaptationReason.time) {
        return _noSafe(
          identity: identity,
          request: request,
          stamp: stamp,
          policyKinds: policyKinds,
          provenance: provenance,
          preservedIntent: preservedIntent,
          noSafeReason:
              ProgrammeAdaptationNoSafeReason.unsupportedConstraintFamily,
          message: _noSafeMessage(request.reason, planStatus),
        );
      }

      return ProgrammeAdaptationProposal(
        proposalId: _proposalId(identity, request, stamp),
        outcome: ProgrammeAdaptationProposalOutcome.noAdaptationRequired,
        reason: request.reason,
        programmedSessionKey: identity.key,
        assignmentId: identity.assignmentId,
        programmeVersionId: identity.programmeVersionId,
        packageContentHash: identity.packageContentHash,
        protocolId: identity.protocolId,
        preparedAt: identity.preparedAt,
        proposedAt: stamp,
        dayKey: identity.dayKey,
        slotOrder: identity.slotOrder,
        sessionChanges: const [],
        exerciseChanges: const [],
        preservedIntent: preservedIntent,
        derivationExplanation:
            'No material change is required. The current prepared session '
            'already remains the closest lawful execution of the authored '
            'prescription under this constraint.',
        athleteFacingMessage:
            'No adaptation is needed for this constraint. Your prescribed '
            'programme and current prepared session are unchanged.',
        noSafeReason:
            ProgrammeAdaptationNoSafeReason.constraintAlreadySatisfied,
        policyKinds: policyKinds,
        evaluationProvenance: provenance,
      );
    }

    if (planStatus == AdaptationPlanStatus.unableToPlan ||
        planStatus == AdaptationPlanStatus.insufficientInformation ||
        !application.isSuccess ||
        application.snapshot == null) {
      return _noSafe(
        identity: identity,
        request: request,
        stamp: stamp,
        policyKinds: policyKinds,
        provenance: provenance,
        preservedIntent: preservedIntent,
        noSafeReason: _noSafeReasonForPlan(planStatus, request.reason),
        message: _noSafeMessage(request.reason, planStatus),
      );
    }

    final snapshot = application.snapshot!;
    final sessionChanges = _sessionChanges(snapshot);
    final exerciseChanges = _exerciseChanges(snapshot);

    if (sessionChanges.isEmpty && exerciseChanges.isEmpty) {
      return _noSafe(
        identity: identity,
        request: request,
        stamp: stamp,
        policyKinds: policyKinds,
        provenance: provenance,
        preservedIntent: preservedIntent,
        noSafeReason: ProgrammeAdaptationNoSafeReason.noLawfulSessionSolution,
        message: _noSafeMessage(request.reason, planStatus),
      );
    }

    return ProgrammeAdaptationProposal(
      proposalId: _proposalId(identity, request, stamp),
      outcome: ProgrammeAdaptationProposalOutcome.reviewable,
      reason: request.reason,
      programmedSessionKey: identity.key,
      assignmentId: identity.assignmentId,
      programmeVersionId: identity.programmeVersionId,
      packageContentHash: identity.packageContentHash,
      protocolId: identity.protocolId,
      preparedAt: identity.preparedAt,
      proposedAt: stamp,
      dayKey: identity.dayKey,
      slotOrder: identity.slotOrder,
      sessionChanges: sessionChanges,
      exerciseChanges: exerciseChanges,
      preservedIntent: preservedIntent,
      derivationExplanation:
          'Each proposed change is derived from today’s authored prescription '
          'for programmed session ${identity.key.value}. The authored Plan '
          'Package, later sessions, programme position, and scheduling remain '
          'unchanged. Only the current prepared session could be affected '
          'after explicit acceptance in a later sprint.',
      athleteFacingMessage:
          'Review the proposed adjustments below. Nothing has changed yet. '
          'Your authored programme and later sessions stay as prescribed.',
      policyKinds: policyKinds,
      evaluationProvenance: provenance,
    );
  }

  static ProgrammeAdaptationProposal noSafeFromException({
    required PreparedExecutionPackage? package,
    required AdaptationRequest request,
    required ProgrammeAdaptationNoSafeReason noSafeReason,
    required String message,
    DateTime? proposedAt,
  }) {
    final stamp = proposedAt ?? DateTime.now().toUtc();
    final policyKinds = AdaptationPolicyGate.kindsForDayOf(
      request.reason,
    ).map((k) => k.name).toList(growable: false);

    if (package == null ||
        !package.isProgrammeBacked ||
        package.assignmentId == null ||
        package.programmeVersionId == null ||
        package.packageContentHash == null ||
        package.protocolId == null) {
      return ProgrammeAdaptationProposal(
        proposalId: 'proposal.unavailable.${stamp.millisecondsSinceEpoch}',
        outcome: ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
        reason: request.reason,
        programmedSessionKey:
            package?.programmedSessionKey ??
            const ProgrammedSessionKey(
              planId: 'unavailable',
              planVersion: '0',
              week: 0,
              day: 0,
            ),
        assignmentId: package?.assignmentId ?? '',
        programmeVersionId: package?.programmeVersionId ?? '',
        packageContentHash: package?.packageContentHash ?? '',
        protocolId: package?.protocolId ?? '',
        preparedAt: package?.preparedAt ?? stamp,
        proposedAt: stamp,
        dayKey: package?.dayKey,
        slotOrder: package?.slotOrder,
        sessionChanges: const [],
        exerciseChanges: const [],
        preservedIntent: null,
        derivationExplanation:
            'No proposal was formed. The authored programme remains the sole '
            'prescription authority.',
        athleteFacingMessage: message,
        noSafeReason: noSafeReason,
        policyKinds: policyKinds,
        evaluationProvenance: const [
          'adapter:PlanPackageSessionAdaptationAdapter',
        ],
      );
    }

    return _noSafe(
      identity: _identityFields(package),
      request: request,
      stamp: stamp,
      policyKinds: policyKinds,
      provenance: const ['adapter:PlanPackageSessionAdaptationAdapter'],
      preservedIntent: null,
      noSafeReason: noSafeReason,
      message: message,
    );
  }

  static bool _isTraceable(
    PreparedExecutionPackage package,
    SessionAdaptationPipelineRun run,
  ) {
    final snapshot = run.application.snapshot;
    if (snapshot == null) {
      return package.protocolId != null && package.protocolId!.trim().isNotEmpty;
    }
    final source = snapshot.sourceProtocolId.trim();
    final prepared = package.protocolId?.trim() ?? '';
    return source.isNotEmpty && source == prepared;
  }

  static List<ProgrammeAdaptationMaterialChange> _sessionChanges(
    AdaptedSessionExecutionSnapshot snapshot,
  ) {
    final changes = <ProgrammeAdaptationMaterialChange>[];

    final originalDuration = snapshot.originalPlannedDurationMin;
    final resultingDuration = snapshot.resultingEstimatedDurationMin;
    if (originalDuration != null &&
        resultingDuration != null &&
        resultingDuration != originalDuration) {
      changes.add(
        ProgrammeAdaptationMaterialChange(
          scope: ProgrammeAdaptationChangeScope.session,
          targetId: snapshot.sourceProtocolId,
          actionLabel: 'adjustSessionDuration',
          summary:
              'Session duration ${originalDuration}m → ${resultingDuration}m',
          beforeValue: '${originalDuration}m',
          afterValue: '${resultingDuration}m',
        ),
      );
    }

    for (final omitted in snapshot.omittedBlocks) {
      changes.add(
        ProgrammeAdaptationMaterialChange(
          scope: ProgrammeAdaptationChangeScope.session,
          targetId: omitted.sourceBlockLocalId,
          actionLabel: omitted.omissionAction.name,
          summary:
              'Omit block ${omitted.sourceBlockLocalId} '
              '(${omitted.blockTypeDbValue})',
          blockLocalId: omitted.sourceBlockLocalId,
          beforeValue: 'included',
          afterValue: 'omitted',
          planStepSequence: omitted.planStepSequence,
        ),
      );
    }

    return List.unmodifiable(changes);
  }

  static List<ProgrammeAdaptationMaterialChange> _exerciseChanges(
    AdaptedSessionExecutionSnapshot snapshot,
  ) {
    final changes = <ProgrammeAdaptationMaterialChange>[];

    for (final block in snapshot.retainedBlocks) {
      for (final exercise in block.exercises) {
        if (!exercise.adapted) continue;
        final before = exercise.originalPrescription;
        final after = exercise.executionPrescription;
        final parts = <String>[];
        if (before.sets != after.sets) {
          parts.add('sets ${before.sets} → ${after.sets}');
        }
        if (before.reps != after.reps) {
          parts.add('reps ${before.reps} → ${after.reps}');
        }
        if (before.restSeconds != after.restSeconds) {
          parts.add(
            'rest ${before.restSeconds ?? '—'}s → ${after.restSeconds ?? '—'}s',
          );
        }
        if (parts.isEmpty) {
          parts.add('prescription adjusted');
        }
        changes.add(
          ProgrammeAdaptationMaterialChange(
            scope: ProgrammeAdaptationChangeScope.exercise,
            targetId: exercise.exerciseLinkLocalId,
            actionLabel: 'adjustExercisePrescription',
            summary: 'Exercise ${exercise.exerciseId}: ${parts.join('; ')}',
            exerciseId: exercise.exerciseId,
            exerciseLinkLocalId: exercise.exerciseLinkLocalId,
            blockLocalId: block.sourceBlockLocalId,
            beforeValue: _prescriptionLabel(before),
            afterValue: _prescriptionLabel(after),
            planStepSequence: exercise.appliedPlanStepSequences.isEmpty
                ? null
                : exercise.appliedPlanStepSequences.first,
          ),
        );
      }
    }

    for (final entry in snapshot.appliedAdaptationAudit) {
      final linkId = entry.exerciseLinkLocalId;
      if (linkId == null || linkId.trim().isEmpty) continue;
      final already = changes.any((c) => c.exerciseLinkLocalId == linkId);
      if (already) continue;
      final before = entry.originalValueReference;
      final after = entry.appliedValueReference;
      changes.add(
        ProgrammeAdaptationMaterialChange(
          scope: ProgrammeAdaptationChangeScope.exercise,
          targetId: linkId,
          actionLabel: entry.actionType.name,
          summary:
              '${entry.actionType.name} on exercise link $linkId'
              '${before != null && after != null ? ': $before → $after' : ''}',
          exerciseLinkLocalId: linkId,
          blockLocalId: entry.blockLocalId,
          beforeValue: before,
          afterValue: after,
          planStepSequence: entry.planStepSequence,
        ),
      );
    }

    return List.unmodifiable(changes);
  }

  static String _prescriptionLabel(PrescriptionExecutionSnapshot rx) {
    final sets = rx.sets?.toString() ?? '—';
    final reps = rx.reps?.toString() ?? '—';
    final rest = rx.restSeconds?.toString() ?? '—';
    return '$sets sets × $reps reps · rest ${rest}s';
  }

  static ProgrammeAdaptationNoSafeReason _noSafeReasonForPlan(
    AdaptationPlanStatus status,
    AdaptationReason reason,
  ) {
    if (status == AdaptationPlanStatus.insufficientInformation) {
      return ProgrammeAdaptationNoSafeReason.insufficientInformation;
    }
    if (status == AdaptationPlanStatus.unableToPlan) {
      return reason == AdaptationReason.equipment ||
              reason == AdaptationReason.environment
          ? ProgrammeAdaptationNoSafeReason.noLawfulExerciseSubstitute
          : ProgrammeAdaptationNoSafeReason.noLawfulSessionSolution;
    }
    if (reason != AdaptationReason.time) {
      return ProgrammeAdaptationNoSafeReason.unsupportedConstraintFamily;
    }
    return ProgrammeAdaptationNoSafeReason.pipelineUnableToPlan;
  }

  static String _noSafeMessage(
    AdaptationReason reason,
    AdaptationPlanStatus status,
  ) {
    final constraint = reason.name;
    final detail = status == AdaptationPlanStatus.insufficientInformation
        ? 'There is not enough authored session metadata to adapt safely.'
        : 'A lawful adjustment that preserves the authored training intent '
            'closely enough is not available for this $constraint constraint.';
    return 'Cohort could not safely adapt this session under your current '
        'constraint. $detail Your prescribed programme has not changed, and '
        'your current prepared session remains available.';
  }

  static ProgrammeAdaptationProposal _noSafe({
    required _ProposalIdentity identity,
    required AdaptationRequest request,
    required DateTime stamp,
    required List<String> policyKinds,
    required List<String> provenance,
    required String? preservedIntent,
    required ProgrammeAdaptationNoSafeReason noSafeReason,
    required String message,
  }) {
    return ProgrammeAdaptationProposal(
      proposalId: _proposalId(identity, request, stamp),
      outcome: ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      reason: request.reason,
      programmedSessionKey: identity.key,
      assignmentId: identity.assignmentId,
      programmeVersionId: identity.programmeVersionId,
      packageContentHash: identity.packageContentHash,
      protocolId: identity.protocolId,
      preparedAt: identity.preparedAt,
      proposedAt: stamp,
      dayKey: identity.dayKey,
      slotOrder: identity.slotOrder,
      sessionChanges: const [],
      exerciseChanges: const [],
      preservedIntent: preservedIntent,
      derivationExplanation:
          'No proposal was formed. The authored Plan Package remains the sole '
          'prescription authority; nothing was rewritten or rescheduled.',
      athleteFacingMessage: message,
      noSafeReason: noSafeReason,
      policyKinds: policyKinds,
      evaluationProvenance: provenance,
    );
  }

  static _ProposalIdentity _identityFields(PreparedExecutionPackage package) {
    return _ProposalIdentity(
      key: package.programmedSessionKey,
      assignmentId: package.assignmentId!.trim(),
      programmeVersionId: package.programmeVersionId!.trim(),
      packageContentHash: package.packageContentHash!.trim(),
      protocolId: package.protocolId!.trim(),
      preparedAt: package.preparedAt,
      dayKey: package.dayKey,
      slotOrder: package.slotOrder,
    );
  }

  static String _proposalId(
    _ProposalIdentity identity,
    AdaptationRequest request,
    DateTime stamp,
  ) {
    return 'proposal.${identity.key.value}.'
        '${request.reason.name}.${stamp.millisecondsSinceEpoch}';
  }
}

class _ProposalIdentity {
  const _ProposalIdentity({
    required this.key,
    required this.assignmentId,
    required this.programmeVersionId,
    required this.packageContentHash,
    required this.protocolId,
    required this.preparedAt,
    this.dayKey,
    this.slotOrder,
  });

  final ProgrammedSessionKey key;
  final String assignmentId;
  final String programmeVersionId;
  final String packageContentHash;
  final String protocolId;
  final DateTime preparedAt;
  final String? dayKey;
  final int? slotOrder;
}
