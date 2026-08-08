import 'package:cohort_platform/application/adaptation/journey_d_equipment_adaptation_contract.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_acceptance_service.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_proposal_service.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/authored_plan_package/plan_package_manifest.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';

import 'journey_d_credential_handoff.dart';

/// Intended Journey D fixture occurrence identity.
const kJourneyDIntendedSessionKey = 'SES-JD-ADAPT-CURRENT';
const kJourneyDLaterSessionKey = 'SES-JD-ADAPT-LATER';
const kJourneyDIntendedProtocolId = 'PROT-S17-JD-ADAPT-CURRENT';
const kJourneyDLaterProtocolId = 'PROT-S17-JD-ADAPT-LATER';
const kJourneyDLaterExerciseId = 'cohort.exercise.push_up';

/// Ports for resolving fixture state and recording hosted execution evidence.
abstract class JourneyDExecutePorts {
  /// Resolve exactly one fixture identity/assignment/intended occurrence.
  Future<JourneyDFixtureResolution> resolveFixture({
    required String marker,
    required String athleteId,
    required String assignmentId,
    required String versionId,
  });

  /// Authenticate as the synthetic athlete (password never logged).
  Future<void> authenticate({
    required String email,
    required String password,
    required String expectedAthleteId,
  });

  /// Prepare the intended occurrence package for [athleteId].
  Future<JourneyDPreparedOccurrence> prepareIntended({
    required String athleteId,
  });

  /// Load adaptation permissions for the fixture programme version.
  Future<List<PlanPackageAdaptationPermission>> loadPermissions({
    required String versionId,
  });

  /// Verify later push_up occurrence remains untouched (programme source).
  Future<bool> laterPushUpIntact({
    required String marker,
    required String assignmentId,
  });

  /// Persist fixture-scoped hosted evidence of Journey D execution (non-secret).
  Future<void> recordExecutionEvidence({
    required JourneyDExecuteEvidence evidence,
  });
}

class JourneyDFixtureResolution {
  const JourneyDFixtureResolution({
    required this.marker,
    required this.athleteId,
    required this.assignmentId,
    required this.versionId,
    required this.intendedOccurrenceKey,
    required this.laterOccurrenceKey,
    this.lineageCode = JourneyDPrivateCredential.lineageProgS17JdAdapt,
  });

  final String marker;
  final String athleteId;
  final String assignmentId;
  final String versionId;
  final String intendedOccurrenceKey;
  final String laterOccurrenceKey;
  final String lineageCode;
}

class JourneyDPreparedOccurrence {
  const JourneyDPreparedOccurrence({
    required this.package,
    required this.executionContext,
    required this.sessionKey,
  });

  final PreparedExecutionPackage package;
  final ProgrammeExecutionContext executionContext;
  final String sessionKey;
}

class JourneyDExecuteEvidence {
  const JourneyDExecuteEvidence({
    required this.marker,
    required this.athleteId,
    required this.assignmentId,
    required this.versionId,
    required this.proposalId,
    required this.action,
    required this.sourceExerciseId,
    required this.replacementExerciseId,
    required this.substitutionRuleId,
    required this.athleteAgreementRecorded,
    required this.intendedOccurrenceKey,
    required this.laterPushUpIntact,
    required this.permissionsPassed,
    required this.executedAtUtc,
  });

  final String marker;
  final String athleteId;
  final String assignmentId;
  final String versionId;
  final String proposalId;
  final String action;
  final String sourceExerciseId;
  final String replacementExerciseId;
  final String substitutionRuleId;
  final bool athleteAgreementRecorded;
  final String intendedOccurrenceKey;
  final bool laterPushUpIntact;
  final bool permissionsPassed;
  final DateTime executedAtUtc;

