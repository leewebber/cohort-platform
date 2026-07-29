/// Configurable founder allowlist and local development override.
///
/// Add Lee's work email to [allowedEmails] once supplied — do not guess.
///
/// Configuration points:
/// 1. Construct and inject via [FounderAccessPolicy.configure]
/// 2. Or call [FounderAccessPolicy.configure] from app bootstrap / tests
/// 3. Local development: set [developmentOverride] true (never ship enabled)
class FounderAccessConfig {
  const FounderAccessConfig({
    this.allowedEmails = const {},
    this.developmentOverride = false,
  });

  /// Case-insensitive email allowlist for founder workspace access.
  ///
  /// **Where to add Lee's work email:** include the normalised address in
  /// this set when configuring [FounderAccessPolicy], e.g.
  /// `FounderAccessConfig(allowedEmails: {'lee@example.com'})`.
  final Set<String> allowedEmails;

  /// Explicit local/dev fixture: treat the current session as founder.
  /// Must never be enabled in production athlete builds.
  final bool developmentOverride;

  static const empty = FounderAccessConfig();

  bool allowsEmail(String? email) {
    if (email == null) return false;
    final normalised = email.trim().toLowerCase();
    if (normalised.isEmpty) return false;
    return allowedEmails
        .map((e) => e.trim().toLowerCase())
        .contains(normalised);
  }
}
