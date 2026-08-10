import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import 'package:trusted_plan_package_import/trusted_plan_package_import.dart';

class _FakeAuth implements AuthTokenVerifier {
  _FakeAuth({this.principal, this.failure = false});

  final AuthenticatedPrincipal? principal;
  final bool failure;
  int calls = 0;

  @override
  Future<AuthenticatedPrincipal?> verifyBearerToken(String token) async {
    calls++;
    if (failure) throw const TrustedAuthenticationException();
    return principal;
  }
}

class _FakeAuthority implements FounderAuthorityVerifier {
  _FakeAuthority({this.authorised = true, this.failure = false});

  final bool authorised;
  final bool failure;
  int calls = 0;

  @override
  Future<bool> isAuthorisedFounder(AuthenticatedPrincipal principal) async {
    calls++;
    if (failure) throw const FounderAuthorityLookupException();
    return authorised;
  }
}

class _RecordingRpc implements PlanPackageImportRpc {
  _RecordingRpc({PlanPackageImportResult? result, this.failure = false})
    : result =
          result ??
          const PlanPackageImportResult(
            status: PlanPackageImportStatus.importedDraft,
            code: 'created_hidden_draft',
            programmeVersionId: 'version-1',
            lineageId: 'lineage-1',
            lineageCode: 'PROG-FIXTURE-01',
            versionNumber: 1,
            packageContentHash:
                '85e6e02785128177c5af0858a8dba9b22624058993d5776f2349ef574869bf64',
            lifecycleStatus: 'draft',
            approvedForGlobal: false,
          );

  final PlanPackageImportResult result;
  final bool failure;
  final payloads = <Map<String, Object?>>[];

  @override
  Future<PlanPackageImportResult> importPackage(
    Map<String, Object?> compilerDerivedPayload,
  ) async {
    payloads.add(compilerDerivedPayload);
    if (failure) throw const PlanPackageRpcException();
    return result;
  }
}