  Map<String, Object?> toMetadata() => {
    'run_id': marker,
    'journey_d_execution_count': 1,
    'journey_i_execution_count': 0,
    'journey_j_execution_count': 0,
    'action': action,
    'source_exercise_id': sourceExerciseId,
    'replacement_exercise_id': replacementExerciseId,
    'substitution_rule_id': substitutionRuleId,
    'athlete_agreement_recorded': athleteAgreementRecorded,
    'intended_occurrence_key': intendedOccurrenceKey,
    'later_push_up_intact': laterPushUpIntact,
    'permissions_passed': permissionsPassed,
    'proposal_id_prefix': proposalId.length >= 8
        ? '${proposalId.substring(0, 8)}…'
        : '…',
    'executed_at': executedAtUtc.toUtc().toIso8601String(),
  };
}

class JourneyDExecuteResult {
  const JourneyDExecuteResult({
    required this.ok,
    required this.classification,
    required this.marker,
    required this.journeyDExecuted,
    required this.journeyDExecutionCount,
    required this.journeyIExecutionCount,
    required this.journeyJExecutionCount,
    required this.swapExercise,
    required this.sourceExerciseId,
    required this.replacementExerciseId,
    required this.substitutionRuleId,
    required this.athleteAgreementRecorded,
    required this.permissionsPassed,
    required this.intendedOccurrenceAdapted,
    required this.laterPushUpIntact,
    required this.programmeSourceMutated,
    required this.detail,
    this.proposalIdRedacted,
    this.credentialConsumed = false,
    this.credentialShredded = false,
    this.hostedWritesExecuted = 0,
    this.executionStage,
    this.exceptionType,
    this.exceptionMessage,
    this.agreementAccepted = false,
    this.applicationInvoked = false,
    this.exceptionLocation,
    this.identityHints = const {},
  });

  final bool ok;
  final String classification;
  final String marker;
  final bool journeyDExecuted;
  final int journeyDExecutionCount;
  final int journeyIExecutionCount;
  final int journeyJExecutionCount;
  final bool swapExercise;
  final String? sourceExerciseId;
  final String? replacementExerciseId;
  final String? substitutionRuleId;
  final bool athleteAgreementRecorded;
  final bool permissionsPassed;
  final bool intendedOccurrenceAdapted;
  final bool laterPushUpIntact;
  final bool programmeSourceMutated;
  final String detail;
  final String? proposalIdRedacted;
  final bool credentialConsumed;
  final bool credentialShredded;
  final int hostedWritesExecuted;

  /// Named stage active when a closure-blocking exception escaped.
  final String? executionStage;

  /// Sanitised exception type name (e.g. `StateError`).
  final String? exceptionType;

  /// Sanitised exception message (no secrets / emails / tokens).
  final String? exceptionMessage;

  /// True when athlete agreement accept returned success in this run.
  final bool agreementAccepted;

  /// True when prepared-package application (accept persist) completed.
  final bool applicationInvoked;

  /// First in-repo stack frame location for local diagnosis (sanitised).
  final String? exceptionLocation;

  /// Non-secret object identity prefixes useful for staging diagnosis.
  final Map<String, String> identityHints;

  Map<String, Object?> toJson() => {
    'ok': ok,
    'classification': classification,
    'marker': marker,
    'fixture_marker': marker,
    'lineage_code': JourneyDPrivateCredential.lineageProgS17JdAdapt,
    'journey_d_executed': journeyDExecuted,
    'journey_d_execution_count': journeyDExecutionCount,
    'journey_i_execution_count': journeyIExecutionCount,
    'journey_j_execution_count': journeyJExecutionCount,
    'swap_exercise': swapExercise,
    'action': swapExercise ? 'swapExercise' : null,
    'source_exercise_id': sourceExerciseId,
    'replacement_exercise_id': replacementExerciseId,
    'substitution_rule_id': substitutionRuleId,
    'athlete_agreement_recorded': athleteAgreementRecorded,
    'permissions_passed': permissionsPassed,
    'intended_occurrence_adapted': intendedOccurrenceAdapted,
    'later_push_up_intact': laterPushUpIntact,
    'programme_source_mutated': programmeSourceMutated,
    'proposal_id_redacted': proposalIdRedacted,
    'credential_consumed': credentialConsumed,
    'credential_shredded': credentialShredded,
    'hosted_writes_executed': hostedWritesExecuted,
    'execution_stage': executionStage,
    'exception_type': exceptionType,
    'exception_message': exceptionMessage,
    'exception_location': exceptionLocation,
    'agreement_accepted': agreementAccepted,
    'application_invoked': applicationInvoked,
    'identity_hints': identityHints,
    'detail': detail,
    'retry': false,
    'resume': false,
    'repair': false,
    'cleanup': false,
  };
}

