import 'package:flutter/foundation.dart';

import '../../../data/repositories/athlete_state_repository.dart';
import '../../../data/repositories/programme_repository.dart';
import '../../../data/repositories/protocol_repository.dart';
import '../../../data/repositories/training_session_repository.dart';
import '../../../models/protocol.dart';
import '../../programme/errors/programme_schedule_exception.dart';
import '../../programme/models/programme_execution_context.dart';
import '../../programme/models/resolved_today_session.dart';
import '../../programme/services/athlete_state_sync_service.dart';
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
  })  : _todaySessionService = todaySessionService,
        _athleteStateSyncService = athleteStateSyncService,
        _athleteStateRepository = athleteStateRepository,
        _protocolRepository = protocolRepository,
        _programmeRepository = programmeRepository,
        _trainingSessionRepository = trainingSessionRepository;

  final TodaySessionService _todaySessionService;
  final AthleteStateSyncService _athleteStateSyncService;
  final AthleteStateRepository _athleteStateRepository;
  final ProtocolRepository _protocolRepository;
  final ProgrammeRepository _programmeRepository;
  final TrainingSessionRepository _trainingSessionRepository;

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
        return HomeTodaySessionRestDay(resolution: resolution);
      case ResolvedTodaySessionKind.dayComplete:
        return HomeTodaySessionDayComplete(resolution: resolution);
      case ResolvedTodaySessionKind.programmeComplete:
        return HomeTodaySessionProgrammeComplete(resolution: resolution);
      case ResolvedTodaySessionKind.paused:
        return HomeTodaySessionPaused(resolution: resolution);
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
    );
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

    final programmeName = resolution.programmeName?.trim();
    if (programmeName != null && programmeName.isNotEmpty) {
      parts.add(programmeName);
    }

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

  static String slotRequirementLabel(ResolvedTodaySession resolution) {
    return resolution.isOptional ? 'Optional session' : 'Required session';
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
