import 'package:supabase/supabase.dart';

/// Injectable Supabase client for the founder importer CLI (no Flutter singleton).
class SupabaseClientHolder {
  SupabaseClientHolder._();

  static SupabaseClient? _client;

  static SupabaseClient get client {
    final value = _client;
    if (value == null) {
      throw StateError(
        'SupabaseClientHolder is not initialized. Call bind() after creating SupabaseClient.',
      );
    }
    return value;
  }

  static void bind(SupabaseClient client) {
    _client = client;
  }

  static void reset() {
    _client = null;
  }
}