/// Canonical Journey D execute path for `s17_jd_adapt_*` / PROG-S17-JD-ADAPT.
///
/// Workflow: resolve → auth → prepare intended → propose → require agreement →
/// accept once → record evidence. Never touches Journey I/J.
class JourneyDExecuteWorkflow {
  JourneyDExecuteWorkflow({
    required this.ports,
    ProgrammeAdaptationProposalService? proposalService,
    ProgrammeAdaptationAcceptanceService? Function(
      AthleteProgrammeSessionPrepareService prepare,
    )?
    acceptanceFactory,
  }) : _proposalService = proposalService,
       _acceptanceFactory = acceptanceFactory;

  final JourneyDExecutePorts ports;
  final ProgrammeAdaptationProposalService? _proposalService;
  final ProgrammeAdaptationAcceptanceService? Function(
    AthleteProgrammeSessionPrepareService prepare,
  )?
  _acceptanceFactory;

  Future<JourneyDExecuteResult> run({
    required String marker,
    required JourneyDPrivateCredential credential,
    required AthleteProgrammeSessionPrepareService prepareService,
    bool eligibilityPassed = false,
  }) async {
    if (!eligibilityPassed) {
      return _fail(
        marker: marker,
        classification: 'JOURNEY_D_FIXTURE_INELIGIBLE',
        detail: 'eligibility_must_pass_before_credential_consume',
        credentialConsumed: false,
      );
    }

    JourneyDCredentialHandoff.validateMarker(marker);
    if (credential.marker != marker) {
      return _fail(
        marker: marker,
        classification: 'JOURNEY_D_CONTRACT_BLOCKED',
        detail: 'credential_marker_mismatch',
        credentialConsumed: true,
      );
    }
    if (credential.lineageCode !=
        JourneyDPrivateCredential.lineageProgS17JdAdapt) {
      return _fail(
        marker: marker,
        classification: 'JOURNEY_D_CONTRACT_BLOCKED',
        detail: 'credential_lineage_refused',
        credentialConsumed: true,
      );
    }

    var stage = 'resolve_fixture';
    var agreementAccepted = false;
    var applicationInvoked = false;
    var hostedWrites = 0;
    final identityHints = <String, String>{
      'athlete_id_prefix': _idPrefix(credential.athleteId),
      'assignment_id_prefix': _idPrefix(credential.assignmentId),
      'version_id_prefix': _idPrefix(credential.versionId),
    };
    try {
      stage = 'resolve_fixture';
      final resolution = await ports.resolveFixture(
        marker: marker,
        athleteId: credential.athleteId,
        assignmentId: credential.assignmentId,
        versionId: credential.versionId,
      );
      if (resolution.intendedOccurrenceKey != kJourneyDIntendedSessionKey) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_SCOPE_BLOCKED',
          detail: 'intended_occurrence_mismatch',
          credentialConsumed: true,
          executionStage: stage,
          identityHints: identityHints,
        );
      }
      if (resolution.laterOccurrenceKey != kJourneyDLaterSessionKey) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_SCOPE_BLOCKED',
          detail: 'later_occurrence_mismatch',
          credentialConsumed: true,
          executionStage: stage,
          identityHints: identityHints,
        );
      }

      stage = 'authenticate';
      await ports.authenticate(
        email: credential.email,
        password: credential.password,
        expectedAthleteId: credential.athleteId,
      );

      stage = 'prepare_intended';
      final prepared = await ports.prepareIntended(
        athleteId: credential.athleteId,
      );
      final protocolId = (prepared.package.protocolId ?? '').trim();
      identityHints['protocol_id'] = protocolId;
      final key = prepared.package.programmedSessionKey.value;
      final okIntended =
          protocolId == kJourneyDIntendedProtocolId ||
          key.contains('CURRENT') ||
          key == kJourneyDIntendedSessionKey ||
          prepared.sessionKey == kJourneyDIntendedSessionKey ||
          prepared.sessionKey.contains('JD-ADAPT-CURRENT');
      if (!okIntended) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_SCOPE_BLOCKED',
          detail: 'prepared_not_intended_occurrence',
          credentialConsumed: true,
          executionStage: stage,
          identityHints: identityHints,
        );
      }
      if (protocolId == kJourneyDLaterProtocolId ||
          key.contains('LATER') ||
          prepared.sessionKey.contains('LATER')) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_SCOPE_BLOCKED',
          detail: 'later_or_unrelated_occurrence_selected',
          credentialConsumed: true,
          executionStage: stage,
          identityHints: identityHints,
        );
      }

      stage = 'load_permissions';
      final permissions = await ports.loadPermissions(
        versionId: credential.versionId,
      );
      if (permissions.isEmpty ||
          !permissions.every((p) => p.athleteAgreementRequired)) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_CONTRACT_BLOCKED',
          detail: 'athlete_agreement_required_permissions_missing',
          credentialConsumed: true,
          executionStage: stage,
          identityHints: identityHints,
        );
      }
      final permissionsPassed = permissions.any(
        (p) =>
            p.changeKind == AdaptationChangeKind.substituteApprovedExercise ||
            p.changeKind == AdaptationChangeKind.substituteApprovedEquipment,
      );
      if (!permissionsPassed) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_CONTRACT_BLOCKED',
          detail: 'substitution_permissions_absent',
          credentialConsumed: true,
          executionStage: stage,
          identityHints: identityHints,
        );
      }

      stage = 'propose_recommendation';
      final proposalService =
          _proposalService ??
          ProgrammeAdaptationProposalService(
            loadAdaptationPermissions: (_) async => permissions,
          );
      final proposal = await proposalService.propose(
        package: prepared.package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
      );
      identityHints['proposal_id_prefix'] = proposal.proposalId.length >= 8
          ? proposal.proposalId.substring(0, 8)
          : proposal.proposalId;

      if (!proposal.isAcceptable) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_EXECUTION_FAILED',
          detail: 'proposal_not_acceptable:${proposal.outcome.name}',
          credentialConsumed: true,
          executionStage: stage,
          identityHints: identityHints,
        );
      }

      if (!_hasApprovedSwap(proposal)) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_EXECUTION_FAILED',
          detail: 'approved_back_squat_to_goblet_swap_missing',
          credentialConsumed: true,
          executionStage: stage,
          identityHints: identityHints,
        );
      }

      // Athlete agreement is mandatory — accept is the explicit agreement act.
      // Accept also applies the reviewed plan to the prepared package (local).
      stage = 'athlete_agreement_accept';
      final acceptance =
          (_acceptanceFactory?.call(prepareService)) ??
          ProgrammeAdaptationAcceptanceService(
            prepareService: prepareService,
            loadAdaptationPermissions: (_) async => permissions,
          );
      final acceptRes = await acceptance.accept(
        athleteId: credential.athleteId,
        currentPackage: prepared.package,
        proposal: proposal,
        executionContext: prepared.executionContext,
      );
      if (!acceptRes.success) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_EXECUTION_FAILED',
          detail: 'athlete_agreement_accept_failed:${acceptRes.errorCode}',
          credentialConsumed: true,
          executionStage: stage,
          identityHints: identityHints,
        );
      }
      agreementAccepted = true;
      applicationInvoked = true;

      stage = 'later_push_up_integrity';
      final laterOk = await ports.laterPushUpIntact(
        marker: marker,
        assignmentId: credential.assignmentId,
      );
      if (!laterOk) {
        return _fail(
          marker: marker,
          classification: 'JOURNEY_D_EXECUTION_UNCERTAIN',
          detail: 'later_push_up_integrity_failed',
          credentialConsumed: true,
          executionStage: stage,
          agreementAccepted: agreementAccepted,
          applicationInvoked: applicationInvoked,
          identityHints: identityHints,
        );
      }

      stage = 'record_execution_evidence';
      final evidence = JourneyDExecuteEvidence(
        marker: marker,
        athleteId: credential.athleteId,
        assignmentId: credential.assignmentId,
        versionId: credential.versionId,
        proposalId: proposal.proposalId,
        action: 'swapExercise',
        sourceExerciseId: JourneyDEquipmentAdaptationContract.sourceExerciseId,
        replacementExerciseId:
            JourneyDEquipmentAdaptationContract.replacementExerciseId,
        substitutionRuleId:
            JourneyDEquipmentAdaptationContract.substitutionRuleId,
        athleteAgreementRecorded: true,
        intendedOccurrenceKey: kJourneyDIntendedSessionKey,
        laterPushUpIntact: laterOk,
        permissionsPassed: permissionsPassed,
        executedAtUtc: DateTime.now().toUtc(),
      );
      await ports.recordExecutionEvidence(evidence: evidence);
      hostedWrites = 1;

      return JourneyDExecuteResult(
        ok: true,
        classification: 'JOURNEY_D_EXECUTED',
        marker: marker,
        journeyDExecuted: true,
        journeyDExecutionCount: 1,
        journeyIExecutionCount: 0,
        journeyJExecutionCount: 0,
        swapExercise: true,
        sourceExerciseId: JourneyDEquipmentAdaptationContract.sourceExerciseId,
        replacementExerciseId:
            JourneyDEquipmentAdaptationContract.replacementExerciseId,
        substitutionRuleId:
            JourneyDEquipmentAdaptationContract.substitutionRuleId,
        athleteAgreementRecorded: true,
        permissionsPassed: permissionsPassed,
        intendedOccurrenceAdapted: true,
        laterPushUpIntact: laterOk,
        programmeSourceMutated: false,
        detail: 'canonical_journey_d_complete',
        proposalIdRedacted: proposal.proposalId.length >= 8
            ? '${proposal.proposalId.substring(0, 8)}…'
            : '…',
        credentialConsumed: true,
        hostedWritesExecuted: hostedWrites,
        executionStage: 'complete',
        agreementAccepted: true,
        applicationInvoked: true,
        identityHints: identityHints,
      );
    } on JourneyDExecuteAmbiguity catch (e) {
      return _fail(
        marker: marker,
        classification: 'JOURNEY_D_SCOPE_BLOCKED',
        detail: e.code,
        credentialConsumed: true,
        executionStage: stage,
        agreementAccepted: agreementAccepted,
        applicationInvoked: applicationInvoked,
        hostedWritesExecuted: hostedWrites,
        identityHints: identityHints,
      );
    } catch (e, st) {
      final safeType = e.runtimeType.toString();
      final safeMessage = sanitizeJourneyDExceptionMessage(e);
      final location = sanitizeJourneyDExceptionLocation(st);
      return _fail(
        marker: marker,
        classification: 'JOURNEY_D_EXECUTION_FAILED',
        detail:
            'unhandled:stage=$stage:$safeType:${safeMessage.isEmpty ? 'no_message' : safeMessage}',
        credentialConsumed: true,
        executionStage: stage,
        exceptionType: safeType,
        exceptionMessage: safeMessage,
        exceptionLocation: location,
        agreementAccepted: agreementAccepted,
        applicationInvoked: applicationInvoked,
        hostedWritesExecuted: hostedWrites,
        identityHints: identityHints,
      );
    }
  }

  bool _hasApprovedSwap(ProgrammeAdaptationProposal proposal) {
    final steps = proposal.allMaterialChanges;
    final materialOk = steps.any(
      (c) =>
          (c.beforeValue ==
                  JourneyDEquipmentAdaptationContract.sourceExerciseId ||
              c.exerciseId ==
                  JourneyDEquipmentAdaptationContract.sourceExerciseId) &&
          (c.afterValue ==
                  JourneyDEquipmentAdaptationContract.replacementExerciseId ||
              c.actionLabel.toLowerCase().contains('swap')),
    );
    // Also accept when reviewed plan exercise ids show the replacement.
    final planBlob = proposal.reviewedExecutablePlan?.toString() ?? '';
    final planOk =
        planBlob.contains(
          JourneyDEquipmentAdaptationContract.replacementExerciseId,
        ) &&
        !planBlob.contains('journey_i') &&
        !planBlob.contains('journey_j');
    return materialOk || planOk;
  }

  JourneyDExecuteResult _fail({
    required String marker,
    required String classification,
    required String detail,
    required bool credentialConsumed,
    String? executionStage,
    String? exceptionType,
    String? exceptionMessage,
    String? exceptionLocation,
    bool agreementAccepted = false,
    bool applicationInvoked = false,
    int hostedWritesExecuted = 0,
    Map<String, String> identityHints = const {},
  }) {
    return JourneyDExecuteResult(
      ok: false,
      classification: classification,
      marker: marker,
      journeyDExecuted: false,
      journeyDExecutionCount: 0,
      journeyIExecutionCount: 0,
      journeyJExecutionCount: 0,
      swapExercise: false,
      sourceExerciseId: null,
      replacementExerciseId: null,
      substitutionRuleId: null,
      // Hosted agreement evidence is recorded only after successful evidence write.
      athleteAgreementRecorded: false,
      permissionsPassed: false,
      intendedOccurrenceAdapted: false,
      laterPushUpIntact: false,
      programmeSourceMutated: false,
      detail: detail,
      credentialConsumed: credentialConsumed,
      hostedWritesExecuted: hostedWritesExecuted,
      executionStage: executionStage,
      exceptionType: exceptionType,
      exceptionMessage: exceptionMessage,
      exceptionLocation: exceptionLocation,
      agreementAccepted: agreementAccepted,
      applicationInvoked: applicationInvoked,
      identityHints: identityHints,
    );
  }

  static String _idPrefix(String id) {
    final t = id.trim();
    if (t.isEmpty) return '';
    return t.length >= 8 ? '${t.substring(0, 8)}…' : t;
  }
}

