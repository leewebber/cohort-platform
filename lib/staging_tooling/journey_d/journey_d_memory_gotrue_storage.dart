import 'package:supabase_flutter/supabase_flutter.dart';

/// In-memory PKCE storage for Journey D non-test live runtime.
///
/// Avoids SharedPreferences / plugin-backed async storage. Not a test mock —
/// it is a repository-owned GotrueAsyncStorage for headless tooling.
class JourneyDMemoryGotrueAsyncStorage extends GotrueAsyncStorage {
  JourneyDMemoryGotrueAsyncStorage();

  final Map<String, String> _items = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _items[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _items.remove(key);
  }
}
