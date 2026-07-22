import 'package:flutter/foundation.dart';

import '../../../data/repositories/athlete_state_repository.dart';
import '../../../data/repositories/programme_repository.dart';
import '../../../data/repositories/programme_slot_outcome_store.dart';
import '../../../data/repositories/programme_slot_outcome_supabase_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../data/repositories/programme_version_supabase_store.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../../models/programme_vocabulary.dart';
import '../../../models/protocol.dart';
import '../../programme/errors/programme_schedule_exception.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/programme_progress_summary.dart';
import '../../programme/models/resolved_today_session.dart';
import '../../programme/services/athlete_state_sync_service.dart';
import '../../programme/services/programme_progress_summary_service.dart';
import '../../programme/services/today_session_service.dart';
import '../models/home_today_session_state.dart';

/// Loads the athlete Home Today section from programme resolution first.
class HomeTodaySessionLoader {
  const HomeTodaySessionLoader({
    required TodaySessionService todaySessionService,
    required AthleteStateSyncService athleteStateSyncService,
    required AthleteStateRepository athleteStateRepository,
    required ProtocolRepository protocolRepository,
    required ProgrammeRepository programmeRepository,
    required TrainingSessionRepository trainingSessionRepository,
    ProgrammeVersionStore? programmeVersionStore,
    ProgrammeSlotOutcomeStore? programmeSlotOutcomeStore,
    ProgrammeProgressSummaryService? progressSummaryService,
  })  : _todaySessionService = todaySessionService,
        _athleteStateSyncService = athleteStateSyncService,
        _athleteStateRepository = athleteStateRepository,
        _protocolRepository = protocolRepository,
        _programmeRepository = programmeRepository,
        _trainingSessionRepository = trainingSessionRepository,
        _programmeVersionStore =
            programmeVersionStore ?? const ProgrammeVersionSupabaseStore(),
        _programmeSlotOutcomeStore =
            programmeSlotOutcomeStore ?? const ProgrammeSlotOutcomeSupabaseStore(),
        _progressSummaryService =
            progressSummaryService ?? const ProgrammeProgressSummaryService();

  final TodaySessionService _todaySessionService;
  final AthleteStateSyncService _athleteStateSyncService;
  final AthleteStateRepository _athleteStateRepository;
  final ProtocolRepository _protocolRepository;
  final ProgrammeRepository _programmeRepository;
  final TrainingSessionRepository _trainingSessionRepository;
  final ProgrammeVersionStore _programmeVersionStore;
  final ProgrammeSlotOutcomeStore _programmeSlotOutcomeStore;
  final ProgrammeProgressSummaryService _progressSummaryService;

  Future<HomeTodaySessionState> load(String athleteId) async {
    try {
      final resolution =
          await _todaySessionService.resolveForAthlete(athleteId);
      await _syncProjectionQuietly(athleteId, resolution);
      return _mapResolution(athleteId, resolution);
    } on ProgrammeScheduleException catch (error) {
      debugPrint('[HomeTodaySession] ProgrammeScheduleException: $error');
      return HomeTodaySessionError(
        error: error,
        message: error.message,
      );
    } catch (error, stackTrace) {
      debugPrint('[HomeTodaySession] resolve failed: $error');
      debugPrint('[HomeTodaySession] stackTrace: $stackTrace');
      return HomeTodaySessionError(
        error: error,
        message: 'Could not resolve today\'s programme session.',
      );
    }
  }

  Future<void> _syncProjectionQuietly(
    String athleteId,
    ResolvedTodaySession resolution,
  ) async {
    if (resolution.kind == ResolvedTodaySessionKind.noActiveProgramme) {
      return;
    }

    try {
      await _athleteStateSyncService.syncFromResolvedSession(
        athleteId: athleteId,
        resolution: resolution,
      );
    } catch (error, stackTrace) {
      debugPrint('[HomeTodaySession] athlete_state sync failed: $error');
      debugPrint('[HomeTodaySession] stackTrace: $stackTrace');
    }
  }

