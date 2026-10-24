import '../../../application/hyrox_base/duration_choice.dart';
import 'package:flutter/material.dart';
import '../../../domain/hyrox_base/programme_prescription.dart';
import '../../../application/hyrox_base/programme_prescription_repository.dart';
import '../../programme/screens/programme_prescription_review_screen.dart';
import '../models/bound_programme_execution.dart';

import '../../../models/block_performance_capture_mode.dart';
import '../../../models/training_session.dart';
import '../../../models/training_session_status.dart';
import '../../../models/workout_format.dart';
import '../../../domain/running_workout/running_workout.dart';
import '../../programme/models/athlete_programme_prepared_session.dart';
import '../../programme/models/programme_execution_context.dart';
import '../models/prepared_execution_package.dart';
import '../models/session_execution_plan.dart';
import '../models/structured_running_execution.dart';
import 'programme_training_session_start_store.dart';
import 'programme_training_session_start_supabase_store.dart';
import '../models/production_restore_outcome.dart';
import 'production_recovery_session_policy.dart';
import 'session_execution_launcher.dart';

enum ProgrammeSessionExecutionFailureCode {
  prescriptionConsentRequired,
  durationChoiceRequired,
  invalidPreparedIdentity,
  missingPreparedProvenance,
  missingExecutionProvenance,
  malformedPreparedProvenance,
  malformedExecutionProvenance,
  preparedProvenanceMismatch,
  unsupportedAuthoredBlock,
  recoveryGuidanceOnly,
  restoreRejected,
  sessionAlreadyCompleted,
  completedOccurrence,
  missingTrainingSession,
  trainingSessionMismatch,
  startAuthorizationFailed,
  startAuthorityMismatch,
  startPersistenceFailed,
  invalidRunningExecutionMapping,
  missingRunningTargetSnapshot,
  unexpectedRunningTargetSnapshot,
  runningTargetSnapshotMismatch,
}

class ProgrammeSessionExecutionException implements Exception {
  const ProgrammeSessionExecutionException(this.code, this.message);

  final ProgrammeSessionExecutionFailureCode code;
  final String message;

  @override
  String toString() => '${code.name}: $message';
}

class ProgrammeTrainingSessionLaunchResult {
  const ProgrammeTrainingSessionLaunchResult({
    required this.trainingSession,
    required this.wasResumed,
    this.runningTargetSnapshot,
    this.runningExecutionAuthority,
    this.boundPrescriptionSnapshot,
    this.durationChoiceSnapshot,
  });

  final TrainingSession trainingSession;
  final bool wasResumed;

  /// Immutable server-frozen v3 source/consent/target handoff; never client math.
  final Map<String, dynamic>? boundPrescriptionSnapshot;
  final Map<String, dynamic>? durationChoiceSnapshot;
  final RunningTargetSnapshotAggregate? runningTargetSnapshot;
  final AuthoredRunningExecutionAuthority? runningExecutionAuthority;

  bool get isStructuredRunningReady =>
      runningTargetSnapshot != null &&
      runningExecutionAuthority?.isAttachedForExecution == true;
}

/// Canonical programme Home → block-aware execution boundary.
///
/// The programme slot outcome is the durable occurrence-to-training-session
/// link. Reopening the same authored slot therefore resumes the same session.
class ProgrammeSessionExecutionLauncher {
  ProgrammeSessionExecutionLauncher({
    ProgrammeTrainingSessionStartStore? startStore,
    SessionExecutionLauncher? sessionExecutionLauncher,
    ProgrammePrescriptionRepository? prescriptions,
  }) : _prescriptions = prescriptions ?? ProgrammePrescriptionRepository(),
       _startStore =
           startStore ?? const ProgrammeTrainingSessionStartSupabaseStore(),
       _sessionExecution =
           sessionExecutionLauncher ?? SessionExecutionLauncher();

  final ProgrammePrescriptionRepository _prescriptions;
  final ProgrammeTrainingSessionStartStore _startStore;
  final SessionExecutionLauncher _sessionExecution;

  static final RegExp _canonicalPackageHash = RegExp(r'^[0-9a-f]{64}$');

