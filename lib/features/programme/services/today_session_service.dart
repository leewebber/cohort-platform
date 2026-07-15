import '../models/resolved_today_session.dart';

/// Primary Home entry point for programme-driven Today's Session.
///
/// See `43_Programme_Engine_Service_Contracts.md` §3.5.
abstract class TodaySessionService {
  Future<ResolvedTodaySession> resolveForAthlete(String athleteId);
}
