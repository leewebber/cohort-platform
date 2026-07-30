import 'athlete_local_repository.dart';
import 'athlete_state_hydrator.dart';
import 'local_kv_store.dart';

/// Process-wide local athlete persistence entry point.
///
/// Features call [AthletePersistence.hydrator] — never SharedPreferences.
class AthletePersistence {
  AthletePersistence._();

  static AthleteLocalRepository? _repository;
  static AthleteStateHydrator? _hydrator;
  static AthleteHydrationResult? lastHydration;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static AthleteLocalRepository get repository {
    final repo = _repository;
    if (repo == null) {
      throw StateError('AthletePersistence.initialize() has not been called.');
    }
    return repo;
  }

  static AthleteStateHydrator get hydrator {
    final h = _hydrator;
    if (h == null) {
      throw StateError('AthletePersistence.initialize() has not been called.');
    }
    return h;
  }

  /// Production bootstrap (SharedPreferences).
  static Future<void> initialize() async {
    if (_initialized) return;
    final store = await SharedPreferencesKvStore.create();
    bindForTests(AthleteLocalRepository(store));
  }

  /// Injectable bind for tests (in-memory store).
  static void bindForTests(AthleteLocalRepository repository) {
    _repository = repository;
    _hydrator = AthleteStateHydrator(repository: repository);
    _initialized = true;
    lastHydration = null;
  }

  static Future<AthleteHydrationResult> hydrate({
    String? preferredAthleteId,
    DateTime? now,
    bool allowRegenerate = true,
  }) async {
    final result = await hydrator.hydrate(
      preferredAthleteId: preferredAthleteId,
      now: now,
      allowRegenerate: allowRegenerate,
    );
    lastHydration = result;
    return result;
  }

  static Future<void> persistBoundSession({DateTime? now}) =>
      hydrator.persistBoundSession(now: now);

  static Future<void> clearForSignOut({String? athleteId}) =>
      hydrator.clearForSignOut(athleteId: athleteId);

  /// Test-only reset.
  static void resetForTests() {
    _repository = null;
    _hydrator = null;
    lastHydration = null;
    _initialized = false;
  }
}
