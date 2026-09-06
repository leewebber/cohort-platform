import 'dart:convert';

/// Synthetic non-secret JWTs for local configuration tests only.
class SyntheticJwts {
  static String withRole(String role) {
    final header = _b64url(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final payload = _b64url(utf8.encode('{"role":"$role","iss":"supabase"}'));
    return '$header.$payload.signature';
  }

  static String get anon => withRole('anon');

  static String get serviceRole => withRole('service_role');

  static String get authenticated => withRole('authenticated');

  static String get customAdmin => withRole('custom_admin');

  static String _b64url(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
