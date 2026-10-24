import 'dart:convert';
import 'dart:io';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trusted_plan_package_import/trusted_plan_package_import.dart';

const eventId = 'bc240000-0000-4000-8000-000000000001';
final fixture =
    jsonDecode(File('test/fixtures/authoritative_v3.json').readAsStringSync())
        as Map;
Map<String, Object?> record({String kind = 'exercise_published'}) {
  final exercise = fixture['bundle']['dependencies'][0]['exercise'] as Map;
  final publication = Map<String, Object?>.from(exercise['publication'] as Map)
    ..['event_id'] = eventId;
  return {
    'contract': 'cohort.trusted-publication-event.v1',
    'event_id': eventId,
    'kind': kind,
    'approval': {
      'status': 'approved',
      'reference': publication['source_reference'],
    },
    'artifact': kind == 'programme_approved'
        ? {
            'source': fixture['payload']['package_canonical_json'],
            'canonical_sha256': fixture['payload']['package_content_hash'],
            'programme_version_id': 'bc240000-0000-4000-8000-000000000040',
            'owner_id': 'bc240000-0000-4000-8000-000000000041',
          }
        : {
            'canonical_text': exercise['canonical_text'],
            'publication': publication,
            'retirement': null,
          },
  };
}

class Auth implements AuthTokenVerifier {
  Auth({this.allowed = true, this.available = true});
  final bool allowed, available;
  @override
  Future<AuthenticatedPrincipal?> verifyBearerToken(String token) async {
    if (!available) throw const TrustedAuthenticationException();
    return allowed
        ? const AuthenticatedPrincipal(
            userId: 'founder',
            email: 'founder@example.invalid',
          )
        : null;
  }
}

class Founder implements FounderAuthorityVerifier {
  Founder(this.allowed);
  final bool allowed;
  @override
  Future<bool> isAuthorisedFounder(AuthenticatedPrincipal principal) async =>
      allowed;
}

class Events implements VerifiedPublicationEvents {
  Events(this.data);
  final Map<String, Object?> data;
  int calls = 0;
  @override
  Future<VerifiedPublicationEvent> resolve(String id) async {
    calls++;
    return VerifiedPublicationEvent.fromTrustedRecord(id, data);
  }
}

class Authority implements V3PublicationAuthority {
  int writes = 0;
  bool wrongHash = false;
  @override
  Future<Map<String, Object?>> resolveCanonicalSource(String text) async =>
      Map<String, Object?>.from(fixture['bundle'] as Map);
  @override
  Future<Map<String, Object?>> publishPrivateVersion(
    Map<String, Object?> payload,
  ) async {
    writes++;
    expect(payload['imported_by'], 'founder');
    return {
      'status': 'published',
      'programme_version_id': payload['programme_version_id'],
      'package_schema_version': 3,
      'package_content_hash': wrongHash
          ? 'a' * 64
          : payload['package_content_hash'],
    };
  }
}