void main() {
  late String validYaml;
  const principal = AuthenticatedPrincipal(
    userId: 'founder-user-id',
    email: 'founder@cohort.test',
  );

  setUpAll(() {
    validYaml = File(
      '../../packages/cohort_plan_package/test/fixtures/'
      'minimal_plan_package.yaml',
    ).readAsStringSync();
  });

  TrustedFounderPlanPackageImportEndpoint endpoint({
    _FakeAuth? auth,
    _FakeAuthority? authority,
    _RecordingRpc? rpc,
    int maxYamlBytes = 1024 * 1024,
  }) {
    return TrustedFounderPlanPackageImportEndpoint(
      authVerifier: auth ?? _FakeAuth(principal: principal),
      founderAuthority: authority ?? _FakeAuthority(),
      importRpc: rpc ?? _RecordingRpc(),
      maxYamlBytes: maxYamlBytes,
    );
  }

  Request request({
    String method = 'POST',
    String? body,
    String? authorization = 'Bearer verified-token',
    String contentType = 'application/yaml',
    String path = TrustedFounderPlanPackageImportEndpoint.route,
  }) {
    final headers = {'content-type': contentType};
    if (authorization != null) {
      headers['authorization'] = authorization;
    }
    return Request(
      method,
      Uri.parse('http://localhost/$path'),
      headers: headers,
      body: body ?? validYaml,
    );
  }

  Future<Map<String, dynamic>> jsonBody(Response response) async {
    return jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  }

  group('trusted endpoint authority and request boundary', () {
    test('rejects unsupported methods before authentication', () async {
      final auth = _FakeAuth(principal: principal);
      final rpc = _RecordingRpc();
      final response = await endpoint(
        auth: auth,
        rpc: rpc,
      ).call(request(method: 'GET'));

      expect(response.statusCode, 405);
      expect(response.headers['allow'], 'POST');
      expect(auth.calls, 0);
      expect(rpc.payloads, isEmpty);
    });

    test('rejects missing bearer token', () async {
      final rpc = _RecordingRpc();
      final response = await endpoint(
        rpc: rpc,
      ).call(request(authorization: null));

      expect(response.statusCode, 401);
      expect((await jsonBody(response))['code'], 'bearer_token_required');
      expect(rpc.payloads, isEmpty);
    });

    test('rejects invalid or expired token', () async {
      final rpc = _RecordingRpc();
      final response = await endpoint(
        auth: _FakeAuth(),
        rpc: rpc,
      ).call(request());

      expect(response.statusCode, 401);
      expect((await jsonBody(response))['code'], 'invalid_or_expired_token');
      expect(rpc.payloads, isEmpty);
    });

    test('sanitises authentication lookup failure', () async {
      final response = await endpoint(
        auth: _FakeAuth(failure: true),
      ).call(request());

      expect(response.statusCode, 503);
      expect((await jsonBody(response))['code'], 'authentication_unavailable');
    });

    test('rejects authenticated non-founder before compilation', () async {
      final rpc = _RecordingRpc();
      final response = await endpoint(
        authority: _FakeAuthority(authorised: false),
        rpc: rpc,
      ).call(request(body: 'not: valid: [['));

      expect(response.statusCode, 403);
      expect((await jsonBody(response))['code'], 'founder_authority_required');
      expect(rpc.payloads, isEmpty);
    });

    test('sanitises founder-authority lookup failure', () async {
      final response = await endpoint(
        authority: _FakeAuthority(failure: true),
      ).call(request());

      expect(response.statusCode, 503);
      expect(
        (await jsonBody(response))['code'],
        'founder_authority_unavailable',
      );
    });

    test(
      'server allowlist uses verified email and ignores coach roles',
      () async {
        final authority = AllowlistedFounderAuthority({'FOUNDER@cohort.test'});
        expect(await authority.isAuthorisedFounder(principal), isTrue);
        expect(
          await authority.isAuthorisedFounder(
            const AuthenticatedPrincipal(
              userId: 'coach-id',
              email: 'coach@cohort.test',
            ),
          ),
          isFalse,
        );
      },
    );

    test('rejects oversized YAML before compilation or RPC', () async {
      final rpc = _RecordingRpc();
      final response = await endpoint(
        rpc: rpc,
        maxYamlBytes: 8,
      ).call(request(body: 'package_schema_version: 1'));

      expect(response.statusCode, 413);
      expect((await jsonBody(response))['code'], 'yaml_too_large');
      expect(rpc.payloads, isEmpty);
    });
  });

  group('compiler and persistence orchestration', () {
    test(
      'malformed YAML returns structured issues and zero RPC calls',
      () async {
        final rpc = _RecordingRpc();
        final response = await endpoint(
          rpc: rpc,
        ).call(request(body: 'programme: [\n  - broken'));
        final body = await jsonBody(response);

        expect(response.statusCode, 422);
        expect(body['code'], 'compile_validation_failed');
        expect(
          (body['issues'] as List).cast<Map>().single['code'],
          'malformed_yaml',
        );
        expect(rpc.payloads, isEmpty);
      },
    );

    test(
      'semantic validation issues propagate and make zero RPC calls',
      () async {
        final rpc = _RecordingRpc();
        final response = await endpoint(rpc: rpc).call(
          request(
            body: validYaml.replaceFirst(
              'athlete_agreement_required: true',
              'athlete_agreement_required: false',
            ),
          ),
        );
        final body = await jsonBody(response);

        expect(response.statusCode, 422);
        expect(
          (body['issues'] as List).cast<Map>().map((issue) => issue['code']),
          contains('agreement_required'),
        );
        expect(rpc.payloads, isEmpty);
      },
    );

    test(
      'client-supplied ownership or authority fields are rejected',
      () async {
        final rpc = _RecordingRpc();
        final response = await endpoint(rpc: rpc).call(
          request(
            body: validYaml.replaceFirst(
              '  coaching_intent:',
              '  owner_id: client-owner\n'
                  '  created_by: client-creator\n'
                  '  founder: true\n'
                  '  coaching_intent:',
            ),
          ),
        );

        expect(response.statusCode, 422);
        expect(rpc.payloads, isEmpty);
      },
    );

    test('authorised founder reaches compiler-derived RPC payload', () async {
      final rpc = _RecordingRpc();
      final response = await endpoint(rpc: rpc).call(request());
      final body = await jsonBody(response);
      final compileResult = const PlanPackageCompiler().compile(validYaml);
      final payload = rpc.payloads.single;

      expect(response.statusCode, 200);
      expect(body['status'], 'imported_draft');
      expect(payload['imported_by'], principal.userId);
      expect(payload['package_content_hash'], compileResult.contentHashSha256);
      expect(payload['package_schema_version'], 1);
      expect((payload['weeks'] as List), hasLength(2));
      expect((payload['sessions'] as List).single, {
        'session_key': 'SES-SQUAT-A',
        'protocol_id': 'PROT-SQUAT-A-R1',
        'session_lineage_id': 'SL-SQUAT-A',
        'revision_number': 1,
        'title': 'Squat A',
      });
      expect(payload.containsKey('yaml'), isFalse);
      expect(payload.containsKey('canonical_json'), isFalse);
      expect(payload.containsKey('owner_id'), isFalse);
      expect(payload.containsKey('created_by'), isFalse);
      expect(payload.containsKey('lifecycle_status'), isFalse);
      expect(payload.containsKey('approved_for_global'), isFalse);
    });

    test(
      'preserves ordered schedule and complete package child contracts',
      () async {
        final rpc = _RecordingRpc();
        await endpoint(rpc: rpc).call(request());
        final payload = rpc.payloads.single;
        final weeks = (payload['weeks'] as List).cast<Map>();

        expect(weeks.map((week) => week['week_number']), [1, 2]);
        expect(
          ((weeks.first['days'] as List).cast<Map>()).map(
            (day) => day['day_order'],
          ),
          [1, 2],
        );
        expect(payload['adaptation_permissions'], hasLength(1));
        expect(payload['protected_invariants'], hasLength(1));
        expect(payload['assessments'], hasLength(1));
        expect(payload['performance_evidence_requirements'], hasLength(1));
        expect(payload['comparison_identities'], hasLength(1));
      },
    );

    test('returns established idempotent replay result', () async {
      final rpc = _RecordingRpc(
        result: const PlanPackageImportResult(
          status: PlanPackageImportStatus.idempotentExistingDraft,
          code: 'idempotent_existing_draft',
          programmeVersionId: 'version-1',
          lineageCode: 'PROG-FIXTURE-01',
          versionNumber: 1,
          lifecycleStatus: 'draft',
          approvedForGlobal: false,
        ),
      );
      final response = await endpoint(rpc: rpc).call(request());

      expect(response.statusCode, 200);
      expect((await jsonBody(response))['status'], 'idempotent_existing_draft');
      expect(rpc.payloads, hasLength(1));
    });

    test('returns fail-closed lineage/version hash collision', () async {
      final rpc = _RecordingRpc(
        result: const PlanPackageImportResult(
          status: PlanPackageImportStatus.versionCollision,
          code: 'hash_collision',
        ),
      );
      final response = await endpoint(rpc: rpc).call(request());

      expect(response.statusCode, 409);
      expect((await jsonBody(response))['code'], 'hash_collision');
    });

    test('sanitises RPC transport failure', () async {
      final response = await endpoint(
        rpc: _RecordingRpc(failure: true),
      ).call(request());
      final body = await jsonBody(response);

      expect(response.statusCode, 502);
      expect(body, {
        'status': 'database_failure',
        'code': 'import_rpc_unavailable',
      });
    });

    test(
      'does not expose database messages or untrusted result codes',
      () async {
        final rpc = _RecordingRpc(
          result: const PlanPackageImportResult(
            status: PlanPackageImportStatus.databaseFailure,
            code: 'secret-database-detail',
            message: 'sensitive internal response',
          ),
        );
        final response = await endpoint(rpc: rpc).call(request());
        final body = await jsonBody(response);

        expect(response.statusCode, 502);
        expect(body['code'], 'database_failure');
        expect(jsonEncode(body), isNot(contains('secret')));
        expect(jsonEncode(body), isNot(contains('sensitive')));
      },
    );

    test('refuses invented success lifecycle or publication state', () async {
      final rpc = _RecordingRpc(
        result: const PlanPackageImportResult(
          status: PlanPackageImportStatus.importedDraft,
          code: 'bad_result',
          lifecycleStatus: 'published',
          approvedForGlobal: true,
        ),
      );
      final response = await endpoint(rpc: rpc).call(request());

      expect(response.statusCode, 502);
      expect(
        (await jsonBody(response))['code'],
        'invalid_import_lifecycle_result',
      );
    });

    test(
      'payload cannot assign, materialise, publish, or add exercises',
      () async {
        final rpc = _RecordingRpc();
        await endpoint(rpc: rpc).call(request());
        final encoded = jsonEncode(rpc.payloads.single);

        for (final forbidden in [
          'programme_assignment',
          'materialise',
          'published_at',
          'approved_for_global',
          'exercise_id',
        ]) {
          expect(encoded.contains(forbidden), isFalse, reason: forbidden);
        }
      },
    );
  });

  group('production adapters and configuration', () {
    test('configuration fails closed without secrets or founder allowlist', () {
      expect(
        () => TrustedImportServerConfig.fromEnvironment(const {}),
        throwsStateError,
      );
      expect(
        () => TrustedImportServerConfig.fromEnvironment({
          'SUPABASE_URL': 'not-a-url',
          'SUPABASE_ANON_KEY': 'placeholder',
          'SUPABASE_SERVICE_ROLE_KEY': 'placeholder',
          'FOUNDER_EMAIL_ALLOWLIST': 'founder@cohort.test',
        }),
        throwsStateError,
      );
    });

    test(
      'auth adapter verifies token through Supabase Auth user endpoint',
      () async {
        late http.Request captured;
        final verifier = SupabaseAuthTokenVerifier(
          supabaseUrl: Uri.parse('https://project.example'),
          anonKey: 'test-anon-placeholder',
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({'id': 'user-1', 'email': 'founder@cohort.test'}),
              200,
            );
          }),
        );

        final verified = await verifier.verifyBearerToken('signed-user-token');

        expect(verified?.userId, 'user-1');
        expect(captured.url.path, '/auth/v1/user');
        expect(captured.headers['authorization'], 'Bearer signed-user-token');
        expect(captured.headers['apikey'], 'test-anon-placeholder');
      },
    );

    test('auth adapter treats rejected token as unauthenticated', () async {
      final verifier = SupabaseAuthTokenVerifier(
        supabaseUrl: Uri.parse('https://project.example'),
        anonKey: 'test-anon-placeholder',
        client: MockClient((_) async => http.Response('{}', 401)),
      );

      expect(await verifier.verifyBearerToken('expired-token'), isNull);
    });

    test(
      'production RPC adapter invokes only existing atomic RPC contract',
      () async {
        late http.Request captured;
        final adapter = SupabasePlanPackageImportRpc(
          supabaseUrl: Uri.parse('https://project.example'),
          serviceRoleKey: 'test-service-placeholder',
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'status': 'imported_draft',
                'code': 'created_hidden_draft',
                'lifecycle_status': 'draft',
                'approved_for_global': false,
              }),
              200,
            );
          }),
        );
        final payload = {
          'package_schema_version': 1,
          'package_content_hash': 'a' * 64,
        };

        final result = await adapter.importPackage(payload);
        final sent = jsonDecode(captured.body) as Map<String, dynamic>;

        expect(captured.url.path, '/rest/v1/rpc/import_authored_plan_package');
        expect(
          SupabasePlanPackageImportRpc.rpcName,
          'import_authored_plan_package',
        );
        expect(sent, {'payload': payload});
        expect(result.status, PlanPackageImportStatus.importedDraft);
        expect(result.lifecycleStatus, 'draft');
        expect(result.approvedForGlobal, false);
      },
    );

    test('server sources contain no legacy importer or sensitive logging', () {
      final source = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(source.contains('founder_importer'), isFalse);
      expect(source.contains('FounderProgrammeYamlParser'), isFalse);
      expect(source.contains('logRequests'), isFalse);
      expect(source.contains('print(yaml'), isFalse);
      expect(source.contains('canonicalJson'), isFalse);
    });

    test('database migration still denies authenticated direct RPC access', () {
      final migration = File(
        '../../supabase/migrations/'
        '20260731120000_authored_plan_package_import.sql',
      ).readAsStringSync();

      expect(
        migration,
        contains(
          'REVOKE ALL ON FUNCTION public.import_authored_plan_package(JSONB) '
          'FROM authenticated;',
        ),
      );
      expect(
        migration,
        contains(
          'GRANT EXECUTE ON FUNCTION public.import_authored_plan_package(JSONB) '
          'TO service_role;',
        ),
      );
    });
  });
}
