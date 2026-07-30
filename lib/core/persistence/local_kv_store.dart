import 'package:shared_preferences/shared_preferences.dart';

/// Key-value store contract for local athlete persistence.
abstract class LocalKvStore {
  Future<String?> readString(String key);

  Future<void> writeString(String key, String value);

  Future<void> remove(String key);

  Future<void> clearPrefix(String prefix);
}

/// SharedPreferences-backed store (production).
class SharedPreferencesKvStore implements LocalKvStore {
  SharedPreferencesKvStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPreferencesKvStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesKvStore(prefs);
  }

  @override
  Future<String?> readString(String key) async => _prefs.getString(key);

  @override
  Future<void> writeString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clearPrefix(String prefix) async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
    for (final key in keys) {
      await _prefs.remove(key);
    }
  }
}

/// Deterministic in-memory store for tests.
class InMemoryKvStore implements LocalKvStore {
  final Map<String, String> _data = {};

  Map<String, String> get debugDump => Map.unmodifiable(_data);

  @override
  Future<String?> readString(String key) async => _data[key];

  @override
  Future<void> writeString(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> clearPrefix(String prefix) async {
    _data.removeWhere((k, _) => k.startsWith(prefix));
  }
}

/// Key helpers scoped by athlete id.
abstract final class PersistenceKeys {
  static const root = 'cohort.athlete.v1';

  static String athleteRoot(String athleteId) => '$root.$athleteId';

  static String profile(String athleteId) =>
      '${athleteRoot(athleteId)}.profile';

  static String planAssignment(String athleteId) =>
      '${athleteRoot(athleteId)}.plan_assignment';

  static String generatedSession(String athleteId) =>
      '${athleteRoot(athleteId)}.generated_session';

  static String completions(String athleteId) =>
      '${athleteRoot(athleteId)}.completions';

  static String capabilityTimeline(String athleteId) =>
      '${athleteRoot(athleteId)}.capability_timeline';

  static String previousPerformance(String athleteId) =>
      '${athleteRoot(athleteId)}.previous_performance';

  static String workoutProgress(String athleteId) =>
      '${athleteRoot(athleteId)}.workout_progress';

  static String exerciseResults(String athleteId) =>
      '${athleteRoot(athleteId)}.exercise_results';

  /// Last guest / local athlete id for bootstrap without auth.
  static const lastLocalAthleteId = '$root.last_local_athlete_id';
}
