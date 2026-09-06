import 'build_environment.dart';

/// Client configuration resolved for one build. Never log [supabaseAnonKey].
class AppReleaseConfiguration {
  const AppReleaseConfiguration({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final BuildEnvironment? environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  factory AppReleaseConfiguration.fromEnvironment() {
    return AppReleaseConfiguration(
      environment: BuildEnvironment.tryParse(
        const String.fromEnvironment('COHORT_BUILD_ENV'),
      ),
      supabaseUrl: const String.fromEnvironment('COHORT_SUPABASE_URL').trim(),
      supabaseAnonKey: const String.fromEnvironment(
        'COHORT_SUPABASE_ANON_KEY',
      ).trim(),
    );
  }
}
