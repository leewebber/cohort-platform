import '../models/resolved_today_session.dart';

/// Temporary debug cache for programme resolution/sync hooks.
class ProgrammeDebugResolutionCache {
  ProgrammeDebugResolutionCache._();

  static ResolvedTodaySession? lastResolution;

  static void store(ResolvedTodaySession resolution) {
    lastResolution = resolution;
  }

  static void clear() {
    lastResolution = null;
  }
}
