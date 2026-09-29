import 'package:flutter/material.dart';

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
  });

  final TrainingSession trainingSession;
  final bool wasResumed;
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
  }) : _startStore =
           startStore ?? const ProgrammeTrainingSessionStartSupabaseStore(),
       _sessionExecution =
           sessionExecutionLauncher ?? SessionExecutionLauncher();

  final ProgrammeTrainingSessionStartStore _startStore;
  final SessionExecutionLauncher _sessionExecution;

  static final RegExp _canonicalPackageHash = RegExp(r'^[0-9a-f]{64}$');

  Future<void> launch({
    required BuildContext context,
    required String athleteId,
    required AthleteProgrammePrepareResult prepared,
  }) async {
    final package = prepared.package;
    final programmeContext = prepared.executionContext;
    if (package == null || programmeContext == null || !prepared.isReady) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.invalidPreparedIdentity,
        'The prepared programme session is incomplete.',
      );
    }

    _validateRecoveryTreatment(package.plan);
    _validatePreparedIdentity(
      athleteId: athleteId,
      package: package,
      programmeContext: programmeContext,
    );
    _validateSupportedPlan(package.plan);

    final launchResult = await createOrResumeLaunchResult(
      athleteId: athleteId,
      programmeContext: programmeContext,
      package: package,
    );
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
        plan: package.plan,
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
  }) async {
    _validatePreparedIdentity(
      athleteId: athleteId,
      package: package,
      programmeContext: programmeContext,
    );
    final runningAuthority = _runningAuthority(package);
    if (runningAuthority?.isAttachedForExecution == true) {
      _validateRunningExecutionMapping(
        authority: runningAuthority!,
        package: package,
        programmeContext: programmeContext,
      );
    }

    Map<String, dynamic> response;
    try {
      response = await _startStore.createOrResume(<String, dynamic>{
        if (programmeContext.occurrenceId != null)
          'occurrence_id': programmeContext.occurrenceId,
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
      return ProgrammeTrainingSessionLaunchResult(
        trainingSession: session,
        wasResumed: status == 'resumed',
        runningTargetSnapshot: snapshot,
        runningExecutionAuthority: runningAuthority,
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
