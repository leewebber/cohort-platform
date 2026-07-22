import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfigurationException implements Exception {
  SupabaseConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    final result = await tryInitialize();
    if (!result.isConfigured) {
      throw SupabaseConfigurationException(result.errorMessage!);
    }
  }

  static Future<SupabaseInitializationResult> tryInitialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      return SupabaseInitializationResult.missing(
        'Could not load .env. Copy .env.example to .env and restart the app.',
      );
    }

    final url = dotenv.env['SUPABASE_URL']?.trim();
    final anonKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();

    if (url == null ||
        url.isEmpty ||
        anonKey == null ||
        anonKey.isEmpty ||
        url.contains('your-project') ||
        anonKey.contains('your-anon-key')) {
      return SupabaseInitializationResult.missing(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env.',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );

    return const SupabaseInitializationResult.configured();
  }
}

class SupabaseInitializationResult {
  const SupabaseInitializationResult._({
    required this.isConfigured,
    this.errorMessage,
  });

  final bool isConfigured;
  final String? errorMessage;

  const SupabaseInitializationResult.configured()
      : this._(isConfigured: true);

  factory SupabaseInitializationResult.missing(String message) {
    return SupabaseInitializationResult._(
      isConfigured: false,
      errorMessage: message,
    );
  }
}
