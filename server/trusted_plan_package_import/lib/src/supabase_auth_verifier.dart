import 'dart:convert';

import 'package:http/http.dart' as http;

import 'contracts.dart';

/// Verifies a bearer token against Supabase Auth's trusted `/auth/v1/user`
/// endpoint. No unverified JWT claim is used for founder authority.
class SupabaseAuthTokenVerifier implements AuthTokenVerifier {
  SupabaseAuthTokenVerifier({
    required Uri supabaseUrl,
    required String anonKey,
    required http.Client client,
  }) : this._(supabaseUrl.resolve('/auth/v1/user'), anonKey, client);

  SupabaseAuthTokenVerifier._(this._userEndpoint, this._anonKey, this._client);

  final Uri _userEndpoint;
  final String _anonKey;
  final http.Client _client;

  @override
  Future<AuthenticatedPrincipal?> verifyBearerToken(String token) async {
    try {
      final response = await _client.get(
        _userEndpoint,
        headers: {
          'apikey': _anonKey,
          'authorization': 'Bearer $token',
          'accept': 'application/json',
        },
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        return null;
      }
      if (response.statusCode != 200) {
        throw const TrustedAuthenticationException();
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const TrustedAuthenticationException();
      }
      final id = decoded['id']?.toString().trim();
      final email = decoded['email']?.toString().trim();
      if (id == null || id.isEmpty || email == null || email.isEmpty) {
        throw const TrustedAuthenticationException();
      }
      return AuthenticatedPrincipal(userId: id, email: email);
    } on TrustedAuthenticationException {
      rethrow;
    } catch (_) {
      throw const TrustedAuthenticationException();
    }
  }
}
