import 'package:flutter/material.dart';

import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../../models/block_performance_capture_mode.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_vocabulary.dart';
import '../../../models/training_session.dart';
import '../../../models/training_session_status.dart';
import '../../../models/workout_format.dart';
import '../../programme/models/athlete_programme_prepared_session.dart';
import '../../programme/models/programme_execution_context.dart';
import '../models/prepared_execution_package.dart';
import '../models/session_execution_plan.dart';
import 'programme_session_progression_coordinator.dart';
import 'session_execution_launcher.dart';

enum ProgrammeSessionExecutionFailureCode {
  invalidPreparedIdentity,
  unsupportedAuthoredBlock,
  completedOccurrence,
  missingTrainingSession,
  trainingSessionMismatch,
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
    TrainingSessionRepository? trainingSessionRepository,
    ProgrammeSlotOutcomeStore? slotOutcomeStore,
    ProgrammeSessionProgressionCoordinator? progressionCoordinator,
    SessionExecutionLauncher? sessionExecutionLauncher,
  }) : _trainingSessions =
           trainingSessionRepository ?? const TrainingSessionRepository(),
       _slotOutcomes =
           slotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore(),
       _progression =
           progressionCoordinator ?? ProgrammeSessionProgressionCoordinator(),
       _sessionExecution =
           sessionExecutionLauncher ?? SessionExecutionLauncher();

  final TrainingSessionRepository _trainingSessions;
  final ProgrammeSlotOutcomeStore _slotOutcomes;
  final ProgrammeSessionProgressionCoordinator _progression;
  final SessionExecutionLauncher _sessionExecution;

  /// Retains an unlinked create across a retry in the same app process.
  ///
  /// Durable success is still established only by [ProgrammeSlotOutcome].
  final Map<String, int> _pendingTrainingSessionIds = {};

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
  }) async {
    final occurrenceKey = _occurrenceKey(programmeContext);
    final existingOutcome = await _slotOutcomes.getForSlot(
      assignmentId: programmeContext.assignmentId,
      sessionSlotId: programmeContext.sessionSlotId,
    );
    final linkedSessionId = existingOutcome?.trainingSessionId;

    if (existingOutcome?.isTerminal == true) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.completedOccurrence,
        'This authored programme session has already been completed.',
      );
    }

    if (linkedSessionId != null) {
      final linked = await _trainingSessions.getSessionById(linkedSessionId);
      if (linked == null) {
        throw const ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.missingTrainingSession,
          'The in-progress programme session could not be restored.',
        );
      }
      _validateTrainingSession(
        linked,
        athleteId: athleteId,
        programmeContext: programmeContext,
      );
      return linked;
    }

    TrainingSession session;
    final pendingId = _pendingTrainingSessionIds[occurrenceKey];
    if (pendingId != null) {
      final pending = await _trainingSessions.getSessionById(pendingId);
      if (pending == null) {
        throw const ProgrammeSessionExecutionException(
          ProgrammeSessionExecutionFailureCode.missingTrainingSession,
          'The pending programme session could not be restored.',
        );
      }
      _validateTrainingSession(
        pending,
        athleteId: athleteId,
        programmeContext: programmeContext,
      );
      session = pending;
    } else {
      session = await _trainingSessions.createSession(
        athleteId: athleteId,
        protocolId: programmeContext.effectiveProtocolId,
        status: TrainingSessionStatus.inProgress,
        programmeId: programmeContext.programmeVersionId,
        weekNumber: programmeContext.weekNumber,
        day: programmeContext.dayKey,
      );
      _pendingTrainingSessionIds[occurrenceKey] = session.id;
    }

    ProgrammeSlotOutcome? persistedOutcome;
    try {
      final start = await _progression.markSessionStartedIfProgrammeBacked(
        athleteId: athleteId,
        programmeContext: programmeContext,
        trainingSessionId: session.id,
      );
      persistedOutcome = start?.outcome;
    } catch (_) {
      persistedOutcome = await _slotOutcomes.getForSlot(
        assignmentId: programmeContext.assignmentId,
        sessionSlotId: programmeContext.sessionSlotId,
      );
    }

    if (persistedOutcome?.outcomeStatus !=
            ProgrammeSlotOutcomeStatus.inProgress ||
        persistedOutcome?.trainingSessionId != session.id) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.startPersistenceFailed,
        'Cohort could not establish the in-progress programme session. Retry to resume the same attempt.',
      );
    }

    _pendingTrainingSessionIds.remove(occurrenceKey);
    return session;
  }

  void _validatePreparedIdentity({
    required String athleteId,
    required PreparedExecutionPackage package,
    required ProgrammeExecutionContext programmeContext,
  }) {
    final programmedKey = programmeContext.programmedSessionKey?.trim();
    if (athleteId.trim().isEmpty ||
        !programmeContext.isProgrammeBacked ||
        programmeContext.packageContentHash?.trim().isEmpty != false ||
        programmedKey == null ||
        programmedKey.isEmpty ||
        package.programmedSessionKey.value != programmedKey ||
        package.assignmentId != programmeContext.assignmentId ||
        package.programmeVersionId != programmeContext.programmeVersionId ||
        package.protocolId != programmeContext.effectiveProtocolId ||
        !package.plan.hasExecutableBlocks) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.invalidPreparedIdentity,
        'The prepared session no longer matches programme authority.',
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
    if (session.status != TrainingSessionStatus.inProgress ||
        session.athleteId != athleteId.trim() ||
        session.protocolId != programmeContext.effectiveProtocolId ||
        session.programmeId != programmeContext.programmeVersionId ||
        session.weekNumber != programmeContext.weekNumber ||
        session.day != programmeContext.dayKey) {
      throw const ProgrammeSessionExecutionException(
        ProgrammeSessionExecutionFailureCode.trainingSessionMismatch,
        'The stored training session does not match this authored occurrence.',
      );
    }
  }

  String _occurrenceKey(ProgrammeExecutionContext context) {
    return '${context.assignmentId}:${context.sessionSlotId}:'
        '${context.programmedSessionKey ?? ''}';
  }
}