Request request({
  String path = TrustedV3PublicationEndpoint.exerciseRoute,
  String method = 'POST',
  String? token = 'verified',
  String? body,
  String contentType = 'application/json',
}) => Request(
  method,
  Uri.parse('http://127.0.0.1/$path'),
  headers: {
    if (token != null) 'authorization': 'Bearer $token',
    'content-type': contentType,
  },
  body: body ?? jsonEncode({'event_id': eventId}),
);
void main() {
  late Events events;
  late Authority authority;
  late int writes;
  late http.Client client;
  TrustedV3PublicationEndpoint endpoint({
    Auth? auth,
    bool founder = true,
    bool configured = true,
  }) => TrustedV3PublicationEndpoint(
    founderPublication: TrustedV3FounderPublication(
      auth: auth ?? Auth(),
      founder: Founder(founder),
      publication: AuthoritativeV3Publication(authority),
    ),
    events: configured ? events : null,
    exerciseProducer: configured
        ? SupabaseExercisePublicationProducer(
            supabaseUrl: Uri.parse('http://127.0.0.1:9'),
            anonKey: 'anon-fixture',
            producerCredential: 'producer-fixture',
            client: client,
          )
        : null,
  );
  setUp(() {
    events = Events(record());
    authority = Authority();
    writes = 0;
    client = MockClient((r) async {
      writes++;
      expect(r.url.path, '/rest/v1/rpc/retain_published_exercise_event_v1');
      expect(r.headers['authorization'], 'Bearer producer-fixture');
      final params = jsonDecode(r.body) as Map;
      expect(params.keys.toSet(), {
        'p_canonical_text',
        'p_publication',
        'p_retirement',
      });
      final d = jsonDecode(params['p_canonical_text'] as String) as Map;
      return http.Response(
        jsonEncode({
          'status': 'retained',
          'exercise_id': d['id'],
          'definition_version': d['version'],
          'content_digest': personalisationDigest(d),
          'retired': false,
        }),
        200,
      );
    });
  });
  tearDown(() => client.close());
  test(
    'auth and Founder checks precede every trusted lookup and mutation',
    () async {
      expect((await endpoint().call(request(token: null))).statusCode, 401);
      expect(
        (await endpoint(auth: Auth(allowed: false)).call(request())).statusCode,
        401,
      );
      expect((await endpoint(founder: false).call(request())).statusCode, 403);
      expect(
        (await endpoint(
          auth: Auth(available: false),
        ).call(request())).statusCode,
        503,
      );
      expect(events.calls, 0);
      expect(writes, 0);
      expect(authority.writes, 0);
    },
  );
  test('disabled configuration refuses after auth and before reads', () async {
    expect((await endpoint(configured: false).call(request())).statusCode, 503);
    expect(
      (await endpoint(
        configured: false,
        founder: false,
      ).call(request())).statusCode,
      403,
    );
    expect(events.calls, 0);
    expect(writes, 0);
  });
  test(
    'only one bounded event ID is accepted, never claimed approvals or definitions',
    () async {
      for (final body in [
        '{}',
        '[]',
        '{"event_id":"bad"}',
        jsonEncode({'event_id': eventId, 'approved': true}),
        jsonEncode({'event_id': eventId, 'canonical_text': '{}'}),
        'x' * 300,
      ]) {
        expect(
          (await endpoint().call(request(body: body))).statusCode,
          anyOf(422, 413),
        );
      }
      expect(
        (await endpoint().call(request(contentType: 'text/plain'))).statusCode,
        415,
      );
      expect((await endpoint().call(request(method: 'GET'))).statusCode, 405);
      expect((await endpoint().call(request(path: 'other'))).statusCode, 404);
      expect(events.calls, 0);
      expect(writes, 0);
    },
  );
  test(
    'trusted exercise event uses only the dedicated SQL capability',
    () async {
      final response = await endpoint().call(request());
      expect(response.statusCode, 200);
      final body = jsonDecode(await response.readAsString()) as Map;
      expect(body['event_received'], true);
      expect(body['approval_evidence'], 'verified_producer_record');
      expect(body.containsKey('canonical_text'), false);
      expect(writes, 1);
      expect(authority.writes, 0);
    },
  );
  test(
    'approved programme source, identity and digest come from trusted lookup',
    () async {
      events = Events(record(kind: 'programme_approved'));
      final response = await endpoint().call(
        request(path: TrustedV3PublicationEndpoint.programmeRoute),
      );
      expect(response.statusCode, 200);
      expect(authority.writes, 1);
      expect(writes, 0);
      expect(
        jsonDecode(await response.readAsString())['approved_for_global'],
        false,
      );
    },
  );
  test(
    'mismatched approval digest never publishes despite valid technical compile',
    () async {
      final data = record(kind: 'programme_approved');
      (data['artifact'] as Map)['canonical_sha256'] = 'a' * 64;
      events = Events(data);
      expect(
        (await endpoint().call(
          request(path: TrustedV3PublicationEndpoint.programmeRoute),
        )).statusCode,
        422,
      );
      expect(authority.writes, 0);
    },
  );
  test('backend acknowledgement must match approved canonical hash', () async {
    events = Events(record(kind: 'programme_approved'));
    authority.wrongHash = true;
    final response = await endpoint().call(
      request(path: TrustedV3PublicationEndpoint.programmeRoute),
    );
    expect(response.statusCode, 503);
    expect(
      await response.readAsString(),
      contains('invalid_publication_result'),
    );
  });
  test('a known retirement must be acknowledged as retired', () async {
    final d = record();
    final a = d['artifact'] as Map;
    final publication = a['publication'] as Map;
    a['retirement'] = {
      'issuer': 'founder_exercise_publication_v1',
      'event_id': 'bc240000-0000-4000-8000-000000000002',
      'publication_event_id': publication['event_id'],
      'source_reference': 'retirement-fixture',
      'retired_at': '2026-10-24T00:00:00Z',
    };
    events = Events(d);
    final response = await endpoint().call(request());
    expect(response.statusCode, 503);
    expect(await response.readAsString(), contains('invalid_producer_result'));
  });
  test('wrong route kind never crosses publication boundary', () async {
    expect(
      (await endpoint().call(
        request(path: TrustedV3PublicationEndpoint.programmeRoute),
      )).statusCode,
      422,
    );
    expect(authority.writes, 0);
    expect(writes, 0);
  });
  test(
    'forged or absent approval evidence and mismatched event identity refuse',
    () async {
      final variants = <Map<String, Object?>>[];
      var d = record();
      d['event_id'] = 'bc240000-0000-4000-8000-000000000099';
      variants.add(d);
      d = record();
      (d['approval'] as Map)['status'] = 'pending';
      variants.add(d);
      d = record();
      d.remove('approval');
      variants.add(d);
      d = record();
      ((d['artifact'] as Map)['publication'] as Map)['issuer'] = 'client';
      variants.add(d);
      d = record();
      (d['artifact'] as Map)['canonical_text'] = '{}';
      variants.add(d);
      for (final v in variants) {
        events = Events(v);
        expect((await endpoint().call(request())).statusCode, anyOf(503, 409));
      }
      expect(writes, 0);
      expect(authority.writes, 0);
    },
  );
  test(
    'trusted records are deep immutable and preserve exact version strings',
    () {
      final d = record();
      final e = VerifiedPublicationEvent.fromTrustedRecord(eventId, d);
      (d['artifact'] as Map)['canonical_text'] = 'changed';
      expect(e.artifact['canonical_text'], isNot('changed'));
      expect(
        () => e.artifact['canonical_text'] = 'changed',
        throwsUnsupportedError,
      );
      expect(
        () => (e.artifact['publication'] as Map)['event_id'] = 'changed',
        throwsUnsupportedError,
      );
    },
  );
  test(
    'producer conflict and missing capability have no service-role fallback',
    () async {
      for (final code in [403, 409, 400]) {
        client.close();
        client = MockClient((r) async {
          expect(r.headers['authorization'], 'Bearer producer-fixture');
          return http.Response('{"message":"PRIVATE_DATABASE_DETAILS"}', code);
        });
        final response = await endpoint().call(request());
        expect(
          response.statusCode,
          code == 403
              ? 503
              : code == 409
              ? 409
              : 422,
        );
        expect(
          await response.readAsString(),
          isNot(contains('PRIVATE_DATABASE_DETAILS')),
        );
      }
    },
  );
  test(
    'HTTP source uses configured authentication and refuses redirects/not-ready',
    () async {
      for (final code in [200, 302, 404, 401]) {
        final c = MockClient((r) async {
          expect(r.url.toString(), 'https://producer.invalid/events/$eventId');
          expect(r.headers['authorization'], 'Bearer source-fixture');
          expect(r.followRedirects, false);
          return http.Response(
            jsonEncode(record()),
            code,
            headers: {
              'content-type': 'application/json',
              'location': 'https://attacker.invalid/',
            },
          );
        });
        final source = HttpVerifiedPublicationEvents(
          baseUrl: Uri.parse('https://producer.invalid/events/'),
          credential: 'source-fixture',
          client: c,
        );
        if (code == 200) {
          expect((await source.resolve(eventId)).id, eventId);
        } else {
          await expectLater(
            source.resolve(eventId),
            throwsA(isA<PublicationBoundaryException>()),
          );
        }
        c.close();
      }
    },
  );
  test('source response body is bounded and timed out', () async {
    for (final delayed in [false, true]) {
      final c = MockClient((r) async {
        if (delayed) {
          await Future<void>.delayed(const Duration(milliseconds: 30));
        }
        return http.Response(
          'x' * (2 * 1024 * 1024 + 1),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final source = HttpVerifiedPublicationEvents(
        baseUrl: Uri.parse('https://producer.invalid/events/'),
        credential: 'fixture',
        client: c,
        timeout: const Duration(milliseconds: 5),
      );
      await expectLater(
        source.resolve(eventId),
        throwsA(isA<PublicationBoundaryException>()),
      );
      c.close();
    }
  });
  test(
    'runtime logs route classes, never event/body/token/approval data',
    () async {
      final logs = <String>[];
      final runtime = TrustedRuntimeHandler(
        importHandler: (_) async => Response.notFound(''),
        v3PublicationHandler: endpoint().call,
        logSink: logs.add,
      );
      expect(
        (await runtime.call(
          request(
            token: 'PRIVATE_BEARER',
            body: jsonEncode({'event_id': eventId}),
          ),
        )).statusCode,
        200,
      );
      expect(logs.single, contains('exercise_publication_event'));
      for (final secret in [
        eventId,
        'PRIVATE_BEARER',
        'canonical_text',
        'producer-fixture',
        'source-fixture',
      ]) {
        expect(logs.single, isNot(contains(secret)));
      }
    },
  );
  test(
    'v3 config requires complete trusted source and distinct producer credentials',
    () {
      final base = {
        'SUPABASE_URL': 'http://127.0.0.1:9',
        'SUPABASE_ANON_KEY': 'anon',
        'SUPABASE_SERVICE_ROLE_KEY': 'service',
        'FOUNDER_EMAIL_ALLOWLIST': 'founder@example.invalid',
      };
      expect(
        TrustedImportServerConfig.fromEnvironment(base).publicationEventsUrl,
        isNull,
      );
      for (final extra in [
        <String, String>{'TRUSTED_V3_PUBLICATION_ENABLED': 'yes'},
        {'TRUSTED_V3_PUBLICATION_ENABLED': 'true'},
        {
          'TRUSTED_V3_PUBLICATION_ENABLED': 'true',
          'PUBLICATION_EVENT_SOURCE_URL': 'http://external.invalid/events/',
          'PUBLICATION_EVENT_SOURCE_TOKEN': 'source',
          'EXERCISE_VERSION_PRODUCER_TOKEN': 'producer',
        },
        {
          'TRUSTED_V3_PUBLICATION_ENABLED': 'true',
          'PUBLICATION_EVENT_SOURCE_URL': 'https://producer.invalid/events/',
          'PUBLICATION_EVENT_SOURCE_TOKEN': 'source',
          'EXERCISE_VERSION_PRODUCER_TOKEN': 'service',
        },
      ]) {
        expect(
          () => TrustedImportServerConfig.fromEnvironment({...base, ...extra}),
          throwsStateError,
        );
      }
      expect(
        TrustedImportServerConfig.fromEnvironment({
          ...base,
          'TRUSTED_V3_PUBLICATION_ENABLED': 'true',
          'PUBLICATION_EVENT_SOURCE_URL': 'https://producer.invalid/events/',
          'PUBLICATION_EVENT_SOURCE_TOKEN': 'source',
          'EXERCISE_VERSION_PRODUCER_TOKEN': 'producer',
        }).publicationEventsUrl,
        Uri.parse('https://producer.invalid/events/'),
      );
    },
  );
}
