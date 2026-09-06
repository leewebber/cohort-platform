/// Explicit build environment. Never inferred from Flutter debug/release mode.
enum BuildEnvironment {
  production,
  loopbackPreview,
  development;

  static const productionHost = 'otnhhdxstdnwccehacku.supabase.co';
  static const stagingHost = 'tsbadngzgvsyfqjupkng.supabase.co';

  String get dartDefineValue => switch (this) {
    BuildEnvironment.production => 'production',
    BuildEnvironment.loopbackPreview => 'loopbackPreview',
    BuildEnvironment.development => 'development',
  };

  String get diagnosticLabel => switch (this) {
    BuildEnvironment.production => 'Production',
    BuildEnvironment.loopbackPreview => 'Local Preview',
    BuildEnvironment.development => 'Development',
  };

  String get invalidConfigurationMessage =>
      'This build has invalid $diagnosticLabel configuration.';

  bool get showsLocalPreviewIndicator => this == loopbackPreview;

  static BuildEnvironment? tryParse(String? raw) {
    switch (raw?.trim()) {
      case 'production':
        return BuildEnvironment.production;
      case 'loopbackPreview':
        return BuildEnvironment.loopbackPreview;
      case 'development':
        return BuildEnvironment.development;
      default:
        return null;
    }
  }
}
