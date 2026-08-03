/// Private runtime configuration for Sprint 1.7 Athlete D staging verification.
///
/// Values are supplied via `--dart-define-from-file` from a private temp JSON
/// file outside Git. Never reads shared `.env` or tracked secret stubs.
class S17StagingRuntimeConfig {
  const S17StagingRuntimeConfig({
    required this.enabled,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.athleteEmail,
    required this.athletePassword,
    required this.athleteId,
    required this.assignmentId,
    required this.versionId,
    required this.packageHash,
    required this.runMarker,
    required this.lineageCode,
    this.resumeMode = false,
    this.selectedJourneysRaw = '',
    this.schedulingLineageCode = 'PROG-S15A-STAGING',
  });

  static const stagingHostMarker = 'tsbadngzgvsyfqjupkng';
  static const productionRefPrefix = 'otnhhdxs';

  final bool enabled;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String athleteEmail;
  final String athletePassword;
  final String athleteId;
  final String assignmentId;
  final String versionId;
  final String packageHash;
  final String runMarker;
  final String lineageCode;
  final bool resumeMode;
  final String selectedJourneysRaw;
  final String schedulingLineageCode;

  /// Loads compile-time defines. Empty/disabled when not provided.
  factory S17StagingRuntimeConfig.fromEnvironment() {
    return S17StagingRuntimeConfig(
      enabled: const bool.fromEnvironment('S17_STAGING_ENABLED'),
      supabaseUrl: const String.fromEnvironment('S17_SUPABASE_URL'),
      supabaseAnonKey: const String.fromEnvironment('S17_SUPABASE_ANON_KEY'),
      athleteEmail: const String.fromEnvironment('S17_ATHLETE_EMAIL'),
      athletePassword: const String.fromEnvironment('S17_ATHLETE_PASSWORD'),
      athleteId: const String.fromEnvironment('S17_ATHLETE_ID'),
      assignmentId: const String.fromEnvironment('S17_ASSIGNMENT_ID'),
      versionId: const String.fromEnvironment('S17_VERSION_ID'),
      packageHash: const String.fromEnvironment('S17_PACKAGE_HASH'),
      runMarker: const String.fromEnvironment('S17_RUN_MARKER'),
      lineageCode: const String.fromEnvironment(
        'S17_LINEAGE_CODE',
        defaultValue: 'PROG-S13-ELIG',
      ),
      resumeMode: const bool.fromEnvironment('S17_RESUME_MODE'),
      selectedJourneysRaw: const String.fromEnvironment(
        'S17_SELECTED_JOURNEYS',
      ),
      schedulingLineageCode: const String.fromEnvironment(
        'S17_SCHEDULING_LINEAGE_CODE',
        defaultValue: 'PROG-S15A-STAGING',
      ),
    );
  }

  S17StagingRuntimeConfig copyWith({
    String? assignmentId,
    String? versionId,
    String? packageHash,
    String? lineageCode,
  }) {
    return S17StagingRuntimeConfig(
      enabled: enabled,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      athleteEmail: athleteEmail,
      athletePassword: athletePassword,
      athleteId: athleteId,
      assignmentId: assignmentId ?? this.assignmentId,
      versionId: versionId ?? this.versionId,
      packageHash: packageHash ?? this.packageHash,
      runMarker: runMarker,
      lineageCode: lineageCode ?? this.lineageCode,
      resumeMode: resumeMode,
      selectedJourneysRaw: selectedJourneysRaw,
      schedulingLineageCode: schedulingLineageCode,
    );
  }

  /// Validates fail-closed staging targeting and Athlete D material.
  /// Returns null when valid; otherwise a refusal reason.
  String? validationError() {
    if (!enabled) {
      return 'S17 staging runtime is not enabled';
    }
    if (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty) {
      return 'Missing staging URL or anon key';
    }
    final url = supabaseUrl.toLowerCase();
    if (url.contains(productionRefPrefix)) {
      return 'Production reference rejected';
    }
    if (!url.contains(stagingHostMarker)) {
      return 'URL is not Cohort Staging';
    }
    if (supabaseAnonKey.toLowerCase().contains('service_role')) {
      return 'service_role must not reach Flutter';
    }
    if (athleteEmail.trim().isEmpty ||
        athletePassword.trim().isEmpty ||
        athleteId.trim().isEmpty ||
        assignmentId.trim().isEmpty ||
        versionId.trim().isEmpty ||
        runMarker.trim().isEmpty) {
      return 'Missing Athlete D login or assignment material';
    }
    if (!athleteEmail.endsWith('@example.invalid')) {
      return 'Athlete D email must use @example.invalid';
    }
    if (!runMarker.startsWith('s17_stage_')) {
      return 'Invalid Athlete D run marker';
    }
    if (!athleteEmail.startsWith(runMarker)) {
      return 'Athlete D email must embed run marker';
    }
    return null;
  }

  Map<String, String> redactedIdentity() {
    String prefix(String value) =>
        value.length <= 8 ? '***' : '${value.substring(0, 8)}…';
    return {
      'run_marker': runMarker,
      'athlete_id_prefix': prefix(athleteId),
      'assignment_id_prefix': prefix(assignmentId),
      'version_id_prefix': prefix(versionId),
      'lineage_code': lineageCode,
      'resume_mode': resumeMode ? 'true' : 'false',
      'targets_cohort_staging': 'true',
    };
  }
}
