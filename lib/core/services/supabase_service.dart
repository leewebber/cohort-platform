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

    final validation = validateConfiguration(url: url, anonKey: anonKey);
    if (!validation.isConfigured) return validation;

    try {
      await Supabase.initialize(url: url!, publishableKey: anonKey!);
    } catch (_) {
      return SupabaseInitializationResult.missing(
        'Supabase configuration is invalid. Check .env and restart the app.',
      );
    }

    return const SupabaseInitializationResult.configured();
  }

  static SupabaseInitializationResult validateConfiguration({
    required String? url,
    required String? anonKey,
  }) {
    final parsedUrl = url == null ? null : Uri.tryParse(url);
    final validUrl =
        parsedUrl != null &&
        (parsedUrl.scheme == 'https' || parsedUrl.scheme == 'http') &&
        parsedUrl.host.isNotEmpty &&
        !url!.contains('your-project');
    final validKey =
        anonKey != null &&
        anonKey.length >= 20 &&
        !anonKey.contains('your-anon-key');

    if (!validUrl || !validKey) {
      return SupabaseInitializationResult.missing(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be valid in .env.',
      );
    }
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

  const SupabaseInitializationResult.configured() : this._(isConfigured: true);

  factory SupabaseInitializationResult.missing(String message) {
    return SupabaseInitializationResult._(
      isConfigured: false,
      errorMessage: message,
    );
  }
}
