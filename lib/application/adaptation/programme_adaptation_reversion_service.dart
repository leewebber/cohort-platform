import 'package:cohort_platform/features/adaptation/models/accepted_adaptation_decision.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';

import 'programme_adaptation_fingerprints.dart';

/// Result of an explicit programme adaptation reversion attempt.
class ProgrammeAdaptationReversionResult {
  const ProgrammeAdaptationReversionResult._({
    required this.success,
    this.package,
    this.errorCode,
    this.message,
  });

  factory ProgrammeAdaptationReversionResult.ok({
    required PreparedExecutionPackage package,
  }) {
    return ProgrammeAdaptationReversionResult._(
      success: true,
      package: package,
    );
  }

  factory ProgrammeAdaptationReversionResult.failed({
    required String errorCode,
    required String message,
  }) {
    return ProgrammeAdaptationReversionResult._(
      success: false,
      errorCode: errorCode,
      message: message,
    );
  }

  final bool success;
  final PreparedExecutionPackage? package;
  final String? errorCode;
  final String? message;
}

/// Explicit pre-completion reversion owner (Sprint 1.6D).
///
/// Reconstructs the authored executable plan via the prepare bank/compiler
/// path and clears the active accepted adaptation. Does not run adaptation
/// planning, advance the cursor, or contact a server.
class ProgrammeAdaptationReversionService {
  ProgrammeAdaptationReversionService({
    required AthleteProgrammeSessionPrepareService prepareService,
  }) : _prepareService = prepareService;

  final AthleteProgrammeSessionPrepareService _prepareService;
  bool _revertInFlight = false;

  /// Reverts the current adapted prepared package to the authored prescription.
  Future<ProgrammeAdaptationReversionResult> revert({
    required String athleteId,
    required PreparedExecutionPackage currentPackage,
    required ProgrammeExecutionContext executionContext,
  }) async {
    if (_revertInFlight) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'revert_in_flight',
        message:
            'A reversion is already in progress. Your prepared session was '
            'not changed.',
      );
    }
    _revertInFlight = true;
    try {
      return await _revertUnlocked(
        athleteId: athleteId,
        currentPackage: currentPackage,
        executionContext: executionContext,
      );
    } finally {
      _revertInFlight = false;
    }
  }

  Future<ProgrammeAdaptationReversionResult> _revertUnlocked({
    required String athleteId,
    required PreparedExecutionPackage currentPackage,
    required ProgrammeExecutionContext executionContext,
  }) async {
    if (!currentPackage.hasAcceptedAdaptation) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'not_adapted',
        message:
            'This prepared session has no accepted adaptation to revert. Your '
            'prepared session was not changed.',
      );
    }
    if (!currentPackage.isProgrammeBacked) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'not_programme_backed',
        message:
            'Only a programme-backed prepared session can be reverted. Your '
            'prepared session was not changed.',
      );
    }
    if (!_identityMatches(currentPackage, executionContext)) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'stale_identity',
        message:
            'The prepared session identity no longer matches the current '
            'programme assignment. Your prepared session was not changed.',
      );
    }

    final decision = currentPackage.acceptedAdaptation!;
    if (!_decisionBelongsToPackage(decision, currentPackage)) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'decision_mismatch',
        message:
            'The accepted adaptation does not belong to this prepared '
            'session. Your prepared session was not changed.',
      );
    }

    final expectedOriginal = decision.originalPlanFingerprint;
    if (expectedOriginal == null || expectedOriginal.trim().isEmpty) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'missing_original_fingerprint',
        message:
            'Cohort cannot prove the original prescription for this '
            'adaptation. Your prepared session was not changed.',
      );
    }

    // Race: in-memory prepared state may already have been replaced.
    final cached = _prepareService.cachedPackageForKey(
      currentPackage.programmedSessionKey.value,
    );
    if (cached != null) {
      final cachedFp = ProgrammeAdaptationFingerprints.package(cached);
      final currentFp = ProgrammeAdaptationFingerprints.package(currentPackage);
      if (cachedFp != currentFp) {
        return ProgrammeAdaptationReversionResult.failed(
          errorCode: 'stale_prepared_state',
          message:
              'The prepared session changed before reversion could complete. '
              'Your prepared session was not changed.',
        );
      }
    }

    final loaded = await _prepareService.loadAuthoredExecutablePlan(
      currentPackage,
      programmeContextLabel: executionContext.programmeName,
    );
    if (loaded == null) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'reconstruction_failed',
        message:
            'Cohort could not reconstruct the original programmed session. '
            'Your adapted prepared session was not changed.',
      );
    }

    final reconstructedFingerprint = ProgrammeAdaptationFingerprints.plan(
      loaded.plan,
    );
    if (reconstructedFingerprint != expectedOriginal) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'original_fingerprint_mismatch',
        message:
            'The reconstructed original prescription does not match the '
            'adaptation provenance. Your adapted prepared session was not '
            'changed.',
      );
    }

    final brief = WorkoutSessionBrief(
      sessionName: currentPackage.brief.sessionName,
      objective: currentPackage.brief.objective,
      estimatedDurationMinutes:
          loaded.plan.durationMin ??
          currentPackage.brief.estimatedDurationMinutes,
      primaryFocus: currentPackage.brief.primaryFocus,
      trainingIntent: currentPackage.brief.trainingIntent,
      sessionDifficulty: currentPackage.brief.sessionDifficulty,
      sessionNotes: currentPackage.brief.sessionNotes,
      coachNotes: loaded.plan.coachNotes ?? currentPackage.brief.coachNotes,
    );

    final PreparedExecutionPackage reverted;
    try {
      reverted = currentPackage.withRevertedToOriginal(
        originalPlan: loaded.plan,
        originalBrief: brief,
      );
    } catch (_) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'domain_reject',
        message:
            'Cohort could not restore the original prepared session safely. '
            'Your adapted prepared session was not changed.',
      );
    }

    try {
      await _prepareService.replacePreparedPackage(
        athleteId: athleteId,
        package: reverted,
        executionContext: executionContext,
      );
    } catch (_) {
      return ProgrammeAdaptationReversionResult.failed(
        errorCode: 'persist_failed',
        message:
            'Cohort could not save the restored original session. Your '
            'adapted prepared session was not changed.',
      );
    }

    return ProgrammeAdaptationReversionResult.ok(package: reverted);
  }

  bool _identityMatches(
    PreparedExecutionPackage package,
    ProgrammeExecutionContext context,
  ) {
    return package.assignmentId == context.assignmentId &&
        package.programmeVersionId == context.programmeVersionId &&
        (package.packageContentHash ?? '') ==
            (context.packageContentHash ?? '') &&
        package.programmedSessionKey.value == context.programmedSessionKey &&
        package.protocolId == context.effectiveProtocolId &&
        (package.dayKey ?? '') == context.dayKey &&
        (package.slotOrder ?? 0) == context.sessionOrder;
  }

  bool _decisionBelongsToPackage(
    AcceptedAdaptationDecision decision,
    PreparedExecutionPackage package,
  ) {
    return decision.programmedSessionKey ==
            package.programmedSessionKey.value &&
        decision.assignmentId == package.assignmentId &&
        decision.programmeVersionId == package.programmeVersionId &&
        decision.packageContentHash == package.packageContentHash &&
        decision.protocolId == package.protocolId;
  }
}