  Future<void> launch({
    required BuildContext context,
    required String athleteId,
    required AthleteProgrammePrepareResult prepared,
  }) async {
    try {
      await _launch(context: context, athleteId: athleteId, prepared: prepared);
    } on _DurationChoiceCancelled {
      return;
    }
  }

  Future<void> _launch({
    required BuildContext context,
    required String athleteId,
    required AthleteProgrammePrepareResult prepared,
  }) async {
    final package = prepared.package;
    final preparedContext = prepared.executionContext;
    if (package == null || preparedContext == null || !prepared.isReady) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.invalidPreparedIdentity,
        'The prepared programme session is incomplete.',
      );
    }

    ProgrammeExecutionContext programmeContext = preparedContext;
    _validateRecoveryTreatment(package.plan);
    _validatePreparedIdentity(
      athleteId: athleteId,
      package: package,
      programmeContext: programmeContext,
    );
    _validateSupportedPlan(package.plan);

    ProgrammeTrainingSessionLaunchResult launchResult;
    try {
      launchResult = await _startWithDurationPrompt(
        context: context,
        athleteId: athleteId,
        programmeContext: programmeContext,
        package: package,
      );
    } on ProgrammeSessionExecutionException catch (error) {
      if (programmeContext.packageSchemaVersion != 3 ||
          error.code !=
              ProgrammeSessionExecutionFailureCode
                  .prescriptionConsentRequired) {
        rethrow;
      }
      if (!context.mounted) return;
      final state = await _prescriptions.readState(
        assignmentId: programmeContext.assignmentId,
        programmeVersionId: programmeContext.programmeVersionId,
      );
      final head = state['consent'];
      final document = state['accepted_document'];
      String? existingToken;
      if (head is Map && head['disposition'] == 'accepted' && document is Map) {
        bindProgrammePrescription(
          plan: package.plan,
          prescription: ProgrammePrescription(
            Map<String, dynamic>.from(document),
          ),
          protocolId: programmeContext.effectiveProtocolId,
          slotKey: programmeContext.packageSlotKey ?? '',
        );
        existingToken = head['consent_id'] as String;
      }
      ProgrammeTrainingSessionLaunchResult? acceptedStart;
      if (!context.mounted) return;
      if (existingToken != null) {
        try {
          programmeContext = programmeContext.copyWith(
            boundConsentId: existingToken,
          );
          acceptedStart = await _startWithDurationPrompt(
            context: context,
            athleteId: athleteId,
            programmeContext: programmeContext,
            package: package,
          );
        } on ProgrammeSessionExecutionException catch (error) {
          if (error.code !=
              ProgrammeSessionExecutionFailureCode
                  .prescriptionConsentRequired) {
            rethrow;
          }
        }
      }
      if (acceptedStart != null) {
        launchResult = acceptedStart;
      } else {
        if (!context.mounted) return;
        final token = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => ProgrammePrescriptionReviewScreen(
              athleteId: athleteId,
              executionContext: programmeContext,
              plan: package.plan,
              forLaunch: true,
            ),
          ),
        );
        if (token == null || !context.mounted) return;
        programmeContext = programmeContext.copyWith(boundConsentId: token);
        launchResult = await _startWithDurationPrompt(
          context: context,
          athleteId: athleteId,
          programmeContext: programmeContext,
          package: package,
        );
      }
    }
    var executablePlan = package.plan;
    final bound = launchResult.boundPrescriptionSnapshot;
    if (bound != null) {
      executablePlan = bindProgrammePrescription(
        plan: package.plan,
        prescription: ProgrammePrescription(bound),
        protocolId: programmeContext.effectiveProtocolId,
        slotKey: programmeContext.packageSlotKey ?? '',
      );
    }

    if (launchResult.durationChoiceSnapshot case final frozenDuration?) {
      executablePlan = applyFrozenDurationChoices(
        executablePlan,
        frozenDuration,
      );
    }
    final trainingSession = launchResult.trainingSession;
    VerifiedStructuredRunningExecution? structuredRunningExecution;
    if (launchResult.isStructuredRunningReady) {
      try {
        structuredRunningExecution =
            VerifiedStructuredRunningExecution.fromLaunch(
              plan: package.plan,
              authority: launchResult.runningExecutionAuthority!,
              frozenSnapshot: launchResult.runningTargetSnapshot!,
            );
      } on StructuredRunningExecutionException catch (error) {
        throw ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.invalidRunningExecutionMapping,
          'Structured running is unavailable (${error.code}). Re-prepare this session.',
        );
      }
    }

    if (!context.mounted) return;
    try {
      await _sessionExecution.launchActiveSessionWithPlan(
        context: context,
        plan: executablePlan,
        protocolId: programmeContext.effectiveProtocolId,
        trainingSessionId: trainingSession.id,
        athleteId: athleteId,
        programmeContext: programmeContext,
        structuredRunningExecution: structuredRunningExecution,
      );
    } on ProductionRestoreException catch (error) {
      throw ProgrammeSessionExecutionException(
        error.outcome == ProductionRestoreOutcome.completedHosted
            ? ProgrammeSessionExecutionFailureCode.sessionAlreadyCompleted
            : ProgrammeSessionExecutionFailureCode.restoreRejected,
        error.athleteMessage,
      );
    }
  }

  Future<ProgrammeTrainingSessionLaunchResult> _startWithDurationPrompt({
    required BuildContext context,
    required String athleteId,
    required ProgrammeExecutionContext programmeContext,
    required PreparedExecutionPackage package,
  }) async {
    try {
      return await createOrResumeLaunchResult(
        athleteId: athleteId,
        programmeContext: programmeContext,
        package: package,
      );
    } on ProgrammeSessionExecutionException catch (error) {
      if (error.code !=
          ProgrammeSessionExecutionFailureCode.durationChoiceRequired) {
        rethrow;
      }
      if (!context.mounted) throw const _DurationChoiceCancelled();
      final choices = await showDialog<Map<String, int>>(
        context: context,
        builder: (_) => _DurationChoiceDialog(plan: package.plan),
      );
      if (choices == null || !context.mounted) {
        throw const _DurationChoiceCancelled();
      }
      return createOrResumeLaunchResult(
        athleteId: athleteId,
        programmeContext: programmeContext,
        package: package,
        durationChoices: choices,
      );
    }
  }

  Future<TrainingSession> createOrResumeTrainingSession({
    required String athleteId,
    required ProgrammeExecutionContext programmeContext,
    required PreparedExecutionPackage package,
  }) async {
    return (await createOrResumeLaunchResult(
      athleteId: athleteId,
      programmeContext: programmeContext,
      package: package,
    )).trainingSession;
  }

  Future<ProgrammeTrainingSessionLaunchResult> createOrResumeLaunchResult({
    required String athleteId,
    required ProgrammeExecutionContext programmeContext,
    required PreparedExecutionPackage package,
    Map<String, int>? durationChoices,
  }) async {
    _validatePreparedIdentity(
      athleteId: athleteId,
      package: package,
      programmeContext: programmeContext,
    );
    if (programmeContext.packageSchemaVersion == 3 &&
        (package.hasAcceptedAdaptation ||
            programmeContext.packageSlotKey == null ||
            programmeContext.occurrenceId == null)) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.unsupportedAuthoredBlock,
        'This programme requires its exact supported authored session. Re-prepare the original session.',
      );
    }
    final runningAuthority = _runningAuthority(package);
    if (runningAuthority?.isAttachedForExecution == true) {
      _validateRunningExecutionMapping(
        authority: runningAuthority!,
        package: package,
        programmeContext: programmeContext,
      );
    }

    final durationWindows = authoredDurationWindows(package.plan);
    if (durationChoices != null) {
      validateDurationChoices(package.plan, durationChoices);
    }
    if (durationWindows.isNotEmpty &&
        programmeContext.packageSchemaVersion != 3) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.unsupportedAuthoredBlock,
        'Duration windows require the exact v3 source/start contract.',
      );
    }
    Map<String, dynamic> response;
    try {
      response = await _startStore.createOrResume(<String, dynamic>{
        if (programmeContext.occurrenceId != null)
          'occurrence_id': programmeContext.occurrenceId,
        if (programmeContext.boundConsentId != null)
          'bound_consent_id': programmeContext.boundConsentId,
        if (durationWindows.isNotEmpty)
          'duration_choices': durationChoices ?? <String, int>{},
        'assignment_id': programmeContext.assignmentId,
        'session_slot_id': programmeContext.sessionSlotId,
        'programme_version_id': programmeContext.programmeVersionId,
        'materialised_package_content_hash':
            programmeContext.packageContentHash,
        'programmed_session_key': programmeContext.programmedSessionKey,
        'planned_protocol_id': programmeContext.plannedProtocolId,
        'effective_protocol_id': programmeContext.effectiveProtocolId,
        'expected_week': programmeContext.weekNumber,
        'expected_day_key': programmeContext.dayKey,
        'expected_slot_order': programmeContext.sessionOrder,
      });
    } on ProgrammeSessionExecutionException {
      rethrow;
    } catch (_) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.startPersistenceFailed,
        'Cohort could not atomically create or resume this programme session. Retry the same authored session.',
      );
    }

    final status = response['status']?.toString();
    if (response['code'] == 'duration_choice_unavailable' &&
        response['reason'] == 'explicit_duration_choice_required') {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.durationChoiceRequired,
        'Choose your main running duration.',
      );
    }
    if (status == 'created' || status == 'resumed') {
      final sessionJson = response['training_session'];
      if (sessionJson is! Map) {
        throw const ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.missingTrainingSession,
          'The authoritative start response did not contain a training session.',
        );
      }
      final session = TrainingSession.fromMap(
        Map<String, dynamic>.from(sessionJson),
      );
      _validateTrainingSession(
        session,
        athleteId: athleteId,
        programmeContext: programmeContext,
      );
      final snapshot = _validatedRunningSnapshot(
        response: response,
        athleteId: athleteId,
        programmeContext: programmeContext,
        runningAuthority: runningAuthority,
      );
      final bound = response['bound_prescription_snapshot'];
      if (programmeContext.packageSchemaVersion != null &&
          programmeContext.packageSchemaVersion != 3 &&
          bound != null) {
        throw const ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.startAuthorityMismatch,
          'Unexpected programme targets. Reopen your authored session.',
        );
      }
      if ((programmeContext.boundConsentId != null ||
              programmeContext.packageSchemaVersion == 3) &&
          bound is! Map) {
        throw const ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.startAuthorityMismatch,
          'The bound prescription snapshot is missing.',
        );
      }
      if (bound is Map &&
          (bound['athlete_id'] != athleteId ||
              bound['assignment_id'] != programmeContext.assignmentId ||
              bound['programme_version_id'] !=
                  programmeContext.programmeVersionId ||
              bound['package_hash'] != programmeContext.packageContentHash ||
              bound['occurrence_id'] != programmeContext.occurrenceId ||
              bound['session_slot_id'] != programmeContext.sessionSlotId ||
              bound['training_session_id'].toString() !=
                  session.id.toString() ||
              (bound['source'] is! Map ||
                  bound['source']['protocol_id'] !=
                      programmeContext.effectiveProtocolId) ||
              (status == 'created' &&
                  programmeContext.boundConsentId != null &&
                  (bound['consent'] is! Map ||
                      bound['consent']['consent_id'] !=
                          programmeContext.boundConsentId)))) {
        throw const ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.startAuthorityMismatch,
          'The bound prescription snapshot does not match this canonical start.',
        );
      }
      final duration = response['duration_choice_snapshot'];
      if (durationWindows.isNotEmpty) {
        if (duration is! Map ||
            duration['athlete_id'] != athleteId ||
            duration['occurrence_id'] != programmeContext.occurrenceId ||
            duration['assignment_id'] != programmeContext.assignmentId ||
            duration['programme_version_id'] !=
                programmeContext.programmeVersionId ||
            duration['training_session_id'].toString() !=
                session.id.toString()) {
          throw const ProgrammeSessionExecutionException(
            ProgrammeSessionExecutionFailureCode.startAuthorityMismatch,
            'Frozen duration choice does not match the canonical start.',
          );
        }
        applyFrozenDurationChoices(
          package.plan,
          Map<String, dynamic>.from(duration),
        );
      } else if (duration != null) {
        throw const ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.startAuthorityMismatch,
          'Unexpected duration choice snapshot.',
        );
      }
      return ProgrammeTrainingSessionLaunchResult(
        durationChoiceSnapshot: duration is Map
            ? _freezeBoundSnapshot(duration)
            : null,
        boundPrescriptionSnapshot: bound is Map
            ? _freezeBoundSnapshot(bound)
            : null,
        trainingSession: session,
        wasResumed: status == 'resumed',
        runningTargetSnapshot: snapshot,
        runningExecutionAuthority: runningAuthority,
      );
    }

    if (programmeContext.packageSchemaVersion == 3 &&
        {
          'missing_stale_or_withdrawn_consent',
          'stale_review_or_benchmark',
          'stale_benchmark_revision',
        }.contains(response['reason'])) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.prescriptionConsentRequired,
        'Review and accept programme targets before a new start.',
      );
    }
    _throwStartFailure(response);
  }

  AuthoredRunningExecutionAuthority? _runningAuthority(
    PreparedExecutionPackage package,
  ) {
    final raw = package.authoredRunningV1;
    if (raw == null) return null;
    try {
      return AuthoredRunningExecutionAuthority.fromCanonicalJson(raw);
    } on RunningExecutionAuthorityException catch (error) {
      throw ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.invalidRunningExecutionMapping,
        'The authored running authority is invalid (${error.code}). Re-prepare this session.',
      );
    }
  }

  void _validateRunningExecutionMapping({
    required AuthoredRunningExecutionAuthority authority,
    required PreparedExecutionPackage package,
    required ProgrammeExecutionContext programmeContext,
  }) {
    if (programmeContext.occurrenceId?.trim().isEmpty != false) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.invalidRunningExecutionMapping,
        'Structured running requires an exact fixed-schedule occurrence.',
      );
    }
    final blockId = authority.exactSessionBlockId!;
    final matching = package.plan.blocks
        .where((block) => block.blockId == blockId)
        .toList(growable: false);
    if (matching.length != 1 || matching.single.timerConfiguration == null) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.invalidRunningExecutionMapping,
        'The structured running mapping does not resolve to one exact executable block.',
      );
    }
    final block = matching.single;
    final projected = const RunningWorkoutProjector().project(
      format: block.workoutFormat,
      configuration: block.timerConfiguration!,
      sourceRef: block.blockId,
    );
    final workout = projected.workout;
    final projectedStepIds = <String>[];
    if (workout != null) {
      for (final node in workout.steps) {
        switch (node) {
          case RunningAtomicStep():
            projectedStepIds.add(node.stepId);
          case RunningRepeatGroup():
            projectedStepIds.addAll(node.steps.map((step) => step.stepId));
        }
      }
    }
    if (!projected.isSupported ||
        workout == null ||
        workout.workoutId != authority.workoutId ||
        !_sameStrings(projectedStepIds, authority.stepIds)) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.invalidRunningExecutionMapping,
        'The structured running IDs do not match the exact B1 executable block.',
      );
    }
  }

  RunningTargetSnapshotAggregate? _validatedRunningSnapshot({
    required Map<String, dynamic> response,
    required String athleteId,
    required ProgrammeExecutionContext programmeContext,
    required AuthoredRunningExecutionAuthority? runningAuthority,
  }) {
    final raw = response['running_target_snapshot'];
    final snapshotExpected =
        programmeContext.occurrenceId != null && runningAuthority != null;
    if (raw == null) {
      if (snapshotExpected) {
        throw const ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.missingRunningTargetSnapshot,
          'The authoritative start response omitted the frozen running target snapshot.',
        );
      }
      return null;
    }
    if (runningAuthority == null || raw is! Map) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.unexpectedRunningTargetSnapshot,
        'The start response returned running authority for an unattached session.',
      );
    }
    try {
      final snapshot = RunningTargetSnapshotAggregate.fromJson(
        Map<String, dynamic>.from(raw),
      );
      final expectedScopes = {
        for (final attachment in runningAuthority.attachmentScopes)
          attachment.attachmentId: attachment.stepIds,
      };
      if (snapshot.athleteId != athleteId.trim() ||
          snapshot.occurrenceId != programmeContext.occurrenceId ||
          snapshot.assignmentId != programmeContext.assignmentId ||
          snapshot.programmeVersionId != programmeContext.programmeVersionId ||
          snapshot.sessionSlotId != programmeContext.sessionSlotId ||
          snapshot.packageContentHash != programmeContext.packageContentHash ||
          snapshot.workoutId != runningAuthority.workoutId ||
          snapshot.targets.length != expectedScopes.length) {
        throw const RunningExecutionAuthorityException(
          'snapshot_authority_mismatch',
          'Frozen snapshot identity does not match launch authority.',
        );
      }
      final seen = <String>{};
      for (final target in snapshot.targets) {
        final expectedSteps = expectedScopes[target.attachmentId];
        if (!seen.add(target.attachmentId) ||
            expectedSteps == null ||
            target.workoutId != snapshot.workoutId ||
            target.frozenAtUtc != snapshot.frozenAtUtc ||
            !_sameStrings(target.stepIds, expectedSteps) ||
            (target.benchmarkAthleteId != null &&
                target.benchmarkAthleteId != athleteId.trim())) {
          throw const RunningExecutionAuthorityException(
            'snapshot_scope_mismatch',
            'Frozen snapshot target scope does not match authored authority.',
          );
        }
      }
      return snapshot;
    } on RunningExecutionAuthorityException catch (error) {
      throw ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.runningTargetSnapshotMismatch,
        'The frozen running target snapshot failed validation (${error.code}).',
      );
    }
  }

  void _validatePreparedIdentity({
    required String athleteId,
    required PreparedExecutionPackage package,
    required ProgrammeExecutionContext programmeContext,
  }) {
    final programmedKey = programmeContext.programmedSessionKey?.trim();
    final lineageCode = programmeContext.lineageCode?.trim();
    final expectedHash = programmeContext.packageContentHash;
    final preparedHash = package.packageContentHash;

    if (expectedHash == null || expectedHash.isEmpty) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.missingExecutionProvenance,
        'The authored execution context is missing package provenance. Re-prepare this session and retry.',
      );
    }
    if (!_canonicalPackageHash.hasMatch(expectedHash)) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.malformedExecutionProvenance,
        'The authored execution context has invalid package provenance. Re-prepare this session and retry.',
      );
    }
    if (preparedHash == null || preparedHash.isEmpty) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.missingPreparedProvenance,
        'The prepared session is missing package provenance. Re-prepare it and retry.',
      );
    }
    if (!_canonicalPackageHash.hasMatch(preparedHash)) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.malformedPreparedProvenance,
        'The prepared session has invalid package provenance. Re-prepare it and retry.',
      );
    }
    if (preparedHash != expectedHash) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.preparedProvenanceMismatch,
        'The prepared session does not match the authored package. Re-prepare it and retry.',
      );
    }

    if (athleteId.trim().isEmpty ||
        !programmeContext.isProgrammeBacked ||
        programmedKey == null ||
        programmedKey.isEmpty ||
        lineageCode == null ||
        lineageCode.isEmpty ||
        package.programmedSessionKey.value != programmedKey ||
        package.assignmentId != programmeContext.assignmentId ||
        package.programmeVersionId != programmeContext.programmeVersionId ||
        package.dayKey != programmeContext.dayKey ||
        package.slotOrder != programmeContext.sessionOrder ||
        package.protocolId != programmeContext.effectiveProtocolId ||
        !package.plan.hasExecutableBlocks) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.invalidPreparedIdentity,
        'The prepared session no longer matches programme authority.',
      );
    }
  }

  Never _throwStartFailure(Map<String, dynamic> response) {
    final code = response['code']?.toString();
    final failureCode = switch (code) {
      'completed_occurrence' =>
        ProgrammeSessionExecutionFailureCode.completedOccurrence,
      'missing_training_session' =>
        ProgrammeSessionExecutionFailureCode.missingTrainingSession,
      'training_session_mismatch' =>
        ProgrammeSessionExecutionFailureCode.trainingSessionMismatch,
      'authentication_required' ||
      'athlete_role_required' ||
      'cross_athlete_assignment' ||
      'cross_athlete_occurrence' =>
        ProgrammeSessionExecutionFailureCode.startAuthorizationFailed,
      'assignment_missing' ||
      'assignment_inactive' ||
      'assignment_not_materialised' ||
      'exact_version_missing' ||
      'package_hash_mismatch' ||
      'stale_cursor' ||
      'authored_slot_mismatch' ||
      'programme_key_mismatch' ||
      'occurrence_identity_conflict' ||
      'occurrence_missing' ||
      'occurrence_lineage_mismatch' ||
      'occurrence_session_integrity_failure' ||
      'fixed_assignment_ineligible' ||
      'fixed_occurrence_ineligible' ||
      'future_occurrence' ||
      'missed_occurrence' =>
        ProgrammeSessionExecutionFailureCode.startAuthorityMismatch,
      _ => ProgrammeSessionExecutionFailureCode.startPersistenceFailed,
    };
    throw ProgrammeSessionExecutionException(
      failureCode,
      'Cohort could not start this exact authored session (${code ?? 'unknown_start_failure'}). Re-prepare or retry without changing the session.',
    );
  }

  void _validateRecoveryTreatment(SessionExecutionPlan plan) {
    const policy = ProductionRecoverySessionPolicy();
    final treatment = policy.decide(
      plan: plan,
      authoredAsRecoveryOrRest: !plan.hasExecutableBlocks,
    );
    if (treatment == ProductionRecoveryTreatment.guidanceOnly) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.recoveryGuidanceOnly,
        'This is a rest or recovery day. There is no workout to begin.',
      );
    }
    if (treatment == ProductionRecoveryTreatment.unavailable) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.unsupportedAuthoredBlock,
        'This session format is not available yet.',
      );
    }
  }

  void _validateSupportedPlan(SessionExecutionPlan plan) {
    for (final block in plan.blocks.where(
      (candidate) => candidate.hasAthleteVisibleContent,
    )) {
      final unsupportedOther =
          block.workoutFormat == WorkoutFormat.other &&
          block.performanceCaptureMode == BlockPerformanceCaptureMode.automatic;
      if (unsupportedOther) {
        throw ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.unsupportedAuthoredBlock,
          'Block "${block.title}" (${block.blockId}) uses unsupported workout format "other" without an explicit performance capture mode.',
        );
      }
    }
  }

  void _validateTrainingSession(
    TrainingSession session, {
    required String athleteId,
    required ProgrammeExecutionContext programmeContext,
  }) {
    final lineageCode = programmeContext.lineageCode?.trim();
    final programmeMatches =
        session.programmeId == lineageCode ||
        session.programmeId == programmeContext.programmeVersionId;
    if (session.status != TrainingSessionStatus.inProgress ||
        session.athleteId != athleteId.trim() ||
        session.protocolId != programmeContext.effectiveProtocolId ||
        !programmeMatches ||
        session.weekNumber != programmeContext.weekNumber ||
        session.day != programmeContext.dayKey) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.trainingSessionMismatch,
        'The stored training session does not match this authored occurrence.',
      );
    }
  }
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Map<String, dynamic> _freezeBoundSnapshot(Map value) =>
    Map<String, dynamic>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: _freezeBoundValue(entry.value),
    });
