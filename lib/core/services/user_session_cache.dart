import '../../features/programme/debug/programme_debug_resolution_cache.dart';
import '../../features/session/controllers/session_execution_controller.dart';

/// Clears user-scoped in-memory caches on sign-out or account switch.
class UserSessionCache {
  UserSessionCache._();

  static void clearAll() {
    ProgrammeDebugResolutionCache.clear();
    AthleteSessionMemoryStore.instance.clearAll();
  }
}
