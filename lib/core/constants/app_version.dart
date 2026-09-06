import '../config/app_build_provenance.dart';

/// Application version label for beta diagnostics.
class AppVersion {
  AppVersion._();

  static String get label => AppBuildProvenance.current.displayVersion;
}