  Future<HomeTodaySessionState> _mapResolution(
    String athleteId,
    ResolvedTodaySession resolution,
  ) async {
    switch (resolution.kind) {
      case ResolvedTodaySessionKind.noActiveProgramme:
        return _loadManualFallback(athleteId);
      case ResolvedTodaySessionKind.executable:
        return _loadProgrammeExecutable(athleteId, resolution);
      case ResolvedTodaySessionKind.restDay:
        return HomeTodaySessionRestDay(
          resolution: resolution,
          progressSummary: await _loadProgressSummary(resolution),
        );
      case ResolvedTodaySessionKind.dayComplete:
        return HomeTodaySessionDayComplete(
          resolution: resolution,
          progressSummary: await _loadProgressSummary(resolution),
        );
      case ResolvedTodaySessionKind.programmeComplete:
        return HomeTodaySessionProgrammeComplete(
          resolution: resolution,
          progressSummary: await _loadProgressSummary(resolution),
        );
      case ResolvedTodaySessionKind.paused:
        return HomeTodaySessionPaused(
          resolution: resolution,
          progressSummary: await _loadProgressSummary(resolution),
        );
    }
  }

  Future<HomeTodaySessionState> _loadProgrammeExecutable(
    String athleteId,
    ResolvedTodaySession resolution,
  ) async {
    final protocolId = resolution.effectiveProtocolId?.trim();
    if (protocolId == null || protocolId.isEmpty) {
      return HomeTodaySessionError(
        error: StateError('Executable resolution missing effectiveProtocolId'),
        message: 'Programme session is missing a protocol reference.',
      );
    }

    final protocol = await _protocolRepository.getProtocolById(protocolId);
    if (protocol == null) {
      return HomeTodaySessionError(
        error: StateError('Protocol $protocolId not found'),
        message: 'Programme protocol $protocolId could not be loaded.',
      );
    }

    ProgrammeExecutionContext executionContext;
    try {
      executionContext =
          ProgrammeExecutionContext.fromResolvedSession(resolution);
    } catch (error) {
      return HomeTodaySessionError(
        error: error,
        message: 'Programme execution context is incomplete.',
      );
    }

    final latestTrainingSession =
        await _trainingSessionRepository.getLatestSessionForAthleteAndProtocol(
      athleteId: athleteId,
      protocolId: protocolId,
    );

    return HomeTodaySessionProgrammeExecutable(
      resolution: resolution,
      protocol: protocol,
      executionContext: executionContext,
      latestTrainingSession: latestTrainingSession,
      progressSummary: await _loadProgressSummary(resolution),
    );
  }

  Future<ProgrammeProgressSummary?> _loadProgressSummary(
    ResolvedTodaySession resolution,
  ) async {
    final assignmentId = resolution.assignmentId?.trim();
    final versionId = resolution.programmeVersionId?.trim();
    final weekNumber = resolution.weekNumber;
    if (assignmentId == null ||
        assignmentId.isEmpty ||
        versionId == null ||
        versionId.isEmpty ||
        weekNumber == null) {
      return null;
    }

    try {
      final tree = await _programmeVersionStore.loadTemplateTree(versionId);
      if (tree == null) return null;

      final outcomes =
          await _programmeSlotOutcomeStore.listForAssignment(assignmentId);

      return _progressSummaryService.summarize(
        tree: tree,
        outcomes: outcomes,
        currentWeek: weekNumber,
      );
    } catch (error, stackTrace) {
      debugPrint('[HomeTodaySession] progress summary failed: $error');
      debugPrint('[HomeTodaySession] stackTrace: $stackTrace');
      return null;
    }
  }