/// Sanitises exception text for Journey D closure evidence (no secrets).
String sanitizeJourneyDExceptionMessage(Object error) {
  var raw = error is StateError
      ? error.message
      : error.toString().replaceFirst(RegExp(r'^[^:]+:\s*'), '');
  raw = raw
      .replaceAll(
        RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
        '<email>',
      )
      .replaceAll(
        RegExp(r'bearer\s+[A-Za-z0-9._-]+', caseSensitive: false),
        'bearer <redacted>',
      )
      .replaceAll(
        RegExp(
          r'(password|service[_-]?role|apikey|token)\s*[:=]\s*\S+',
          caseSensitive: false,
        ),
        '<credential=<redacted>>',
      )
      .replaceAll(
        RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
        '<jwt>',
      );
  if (raw.length > 240) {
    raw = '${raw.substring(0, 240)}…';
  }
  return raw.trim();
}

/// First in-repo stack frame for local diagnosis (paths only, no secrets).
String? sanitizeJourneyDExceptionLocation(StackTrace stackTrace) {
  for (final line in stackTrace.toString().split('\n')) {
    final trimmed = line.trim();
    if (trimmed.contains('journey_d_') ||
        trimmed.contains('programme_adaptation_') ||
        trimmed.contains('package:cohort_platform/')) {
      var safe = trimmed
          .replaceAll(
            RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
            '<email>',
          )
          .replaceAll(
            RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'),
            '<jwt>',
          );
      if (safe.length > 200) safe = '${safe.substring(0, 200)}…';
      return safe;
    }
  }
  return null;
}

