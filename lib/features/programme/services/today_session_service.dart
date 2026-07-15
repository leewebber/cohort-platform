import '../models/resolved_today_session.dart';

/// Primary Home entry point for programme-driven Today's Session.
abstract class TodaySessionService {
  Future<ResolvedTodaySession> resolveForAthlete(String athleteId);
}
