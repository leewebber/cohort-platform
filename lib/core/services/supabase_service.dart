import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_release_configuration.dart';
import '../config/build_environment.dart';
import '../config/release_configuration_code.dart';
import '../config/release_configuration_policy.dart';

typedef SupabaseClientInitializer =
    Future<void> Function({required String url, required String anonKey});

class SupabaseConfigurationException implements Exception {
  SupabaseConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static const _policy = ReleaseConfigurationPolicy();

  static Future<void> initialize({
    AppReleaseConfiguration? configuration,
    SupabaseClientInitializer? initializeClient,
  }) async {
    final result = await tryInitialize(
      configuration: configuration,
      initializeClient: initializeClient,
    );
    if (!result.isConfigured) {
      throw SupabaseConfigurationException(
        result.errorMessage ?? 'This build has invalid configuration.',
      );
    }
  }

  static Future<SupabaseInitializationResult> tryInitialize({
    AppReleaseConfiguration? configuration,
    SupabaseClientInitializer? initializeClient,
  }) async {
    final resolved = configuration ?? AppReleaseConfiguration.fromEnvironment();
    final validation = _policy.validate(resolved);
    if (!validation.isConfigured) {
      return SupabaseInitializationResult.rejected(
        code: validation.code!,
        athleteMessage: validation.athleteMessage!,
      );
    }

    final initializer = initializeClient ?? _defaultInitialize;
    try {
      await initializer(
        url: resolved.supabaseUrl,
        anonKey: resolved.supabaseAnonKey,
      );
    } catch (_) {
      return SupabaseInitializationResult.rejected(
        code: ReleaseConfigurationCode.malformedUrl,
        athleteMessage:
            resolved.environment?.invalidConfigurationMessage ??
            'This build has invalid configuration.',
        attemptedClientInitialization: true,
      );
    }

    return const SupabaseInitializationResult.configured();
  }

  static Future<void> _defaultInitialize({
    required String url,
    required String anonKey,
  }) {
    return Supabase.initialize(url: url, publishableKey: anonKey);
  }

  static SupabaseInitializationResult validateConfiguration({
    required String? url,
    required String? anonKey,
    BuildEnvironment? environment,
  }) {
    final result = _policy.validate(
      AppReleaseConfiguration(
        environment: environment,
        supabaseUrl: url?.trim() ?? '',
        supabaseAnonKey: anonKey?.trim() ?? '',
      ),
    );
    if (result.isConfigured) {
      return const SupabaseInitializationResult.configured();
    }
    return SupabaseInitializationResult.rejected(
      code: result.code!,
      athleteMessage: result.athleteMessage!,
    );
  }
}

class SupabaseInitializationResult {
  const SupabaseInitializationResult._({
    required this.isConfigured,
    this.errorMessage,
    this.code,
    this.attemptedClientInitialization = false,
  });

  final bool isConfigured;
  final String? errorMessage;
  final ReleaseConfigurationCode? code;
  final bool attemptedClientInitialization;

  const SupabaseInitializationResult.configured()
    : this._(isConfigured: true, attemptedClientInitialization: true);

  factory SupabaseInitializationResult.rejected({
    required ReleaseConfigurationCode code,
    required String athleteMessage,
    bool attemptedClientInitialization = false,
  }) {
    return SupabaseInitializationResult._(
      isConfigured: false,
      errorMessage: athleteMessage,
      code: code,
      attemptedClientInitialization: attemptedClientInitialization,
    );
  }

  factory SupabaseInitializationResult.missing(String message) {
    return SupabaseInitializationResult._(
      isConfigured: false,
      errorMessage: message,
      code: ReleaseConfigurationCode.missingEnvironment,
    );
  }
}
