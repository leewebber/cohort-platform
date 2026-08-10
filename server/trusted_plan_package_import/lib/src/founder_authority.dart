import 'contracts.dart';

/// Server-side adapter for Cohort's established founder email allowlist.
///
/// The email is accepted only after [AuthTokenVerifier] has obtained it from
/// Supabase Auth. Coach/profile roles and client-supplied founder flags are not
/// authority.
class AllowlistedFounderAuthority implements FounderAuthorityVerifier {
  AllowlistedFounderAuthority(Set<String> allowedEmails)
    : _allowedEmails = {
        for (final email in allowedEmails) email.trim().toLowerCase(),
      }..remove('');

  final Set<String> _allowedEmails;

  @override
  Future<bool> isAuthorisedFounder(AuthenticatedPrincipal principal) async {
    return _allowedEmails.contains(principal.email.trim().toLowerCase());
  }
}
