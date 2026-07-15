import '../models/resolved_today_session.dart';

/// Denormalised projection writer for `athlete_state` programme fields.
///
/// `ProgrammeAssignment` remains the source of truth.
abstract class AthleteStateSyncService {
  Future<void> syncFromResolvedSession({
    required String athleteId,
    required ResolvedTodaySession resolution,
  });

  Future<void> clearProgrammeProjection(String athleteId);
}
