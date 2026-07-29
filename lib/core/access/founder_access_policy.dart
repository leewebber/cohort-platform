import 'founder_access_config.dart';

/// Single policy for founder workspace eligibility.
///
/// Does **not** infer founder access from coach role strings on a profile.
class FounderAccessPolicy {
  FounderAccessPolicy._();

  static FounderAccessConfig _config = FounderAccessConfig.empty;
  static String? _sessionEmail;

  static FounderAccessConfig get config => _config;

  /// Inject allowlist / development override. Call from bootstrap or tests.
  static void configure(FounderAccessConfig config) {
    _config = config;
  }

  /// Bind the signed-in email for this app session (AuthGate).
  static void bindSessionEmail(String? email) {
    _sessionEmail = email?.trim();
  }

  static void reset() {
    _config = FounderAccessConfig.empty;
    _sessionEmail = null;
  }

  /// Returns true when [email] is on the allowlist or development override is on.
  static bool isAuthorisedFounder({String? email}) {
    if (_config.developmentOverride) return true;
    return _config.allowsEmail(email ?? _sessionEmail);
  }

  /// Whether the current bound session is an authorised founder.
  static bool get isSessionFounder =>
      isAuthorisedFounder(email: _sessionEmail);
}
