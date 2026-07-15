import '../../../data/repositories/athlete_state_store.dart';
import '../../../models/athlete_state.dart';
import '../../../models/programme_vocabulary.dart';
import '../models/resolved_today_session.dart';
import 'athlete_state_sync_service.dart';

/// Denormalised projection writer for athlete_state programme fields.
class AthleteStateSyncServiceImpl implements AthleteStateSyncService {
  const AthleteStateSyncServiceImpl({
    required AthleteStateStore athleteStateStore,
  }) : _athleteStateStore = athleteStateStore;

  final AthleteStateStore _athleteStateStore;

  @override
  Future<void> syncFromResolvedSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
  }) async {
    final existing =
        await _athleteStateStore.getByAthleteId(athleteId) ??
            AthleteState(athleteId: athleteId);

    final projection = _buildProjection(
      existing: existing,
      resolution: resolution,
    );

    if (_projectionEquals(existing, projection)) {
      return;
    }

    await _athleteStateStore.upsertProjection(projection);
  }

  @override
  Future<void> clearProgrammeProjection(String athleteId) async {
    await _athleteStateStore.clearProgrammeProjection(athleteId);
  }

  AthleteState _buildProjection({
    required AthleteState existing,
    required ResolvedTodaySession resolution,
  }) {
    if (resolution.hasExecutableSession) {
      return existing.copyWith(
        programmeId: resolution.lineageCode,
        currentWeek: resolution.weekNumber,
        currentDay: resolution.dayKey,
        currentProtocolId: resolution.effectiveProtocolId,
        sessionStatus: resolution.outcomeStatus?.dbValue,
      );
    }

    if (resolution.kind == ResolvedTodaySessionKind.restDay ||
        resolution.kind == ResolvedTodaySessionKind.dayComplete ||
        resolution.kind == ResolvedTodaySessionKind.programmeComplete) {
      return existing.copyWith(
        programmeId: resolution.lineageCode,
        currentWeek: resolution.weekNumber,
        currentDay: resolution.dayKey,
        clearCurrentProtocolId: true,
        clearSessionStatus: true,
      );
    }

    if (resolution.kind == ResolvedTodaySessionKind.paused) {
      return existing.copyWith(
        programmeId: resolution.lineageCode,
        currentWeek: resolution.weekNumber,
        currentDay: resolution.dayKey,
        clearCurrentProtocolId: true,
        sessionStatus: 'paused',
      );
    }

    return existing;
  }

  bool _projectionEquals(AthleteState left, AthleteState right) {
    return left.athleteId == right.athleteId &&
        left.currentGoal == right.currentGoal &&
        left.programmeId == right.programmeId &&
        left.currentWeek == right.currentWeek &&
        left.currentDay == right.currentDay &&
        left.currentProtocolId == right.currentProtocolId &&
        left.sessionStatus == right.sessionStatus;
  }
}
