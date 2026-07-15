import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../../models/programme_vocabulary.dart';
import '../errors/programme_progression_exception.dart';
import '../models/programme_progression_result.dart';
import '../models/programme_schedule_resolution.dart';
import '../models/programme_suggested_cursor.dart';
import '../models/resolved_today_session.dart';
import 'athlete_state_sync_service.dart';
import 'programme_progression_service.dart';
import 'programme_schedule_resolver.dart';
import 'programme_slot_outcome_service.dart';
import 'today_session_service.dart';

/// Advances assignment cursor and syncs athlete_state after slot outcomes.
class ProgrammeProgressionServiceImpl implements ProgrammeProgressionService {
  const ProgrammeProgressionServiceImpl({
    required ProgrammeAssignmentStore assignmentStore,
    required ProgrammeSlotOutcomeStore slotOutcomeStore,
    required ProgrammeVersionStore versionStore,
    required ProgrammeSlotOutcomeService slotOutcomeService,
    required ProgrammeScheduleResolver scheduleResolver,
    required TodaySessionService todaySessionService,
    required AthleteStateSyncService athleteStateSyncService,
  })  : _assignmentStore = assignmentStore,
        _slotOutcomeStore = slotOutcomeStore,
        _versionStore = versionStore,
        _slotOutcomeService = slotOutcomeService,
        _scheduleResolver = scheduleResolver,
        _todaySessionService = todaySessionService,
        _athleteStateSyncService = athleteStateSyncService;

  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeSlotOutcomeStore _slotOutcomeStore;
  final ProgrammeVersionStore _versionStore;
  final ProgrammeSlotOutcomeService _slotOutcomeService;
  final ProgrammeScheduleResolver _scheduleResolver;
  final TodaySessionService _todaySessionService;
  final AthleteStateSyncService _athleteStateSyncService;

  @override
  Future<ProgrammeProgressionResult> markSessionStarted({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
  }) {
    return resolveAfterOutcome(
      athleteId: athleteId,
      resolution: resolution,
      outcomeStatus: ProgrammeSlotOutcomeStatus.inProgress,
      trainingSessionId: trainingSessionId,
      advanceCursor: false,
    );
  }

