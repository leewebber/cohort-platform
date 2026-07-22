/// Controls whether internal engineering tooling may appear in the app UI.
///
/// Production athlete and coach experiences default to hidden.
///
/// Enable deliberately via:
/// - `flutter run --dart-define=ENABLE_INTERNAL_TOOLS=true`
/// - [enableForTesting] in automated tests
/// - [enable] during local engineering sessions (do not ship enabled)
class InternalToolsPolicy {
  InternalToolsPolicy._();

  static const _dartDefineKey = 'ENABLE_INTERNAL_TOOLS';

  static bool _testOverride = false;
  static bool _manualOverride = false;

  static bool get enabled {
    if (_testOverride || _manualOverride) return true;
    return const bool.fromEnvironment(_dartDefineKey, defaultValue: false);
  }

  /// Explicit opt-in for unit/widget tests that cover internal tooling.
  static void enableForTesting() {
    _testOverride = true;
  }

  /// Explicit opt-in for local engineering sessions.
  static void enable() {
    _manualOverride = true;
  }

  static void reset() {
    _testOverride = false;
    _manualOverride = false;
  }
}