class JourneyDExecuteAmbiguity implements Exception {
  JourneyDExecuteAmbiguity(this.code);
  final String code;
  @override
  String toString() => 'JourneyDExecuteAmbiguity($code)';
}

/// In-memory fake ports for local acceptance (never hosted).
class FakeJourneyDExecutePorts implements JourneyDExecutePorts {
  FakeJourneyDExecutePorts({
    required this.resolution,
    required this.prepared,
    required this.permissions,
    this.laterIntact = true,
    this.authCalls = 0,
    this.rejectAuth = false,
    this.ambiguous = false,
    this.missing = false,
    this.throwStateErrorAtStage,
    this.stateErrorMessage = 'injected_state_error',
  });

  JourneyDFixtureResolution resolution;
  JourneyDPreparedOccurrence prepared;
  List<PlanPackageAdaptationPermission> permissions;
  bool laterIntact;
  int authCalls;
  bool rejectAuth;
  bool ambiguous;
  bool missing;

  /// When set, throws [StateError] entering that ports stage.
  ///
  /// Supported: `authenticate`, `later_push_up_integrity`,
  /// `record_execution_evidence`.
  final String? throwStateErrorAtStage;
  final String stateErrorMessage;
  int resolveCalls = 0;
  int prepareCalls = 0;
  int evidenceCalls = 0;
  String? lastAuthEmail;
  // ignore: unused_field
  String? _lastPassword;
  JourneyDExecuteEvidence? lastEvidence;