  @override
  Future<ProgrammeProgressionResult> completeSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
    String? resolutionNote,
  }) {
    return resolveAfterOutcome(
      athleteId: athleteId,
      resolution: resolution,
      outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
      trainingSessionId: trainingSessionId,
      resolutionNote: resolutionNote,
    );
  }

  @override
  Future<ProgrammeProgressionResult> completeSessionPartial({
    required String athleteId,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
    String? resolutionNote,
  }) {
    return resolveAfterOutcome(
      athleteId: athleteId,
      resolution: resolution,
      outcomeStatus: ProgrammeSlotOutcomeStatus.completedPartial,
      trainingSessionId: trainingSessionId,
      resolutionNote: resolutionNote,
    );
  }

  @override
  Future<ProgrammeProgressionResult> skipSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    String? resolutionNote,
  }) {
    return resolveAfterOutcome(
      athleteId: athleteId,
      resolution: resolution,
      outcomeStatus: ProgrammeSlotOutcomeStatus.skipped,
      resolutionNote: resolutionNote,
    );
  }

  @override
  Future<ProgrammeProgressionResult> replaceSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
    required String replacementProtocolId,
    int? trainingSessionId,
    String? resolutionNote,
  }) {
    return resolveAfterOutcome(
      athleteId: athleteId,
      resolution: resolution,
      outcomeStatus: ProgrammeSlotOutcomeStatus.replaced,
      trainingSessionId: trainingSessionId,
      replacementProtocolId: replacementProtocolId,
      resolutionNote: resolutionNote,
      advanceCursor: trainingSessionId != null,
    );
  }

  @override
  Future<ProgrammeProgressionResult> resolveAfterOutcome({
    required String athleteId,
    required ResolvedTodaySession resolution,
    required ProgrammeSlotOutcomeStatus outcomeStatus,
    int? trainingSessionId,
    String? replacementProtocolId,
    String? resolutionNote,
    bool advanceCursor = true,
  }) async {
    final assignment = await _assignmentStore.getActiveAssignment(athleteId);
    if (assignment == null) {
      return ProgrammeProgressionResult.noActiveProgramme();
    }

    if (_isStaleResolution(assignment: assignment, resolution: resolution)) {
      return ProgrammeProgressionResult.staleResolution(
        message:
            'ResolvedTodaySession no longer matches assignment cursor '
            '(week ${assignment.currentWeek} ${assignment.currentDayKey} '
            'slot ${assignment.currentSessionOrder})',
      );
    }

    if (outcomeStatus == ProgrammeSlotOutcomeStatus.rescheduled) {
      return ProgrammeProgressionResult.staleResolution(
        message: 'Rescheduled slots remain unresolved until destination completes',
      );
    }

    final existingOutcome = await _slotOutcomeStore.getForSlot(
      assignmentId: assignment.id,
      sessionSlotId: resolution.slotId!,
    );

    if (_isIdempotentReplay(
      assignment: assignment,
      existingOutcome: existingOutcome,
      outcomeStatus: outcomeStatus,
      trainingSessionId: trainingSessionId,
      advanceCursor: advanceCursor,
    )) {
      final nextSession = await _todaySessionService.resolveForAthlete(athleteId);
      return ProgrammeProgressionResult.completed(
        outcome: existingOutcome!,
        updatedAssignment: assignment,
        nextResolvedSession: nextSession,
        athleteStateSynced: false,
        warnings: const ['Idempotent replay — no changes applied'],
      );
    }

    ProgrammeSlotOutcome outcome;
    try {
      outcome = await _slotOutcomeService.upsertFromResolution(
        resolution: resolution,
        outcomeStatus: outcomeStatus,
        trainingSessionId: trainingSessionId,
        replacementProtocolId: replacementProtocolId,
        resolutionNote: resolutionNote,
      );
    } catch (error) {
      throw ProgrammeProgressionException(
        ProgrammeProgressionErrorCode.outcomePersistenceFailed,
        'Failed to persist programme slot outcome',
        details: error.toString(),
      );
    }

    ProgrammeAssignment updatedAssignment = assignment;
    final warnings = <String>[];

    if (advanceCursor && outcomeStatus.isTerminal) {
      try {
        updatedAssignment = await _advanceAssignmentCursor(
          assignment: assignment,
          resolution: resolution,
          trainingSessionId: trainingSessionId,
        );
        updatedAssignment = await _reloadAssignment(updatedAssignment);
      } catch (error) {
        return ProgrammeProgressionResult.partialSuccess(
          outcome: outcome,
          warnings: [
            'Outcome persisted but assignment cursor update failed: $error',
          ],
        );
      }
    } else if (!advanceCursor && outcomeStatus == ProgrammeSlotOutcomeStatus.replaced) {
      updatedAssignment = assignment;
    } else {
      updatedAssignment = await _reloadAssignment(updatedAssignment);
    }

    ResolvedTodaySession nextSession;
    if (!advanceCursor && outcomeStatus == ProgrammeSlotOutcomeStatus.replaced) {
      nextSession = _resolutionWithReplacement(
        resolution: resolution,
        replacementProtocolId: replacementProtocolId!,
        outcome: outcome,
      );
    } else if (updatedAssignment.status == ProgrammeAssignmentStatus.completed) {
      final tree = await _versionStore.loadTemplateTree(
        updatedAssignment.programmeVersionId,
      );
      if (tree == null) {
        throw ProgrammeProgressionException(
          ProgrammeProgressionErrorCode.assignmentUpdateFailed,
          'Pinned programme version could not be loaded',
        );
      }

      nextSession = ResolvedTodaySession.fromResolution(
        _scheduleResolver.resolve(
          assignment: updatedAssignment,
          tree: tree,
          outcomes: await _slotOutcomeStore.listForAssignment(
            updatedAssignment.id,
          ),
        ),
      );
    } else {
      nextSession = await _todaySessionService.resolveForAthlete(athleteId);
    }

    var athleteStateSynced = false;
    try {
      await _athleteStateSyncService.syncFromResolvedSession(
        athleteId: athleteId,
        resolution: nextSession,
      );
      athleteStateSynced = true;
    } catch (error) {
      warnings.add('athlete_state sync failed: $error');
      return ProgrammeProgressionResult.partialSuccess(
        outcome: outcome,
        updatedAssignment: updatedAssignment,
        nextResolvedSession: nextSession,
        warnings: warnings,
      );
    }

    if (warnings.isEmpty) {
      return ProgrammeProgressionResult.completed(
        outcome: outcome,
        updatedAssignment: updatedAssignment,
        nextResolvedSession: nextSession,
        athleteStateSynced: athleteStateSynced,
      );
    }

    return ProgrammeProgressionResult.partialSuccess(
      outcome: outcome,
      updatedAssignment: updatedAssignment,
      nextResolvedSession: nextSession,
      warnings: warnings,
    );
  }

  Future<ProgrammeAssignment> _advanceAssignmentCursor({
    required ProgrammeAssignment assignment,
    required ResolvedTodaySession resolution,
    int? trainingSessionId,
  }) async {
    final tree = await _versionStore.loadTemplateTree(
      assignment.programmeVersionId,
    );
    if (tree == null) {
      throw ProgrammeProgressionException(
        ProgrammeProgressionErrorCode.assignmentUpdateFailed,
        'Pinned programme version could not be loaded',
      );
    }

    final outcomes = await _slotOutcomeStore.listForAssignment(assignment.id);
    final scheduleResolution = _scheduleResolver.resolve(
      assignment: assignment,
      tree: tree,
      outcomes: outcomes,
    );

    ProgrammeAssignment updated = assignment;

    switch (scheduleResolution.kind) {
      case ProgrammeScheduleResolutionKind.executableSlot:
        final slot = scheduleResolution.slot;
        if (slot != null &&
            (slot.id != resolution.slotId ||
                slot.sessionOrder != assignment.currentSessionOrder)) {
          updated = assignment.copyWith(
            currentSessionOrder: slot.sessionOrder,
            lastProgressedTrainingSessionId: trainingSessionId,
          );
        } else if (trainingSessionId != null) {
          updated = assignment.copyWith(
            lastProgressedTrainingSessionId: trainingSessionId,
          );
        }
      case ProgrammeScheduleResolutionKind.dayComplete:
        final next = scheduleResolution.suggestedNextCursor;
        if (next != null) {
          updated = _assignmentAtCursor(
            assignment: assignment,
            cursor: next,
            trainingSessionId: trainingSessionId,
          );
        }
      case ProgrammeScheduleResolutionKind.programmeComplete:
        updated = assignment.copyWith(
          status: ProgrammeAssignmentStatus.completed,
          completedAt: DateTime.now().toUtc(),
          lastProgressedTrainingSessionId: trainingSessionId,
        );
      case ProgrammeScheduleResolutionKind.restDay:
        if (trainingSessionId != null) {
          updated = assignment.copyWith(
            lastProgressedTrainingSessionId: trainingSessionId,
          );
        }
    }

    if (_assignmentCursorEquals(assignment, updated) &&
        assignment.status == updated.status &&
        assignment.lastProgressedTrainingSessionId ==
            updated.lastProgressedTrainingSessionId) {
      return assignment;
    }

    return _assignmentStore.update(updated);
  }

  Future<ProgrammeAssignment> _reloadAssignment(
    ProgrammeAssignment assignment,
  ) async {
    final reloaded = await _assignmentStore.getById(assignment.id);
    return reloaded ?? assignment;
  }

  ProgrammeAssignment _assignmentAtCursor({
    required ProgrammeAssignment assignment,
    required ProgrammeSuggestedCursor cursor,
    int? trainingSessionId,
  }) {
    return assignment.copyWith(
      currentWeek: cursor.weekNumber,
      currentDayKey: cursor.dayKey,
      currentSessionOrder: cursor.slotOrder,
      lastProgressedTrainingSessionId: trainingSessionId,
    );
  }

  ResolvedTodaySession _resolutionWithReplacement({
    required ResolvedTodaySession resolution,
    required String replacementProtocolId,
    required ProgrammeSlotOutcome outcome,
  }) {
    return ResolvedTodaySession(
      kind: ResolvedTodaySessionKind.executable,
      assignmentId: resolution.assignmentId,
      programmeVersionId: resolution.programmeVersionId,
      lineageCode: resolution.lineageCode,
      programmeName: resolution.programmeName,
      versionNumber: resolution.versionNumber,
      weekNumber: resolution.weekNumber,
      dayKey: resolution.dayKey,
      dayTitle: resolution.dayTitle,
      dayType: resolution.dayType,
      dayIntent: resolution.dayIntent,
      slotId: resolution.slotId,
      slotOrder: resolution.slotOrder,
      slotTitle: resolution.slotTitle,
      plannedProtocolId: resolution.plannedProtocolId,
      effectiveProtocolId: replacementProtocolId,
      outcomeStatus: ProgrammeSlotOutcomeStatus.replaced,
      isOptional: resolution.isOptional,
      assignment: resolution.assignment,
      slotOutcome: outcome,
    );
  }

  bool _isStaleResolution({
    required ProgrammeAssignment assignment,
    required ResolvedTodaySession resolution,
  }) {
    if (resolution.assignmentId != assignment.id) return true;
    if (resolution.weekNumber != assignment.currentWeek) return true;
    if (resolution.dayKey != assignment.currentDayKey) return true;
    if (resolution.slotOrder != assignment.currentSessionOrder) return true;
    if (resolution.slotId == null) return true;

    return false;
  }

  bool _isIdempotentReplay({
    required ProgrammeAssignment assignment,
    required ProgrammeSlotOutcome? existingOutcome,
    required ProgrammeSlotOutcomeStatus outcomeStatus,
    int? trainingSessionId,
    required bool advanceCursor,
  }) {
    if (existingOutcome == null) return false;
    if (existingOutcome.outcomeStatus != outcomeStatus) return false;

    if (trainingSessionId != null &&
        assignment.lastProgressedTrainingSessionId == trainingSessionId &&
        advanceCursor &&
        outcomeStatus.isTerminal) {
      return true;
    }

    if (!advanceCursor &&
        outcomeStatus == ProgrammeSlotOutcomeStatus.inProgress &&
        existingOutcome.outcomeStatus == ProgrammeSlotOutcomeStatus.inProgress) {
      return trainingSessionId == null ||
          existingOutcome.trainingSessionId == trainingSessionId;
    }

    return false;
  }

  bool _assignmentCursorEquals(
    ProgrammeAssignment left,
    ProgrammeAssignment right,
  ) {
    return left.currentWeek == right.currentWeek &&
        left.currentDayKey == right.currentDayKey &&
        left.currentSessionOrder == right.currentSessionOrder;
  }
}