  Future<HomeTodaySessionState> _loadManualFallback(String athleteId) async {
    final athleteState =
        await _athleteStateRepository.getAthleteState(athleteId);
    if (athleteState == null) {
      return const HomeTodaySessionEmpty();
    }

    final protocolId = athleteState.currentProtocolId?.trim();
    if (protocolId == null || protocolId.isEmpty) {
      return const HomeTodaySessionEmpty();
    }

    final protocol = await _protocolRepository.getProtocolById(protocolId);
    if (protocol == null) {
      return const HomeTodaySessionEmpty();
    }

    final programme = athleteState.programmeId != null
        ? await _programmeRepository.getProgrammeById(
            athleteState.programmeId!,
          )
        : null;

    final latestTrainingSession =
        await _trainingSessionRepository.getLatestSessionForAthleteAndProtocol(
      athleteId: athleteId,
      protocolId: protocolId,
    );

    return HomeTodaySessionManual(
      athleteState: athleteState,
      protocol: protocol,
      programme: programme,
      latestTrainingSession: latestTrainingSession,
    );
  }
}

/// Display helpers for programme-backed Home cards.
class HomeTodaySessionLabels {
  const HomeTodaySessionLabels._();

  static String dayLabel(ResolvedTodaySession resolution) {
    final title = resolution.dayTitle?.trim();
    if (title != null && title.isNotEmpty) {
      return title;
    }

    final dayKey = resolution.dayKey;
    if (dayKey == null) return '';

    final match = RegExp(r'day_(\d+)').firstMatch(dayKey);
    if (match != null) {
      return 'Day ${match.group(1)}';
    }

    return dayKey;
  }

  static String weekLabel(ResolvedTodaySession resolution) {
    final parts = <String>[];

    final week = resolution.weekNumber;
    if (week != null) {
      parts.add('Week $week');
    }

    final day = dayLabel(resolution);
    if (day.isNotEmpty) {
      parts.add(day);
    }

    return parts.join(' • ');
  }

  static String? programmeName(ResolvedTodaySession resolution) {
    final name = resolution.programmeName?.trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static String? sessionGoal(ResolvedTodaySession resolution) {
    final intent = resolution.dayIntent;
    if (intent == null) return null;
    return 'Session goal: ${intent.displayLabel}';
  }

  static String? adaptationNotice(
    ResolvedTodaySession resolution,
    Protocol protocol,
  ) {
    final planned = resolution.plannedProtocolId?.trim();
    final effective = resolution.effectiveProtocolId?.trim();
    if (planned == null ||
        effective == null ||
        planned.isEmpty ||
        effective.isEmpty ||
        planned == effective) {
      return null;
    }

    return 'Adapted for today — ${protocol.name} replaces the originally planned session.';
  }

  static String? progressLabel(ProgrammeProgressSummary? summary) {
    if (summary == null) return null;
    return summary.displayLabel;
  }

  static String estimatedDuration(int? durationMin) {
    if (durationMin == null) return '';
    return '$durationMin min estimated';
  }

  static String slotRequirementLabel(ResolvedTodaySession resolution) {
    return resolution.isOptional ? 'Optional session' : "Today's session";
  }

  /// Canonical session title — always from the loaded protocol record.
  static String canonicalSessionTitle(Protocol protocol) {
    return protocol.name;
  }

  /// Coach-authored slot label when it adds context beyond the protocol name.
  static String? slotContextLabel(
    ResolvedTodaySession resolution,
    Protocol protocol,
  ) {
    final slotTitle = resolution.slotTitle?.trim();
    if (slotTitle == null || slotTitle.isEmpty) {
      return null;
    }

    if (slotTitle.toLowerCase() == protocol.name.trim().toLowerCase()) {
      return null;
    }

    return slotTitle;
  }

  /// Programme executable card subtitle: requirement plus optional slot context.
  static String executableSubtitle(
    ResolvedTodaySession resolution,
    Protocol protocol,
  ) {
    final parts = <String>[slotRequirementLabel(resolution)];

    final context = slotContextLabel(resolution, protocol);
    if (context != null) {
      parts.add(context);
    }

    return parts.join(' • ');
  }
}
