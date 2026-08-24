import 'package:flutter/material.dart';

import '../../../models/block_performance_capture_mode.dart';
import '../../../models/training_session.dart';
import '../../../models/training_session_status.dart';
import '../../../models/workout_format.dart';
import '../../programme/models/athlete_programme_prepared_session.dart';
import '../../programme/models/programme_execution_context.dart';
import '../models/prepared_execution_package.dart';
import '../models/session_execution_plan.dart';
import 'programme_training_session_start_store.dart';
import 'programme_training_session_start_supabase_store.dart';
import 'session_execution_launcher.dart';

enum ProgrammeSessionExecutionFailureCode {
  invalidPreparedIdentity,
  missingPreparedProvenance,
  missingExecutionProvenance,
  malformedPreparedProvenance,
  malformedExecutionProvenance,
  preparedProvenanceMismatch,
  unsupportedAuthoredBlock,
  completedOccurrence,
  missingTrainingSession,
  trainingSessionMismatch,
  startAuthorizationFailed,
  startAuthorityMismatch,
  startPersistenceFailed,
}

class ProgrammeSessionExecutionException implements Exception {
  const ProgrammeSessionExecutionException(this.code, this.message);

  final ProgrammeSessionExecutionFailureCode code;
  final String message;

  @override
  String toString() => '${code.name}: $message';
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

    _validatePreparedIdentity(
      athleteId: athleteId,
      package: package,
      programmeContext: programmeContext,
    );
    _validateSupportedPlan(package.plan);

    final trainingSession = await createOrResumeTrainingSession(
      athleteId: athleteId,
      programmeContext: programmeContext,
      package: package,
    );

    if (!context.mounted) return;
    await _sessionExecution.launchActiveSessionWithPlan(
      context: context,
      plan: package.plan,
      protocolId: programmeContext.effectiveProtocolId,
      trainingSessionId: trainingSession.id,
      athleteId: athleteId,
      programmeContext: programmeContext,
    );
  }

  Future<TrainingSession> createOrResumeTrainingSession({
    required String athleteId,
    required ProgrammeExecutionContext programmeContext,
    required PreparedExecutionPackage package,
  }) async {
    _validatePreparedIdentity(
      athleteId: athleteId,
      package: package,
      programmeContext: programmeContext,
    );

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
      return session;
    }

    _throwStartFailure(response);
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