  /// Password reaches auth without being exposed via toString of this class.
  bool get passwordReachedAuth => _lastPassword != null && authCalls > 0;

  @override
  Future<JourneyDFixtureResolution> resolveFixture({
    required String marker,
    required String athleteId,
    required String assignmentId,
    required String versionId,
  }) async {
    resolveCalls += 1;
    if (missing) {
      throw JourneyDExecuteAmbiguity('fixture_missing');
    }
    if (ambiguous) {
      throw JourneyDExecuteAmbiguity('fixture_ambiguous');
    }
    if (resolution.marker != marker ||
        resolution.athleteId != athleteId ||
        resolution.assignmentId != assignmentId ||
        resolution.versionId != versionId) {
      throw JourneyDExecuteAmbiguity('fixture_identity_mismatch');
    }
    return resolution;
  }

  @override
  Future<void> authenticate({
    required String email,
    required String password,
    required String expectedAthleteId,
  }) async {
    authCalls += 1;
    lastAuthEmail = email;
    _lastPassword = password;
    if (rejectAuth || throwStateErrorAtStage == 'authenticate') {
      throw StateError(
        rejectAuth ? 'auth_rejected' : stateErrorMessage,
      );
    }
  }

  @override
  Future<JourneyDPreparedOccurrence> prepareIntended({
    required String athleteId,
  }) async {
    prepareCalls += 1;
    return prepared;
  }

  @override
  Future<List<PlanPackageAdaptationPermission>> loadPermissions({
    required String versionId,
  }) async {
    return permissions;
  }

  @override
  Future<bool> laterPushUpIntact({
    required String marker,
    required String assignmentId,
  }) async {
    if (throwStateErrorAtStage == 'later_push_up_integrity') {
      throw StateError(stateErrorMessage);
    }
    return laterIntact;
  }

  @override
  Future<void> recordExecutionEvidence({
    required JourneyDExecuteEvidence evidence,
  }) async {
    if (throwStateErrorAtStage == 'record_execution_evidence') {
      throw StateError(stateErrorMessage);
    }
    evidenceCalls += 1;
    lastEvidence = evidence;
  }
}
