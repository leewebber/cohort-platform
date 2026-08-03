import '../../../models/adaptation_reason.dart';
import '../../../models/adaptation_request.dart';
import '../../plans/models/programmed_session_key.dart';
import '../../session/models/session_execution_plan.dart';

/// Outcome of a programme-backed adaptation evaluation (Sprint 1.6B).
///
/// Distinct from [AcceptedAdaptationDecision] — proposals never mutate prepared
/// state until explicit acceptance (Sprint 1.6C).
enum ProgrammeAdaptationProposalOutcome {
  /// Material session and/or exercise changes are available for athlete review.
  reviewable,

  /// Constraint already satisfied; original prepared session remains correct.
  noAdaptationRequired,

  /// No lawful adaptation preserves authored intent closely enough.
  noSafeAdaptation,
}

/// Why a proposal could not be formed safely.
enum ProgrammeAdaptationNoSafeReason {
  constraintAlreadySatisfied,
  unableToPreserveIntent,
  prohibitedChangeRequired,
  staleOrMismatchedPreparedSession,
  notProgrammeBacked,
  notTraceableToPrescription,
  schedulingRequestUnsupported,
  futureSessionMutationUnsupported,
  progressionMutationUnsupported,
  noLawfulSessionSolution,
  noLawfulExerciseSubstitute,
  pipelineUnableToPlan,
  insufficientInformation,
  policyRejected,
  unsupportedConstraintFamily,
}

/// Granularity of a single material change in a proposal.
enum ProgrammeAdaptationChangeScope { session, exercise }

/// One material before/after change retained for athlete review.
class ProgrammeAdaptationMaterialChange {
  const ProgrammeAdaptationMaterialChange({
    required this.scope,
    required this.targetId,
    required this.actionLabel,
    required this.summary,
    this.exerciseId,
    this.exerciseLinkLocalId,
    this.blockLocalId,
    this.beforeValue,
    this.afterValue,
    this.planStepSequence,
  });

  final ProgrammeAdaptationChangeScope scope;
  final String targetId;
  final String actionLabel;
  final String summary;
  final String? exerciseId;
  final String? exerciseLinkLocalId;
  final String? blockLocalId;
  final String? beforeValue;
  final String? afterValue;
  final int? planStepSequence;

  Map<String, dynamic> toPersistenceMap() => {
    'scope': scope.name,
    'targetId': targetId,
    'actionLabel': actionLabel,
    'summary': summary,
    'exerciseId': exerciseId,
    'exerciseLinkLocalId': exerciseLinkLocalId,
    'blockLocalId': blockLocalId,
    'beforeValue': beforeValue,
    'afterValue': afterValue,
    'planStepSequence': planStepSequence,
  };
}

/// First-class in-memory proposal for the programme Adapt Session path.
class ProgrammeAdaptationProposal {
  const ProgrammeAdaptationProposal({
    required this.proposalId,
    required this.outcome,
    required this.reason,
    required this.programmedSessionKey,
    required this.assignmentId,
    required this.programmeVersionId,
    required this.packageContentHash,
    required this.protocolId,
    required this.preparedAt,
    required this.proposedAt,
    required this.sessionChanges,
    required this.exerciseChanges,
    required this.preservedIntent,
    required this.derivationExplanation,
    required this.athleteFacingMessage,
    this.dayKey,
    this.slotOrder,
    this.noSafeReason,
    this.policyKinds = const [],
    this.evaluationProvenance = const [],
    this.request,
    this.originalPlanFingerprint,
    this.reviewedExecutablePlan,
    this.snapshotId,
    this.reviewedPlanFingerprint,
  });

  final String proposalId;
  final ProgrammeAdaptationProposalOutcome outcome;
  final AdaptationReason reason;
  final ProgrammedSessionKey programmedSessionKey;
  final String assignmentId;
  final String programmeVersionId;
  final String packageContentHash;
  final String protocolId;
  final DateTime preparedAt;
  final DateTime proposedAt;
  final String? dayKey;
  final int? slotOrder;
  final List<ProgrammeAdaptationMaterialChange> sessionChanges;
  final List<ProgrammeAdaptationMaterialChange> exerciseChanges;
  final String? preservedIntent;
  final String derivationExplanation;
  final String athleteFacingMessage;
  final ProgrammeAdaptationNoSafeReason? noSafeReason;
  final List<String> policyKinds;
  final List<String> evaluationProvenance;

  /// Original athlete request retained for freshness revalidation on accept.
  final AdaptationRequest? request;

  /// Fingerprint of the prepared plan at proposal time.
  final String? originalPlanFingerprint;

  /// Exact reviewed executable plan (reviewable proposals only).
  final SessionExecutionPlan? reviewedExecutablePlan;

  final String? snapshotId;
  final String? reviewedPlanFingerprint;

  bool get isReviewable =>
      outcome == ProgrammeAdaptationProposalOutcome.reviewable;

  bool get isNoSafeAdaptation =>
      outcome == ProgrammeAdaptationProposalOutcome.noSafeAdaptation;

  bool get isAcceptable =>
      isReviewable &&
      reviewedExecutablePlan != null &&
      reviewedExecutablePlan!.hasExecutableBlocks &&
      request != null &&
      originalPlanFingerprint != null;

  List<ProgrammeAdaptationMaterialChange> get allMaterialChanges => [
    ...sessionChanges,
    ...exerciseChanges,
  ];

  /// Structural fingerprint of prepared identity retained on the proposal.
  String get preparedIdentityFingerprint =>
      '$assignmentId|$programmeVersionId|$packageContentHash|'
      '${programmedSessionKey.value}|$protocolId|'
      '${dayKey ?? ''}|${slotOrder ?? ''}';
}
