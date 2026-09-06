import 'build_environment.dart';

/// Compile-time build identity. Secrets never belong here.
class AppBuildProvenance {
  const AppBuildProvenance({
    required this.environment,
    required this.appVersion,
    required this.buildNumber,
    required this.gitCommit,
  });

  final BuildEnvironment? environment;
  final String appVersion;
  final String buildNumber;
  final String gitCommit;

  static AppBuildProvenance? debugOverride;

  static AppBuildProvenance get current =>
      debugOverride ?? AppBuildProvenance.fromEnvironment();

  factory AppBuildProvenance.fromEnvironment() {
    return AppBuildProvenance(
      environment: BuildEnvironment.tryParse(
        const String.fromEnvironment('COHORT_BUILD_ENV'),
      ),
      appVersion: _nonEmpty(
        const String.fromEnvironment('COHORT_APP_VERSION'),
        '1.0.0',
      ),
      buildNumber: _nonEmpty(
        const String.fromEnvironment('COHORT_BUILD_NUMBER'),
        '1',
      ),
      gitCommit: _nonEmpty(
        const String.fromEnvironment('COHORT_GIT_COMMIT'),
        'unknown',
      ),
    );
  }

  String get shortCommit {
    final trimmed = gitCommit.trim();
    if (trimmed.isEmpty || trimmed == 'unknown') return 'unknown';
    return trimmed.length <= 7 ? trimmed : trimmed.substring(0, 7);
  }

  String get displayVersion => '$appVersion ($buildNumber)';

  String get environmentLabel =>
      environment?.diagnosticLabel ?? 'Unspecified';

  static String _nonEmpty(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
