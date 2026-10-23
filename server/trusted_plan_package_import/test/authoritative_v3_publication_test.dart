import 'dart:convert';
import 'dart:io';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trusted_plan_package_import/trusted_plan_package_import.dart';

void main() {
  final fixture =
      jsonDecode(File('test/fixtures/authoritative_v3.json').readAsStringSync())
          as Map;
  test(
    'founder verification precedes source reads and privileged publication',
    () async {
      final authority = _Authority(
        Map<String, Object?>.from(fixture['bundle'] as Map),
      );
      for (final allowed in [false, true]) {
        final facade = TrustedV3FounderPublication(
          auth: _Auth(allowed),
          founder: _Founder(false),
          publication: AuthoritativeV3Publication(authority),
        );
        await expectLater(
          facade.publish(
            bearerToken: 'synthetic',
            source: jsonEncode(fixture['source']),
            programmeVersionId: 'v',
            ownerId: 'o',
          ),
          throwsA(isA<TrustedAuthenticationException>()),
        );
        expect(authority.calls, 0);
      }
      final facade = TrustedV3FounderPublication(
        auth: _Auth(true),
        founder: _Founder(true),
        publication: AuthoritativeV3Publication(authority),
      );
      await facade.publish(
        bearerToken: 'synthetic',
        source: jsonEncode(fixture['source']),
        programmeVersionId: 'v',
        ownerId: 'o',
      );
      expect(authority.payload!['imported_by'], 'verified-founder');
    },
  );
  test(
    'existing trusted HTTP transport calls only explicit SQL admission/publication',
    () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        final body = jsonDecode(request.body) as Map;
        if (request.url.path.endsWith('read_v3_publication_dependencies')) {
          expect(body.keys, ['p_canonical_text']);
          return http.Response.bytes(
            utf8.encode(jsonEncode(fixture['bundle'])),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        expect(body.keys, ['payload']);
        return http.Response('{"status":"published"}', 200);
      });
      final authority = SupabaseV3PublicationAuthority(
        supabaseUrl: Uri.parse('http://127.0.0.1:9'),
        serviceRoleKey: 'synthetic-service-fixture',
        client: client,
      );
      await AuthoritativeV3Publication(authority).publish(
        source: jsonEncode(fixture['source']),
        programmeVersionId: 'v',
        ownerId: 'o',
        importedBy: 'verified',
      );
      expect(paths, [
        '/rest/v1/rpc/read_v3_publication_dependencies',
        '/rest/v1/rpc/publish_private_exact_programme_version_v3',
      ]);
      client.close();
    },
  );
  test(
    'trusted adapter recompiles resolved canonical UUID blocks and publishes exact bytes',
    () async {
      final authority = _Authority(
        Map<String, Object?>.from(fixture['bundle'] as Map),
      );
      final result = await AuthoritativeV3Publication(authority).publish(
        source: jsonEncode(fixture['source']),
        programmeVersionId: 'version',
        ownerId: 'owner',
        importedBy: 'verified-founder',
      );
      expect(result['status'], 'published');
      expect(authority.calls, 1);
      final payload = authority.payload!;
      expect(payload['package_schema_version'], 3);
      final tree =
          jsonDecode(payload['package_canonical_json']! as String) as Map;
      expect(tree['personalisation_binding'], isNotNull);
      expect(payload.containsKey('resolved_sources'), isFalse);
      expect(payload['package_content_hash'], personalisationDigest(tree));
    },
  );
  test(
    'missing authoritative resolution and forged dependency digests never publish',
    () async {
      for (final key in ['dependencies', 'sessions']) {
        final bundle = Map<String, Object?>.from(fixture['bundle'] as Map)
          ..[key] = [];
        final authority = _Authority(bundle);
        await expectLater(
          AuthoritativeV3Publication(authority).publish(
            source: jsonEncode(fixture['source']),
            programmeVersionId: 'version',
            ownerId: 'owner',
            importedBy: 'founder',
          ),
          throwsFormatException,
        );
        expect(authority.calls, 0);
      }
      final source = jsonDecode(jsonEncode(fixture['source'])) as Map;
      source['personalisation_binding']['targets'][0]['exercise']['digest'] =
          'a' * 64;
      final authority = _Authority(
        Map<String, Object?>.from(fixture['bundle'] as Map),
      );
      await expectLater(
        AuthoritativeV3Publication(authority).publish(
          source: jsonEncode(source),
          programmeVersionId: 'version',
          ownerId: 'owner',
          importedBy: 'founder',
        ),
        throwsFormatException,
      );
      expect(authority.calls, 0);
    },
  );
  test('changed body and unapproved exercise capability refuse', () async {
    final bundle = jsonDecode(jsonEncode(fixture['bundle'])) as Map;
    bundle['dependencies'][0]['exercise']['publication']['approved_binding_kinds'] =
        [];
    final authority = _Authority(Map<String, Object?>.from(bundle));
    await expectLater(
      AuthoritativeV3Publication(authority).publish(
        source: jsonEncode(fixture['source']),
        programmeVersionId: 'version',
        ownerId: 'owner',
        importedBy: 'founder',
      ),
      throwsFormatException,
    );
    expect(authority.calls, 0);
  });
}

class _Authority implements V3PublicationAuthority {
  _Authority(this.bundle);
  final Map<String, Object?> bundle;
  int calls = 0;
  Map<String, Object?>? payload;
  @override
  Future<Map<String, Object?>> resolveCanonicalSource(String text) async =>
      bundle;
  @override
  Future<Map<String, Object?>> publishPrivateVersion(
    Map<String, Object?> value,
  ) async {
    calls++;
    payload = value;
    return {'status': 'published'};
  }
}

class _Auth implements AuthTokenVerifier {
  _Auth(this.allowed);
  final bool allowed;
  @override
  Future<AuthenticatedPrincipal?> verifyBearerToken(String token) async =>
      allowed
      ? const AuthenticatedPrincipal(
          userId: 'verified-founder',
          email: 'fixture@example.invalid',
        )
      : null;
}

class _Founder implements FounderAuthorityVerifier {
  _Founder(this.allowed);
  final bool allowed;
  @override
  Future<bool> isAuthorisedFounder(AuthenticatedPrincipal principal) async =>
      allowed;
}