Object? _freezeBoundValue(Object? value) {
  if (value is Map) return _freezeBoundSnapshot(value);
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_freezeBoundValue));
  }
  return value;
}

class _DurationChoiceCancelled implements Exception {
  const _DurationChoiceCancelled();
}

class _DurationChoiceDialog extends StatefulWidget {
  const _DurationChoiceDialog({required this.plan});
  final SessionExecutionPlan plan;
  @override
  State<_DurationChoiceDialog> createState() => _DurationChoiceDialogState();
}

class _DurationChoiceDialogState extends State<_DurationChoiceDialog> {
  final controllers = <String, TextEditingController>{};
  String? error;
  @override
  void initState() {
    super.initState();
    for (final id in authoredDurationWindows(widget.plan).keys) {
      controllers[id] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose main running duration'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in authoredDurationWindows(widget.plan).entries)
            TextField(
              controller: controllers[e.key],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${e.value[0] ~/ 60}–${e.value[1] ~/ 60} minutes',
                helperText:
                    'Main running only; preparation and cooldown are additional.',
              ),
            ),
          if (error != null) Text(error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final result = <String, int>{};
          for (final e in controllers.entries) {
            final minutes = int.tryParse(e.value.text.trim());
            if (minutes != null) result[e.key] = minutes * 60;
          }
          try {
            validateDurationChoices(widget.plan, result);
            Navigator.pop(context, result);
          } on FormatException catch (e) {
            setState(() => error = e.message);
          }
        },
        child: const Text('Use duration'),
      ),
    ],
  );
}
