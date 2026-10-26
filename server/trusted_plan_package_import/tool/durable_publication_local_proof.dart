// LOCAL DISPOSABLE PROOF ONLY. Credentials read from a mode-0600 loopback fixture.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:trusted_plan_package_import/trusted_plan_package_import.dart';

Future<void> main(List<String> args) async {
  final c = jsonDecode(File(args[0]).readAsStringSync()) as Map;
  final api = Uri.parse(c['api'] as String);
  if (api.scheme != 'http' ||
      api.host != '127.0.0.1' ||
      !(c['container'] as String).startsWith('supabase_db_s12g')) {
    throw StateError('Disposable loopback only');
  }
  final client = http.Client();
  var checks = 0;
  void check(bool value, String name) {
    if (!value) throw StateError('LOCAL PROOF FAILED: $name');
    checks++;
    stdout.writeln('PASS $name');
  }

  Future<String> sql(String query) async {
    final r = await Process.run('docker', [
      'exec',
      '-i',
      c['container'] as String,
      'psql',
      '-X',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-At',
      '-c',
      query,
    ]);
    if (r.exitCode != 0) {
      throw StateError('Local fixture SQL failed (details suppressed)');
    }
    return (r.stdout as String).trim();
  }

  final caps = c['caps'] as Map;
  Future<Map<String, Object?>> login(String email) async {
    final password =
        'Local-only-proof-${DateTime.now().microsecondsSinceEpoch}-xA9!';
    final created = await client.post(
      api.resolve('/auth/v1/admin/users'),
      headers: {
        'apikey': c['anon'],
        'authorization': 'Bearer ${c['service']}',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'email_confirm': true,
      }),
    );
    check(
      created.statusCode == 200 || created.statusCode == 201,
      'disposable GoTrue user created',
    );
    final session = await client.post(
      api.resolve('/auth/v1/token?grant_type=password'),
      headers: {'apikey': c['anon'], 'content-type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    check(session.statusCode == 200, 'GoTrue-issued authenticated session');
    return Map<String, Object?>.from(jsonDecode(session.body) as Map);
  }

  final founderSession = await login('approval-founder@example.invalid');
  final otherSession = await login('approval-athlete@example.invalid');
  final token = founderSession['access_token'] as String;
  final actor = (founderSession['user'] as Map)['id'] as String;
  final store = SupabasePublicationApprovalStore(
    supabaseUrl: api,
    anonKey: c['anon'],
    writerCredential: caps['cohort_publication_approval_writer'],
    deliveryCredential: caps['cohort_publication_event_delivery'],
    client: client,
  );
  final pub = TrustedV3FounderPublication(
    auth: SupabaseAuthTokenVerifier(
      supabaseUrl: api,
      anonKey: c['anon'],
      client: client,
    ),
    founder: AllowlistedFounderAuthority({'approval-founder@example.invalid'}),
    publication: AuthoritativeV3Publication(
      SupabaseV3PublicationAuthority(
        supabaseUrl: api,
        serviceRoleKey: c['service'],
        client: client,
      ),
    ),
  );
  final receiver = TrustedV3PublicationEndpoint(
    founderPublication: pub,
    events: store,
    exerciseProducer: SupabaseExercisePublicationProducer(
      supabaseUrl: api,
      anonKey: c['anon'],
      producerCredential: caps['cohort_exercise_version_publisher'],
      client: client,
    ),
  );
  var mode = 'real';
  Future<Response> deliver(Request req) async {
    if (mode == 'fail') {
      return Response(503, body: jsonEncode({'private': 'NEVER_PERSIST_THIS'}));
    }
    if (mode == 'conflict') {
      return Response(409, body: jsonEncode({'private': 'NEVER_PERSIST_THIS'}));
    }
    final response = await receiver.call(req);
    if (mode == 'lost') throw StateError('lost acknowledgement');
    return response;
  }

  final endpoint = DurablePublicationApprovalEndpoint(
    founder: pub,
    store: store,
    deliveryHandler: deliver,
  );
  final logs = <String>[];
  final runtime = TrustedRuntimeHandler(
    importHandler: (_) async => Response.notFound(''),
    v3PublicationHandler: receiver.call,
    publicationApprovalHandler: endpoint.call,
    logSink: logs.add,
  );
  final server = await io.serve(runtime.call, InternetAddress.loopbackIPv4, 0);
  final base = Uri.parse('http://127.0.0.1:${server.port}');
  Future<({int status, Map data})> call(
    String action,
    Map input, {
    String? bearer,
  }) async {
    final res = await client.post(
      base.resolve('/${DurablePublicationApprovalEndpoint.prefix}$action'),
      headers: {
        'authorization': 'Bearer ${bearer ?? token}',
        'content-type': 'application/json',
      },
      body: jsonEncode(input),
    );
    return (status: res.statusCode, data: jsonDecode(res.body) as Map);
  }

  try {
    check(
      (await call(
            'prepare',
            {},
            bearer: otherSession['access_token'] as String,
          )).status ==
          403,
      'non-Founder refused before store',
    );
    check(
      (await call('prepare', {}, bearer: c['service'])).status != 200,
      'service credential is not Founder approval',
    );
    check(
      (await call(
            'prepare',
            {},
            bearer: caps['cohort_publication_approval_writer'],
          )).status !=
          200,
      'capability token is not Founder authentication',
    );
    check(
      await sql('SELECT count(*) FROM public.publication_approval_drafts') ==
          '0',
      'unauthorised calls leave no drafts',
    );
    final fixture =
        jsonDecode(
              File('test/fixtures/authoritative_v3.json').readAsStringSync(),
            )
            as Map;
    final definition =
        Map<String, Object?>.from(
            jsonDecode(
                  fixture['bundle']['dependencies'][0]['exercise']['canonical_text']
                      as String,
                )
                as Map,
          )
          ..['lifecycle_status'] = 'draft'
          ..remove('published_at');
    final preparedInput = {
      'request_id': 'bc260000-0000-4000-8000-000000000001',
      'kind': 'exercise_published',
      'input': {
        'canonical_text': personalisationCanonicalJson(definition),
        'approved_binding_kinds': ['runningIntervals'],
      },
    };
    var res = await call('prepare', preparedInput);
    check(
      res.status == 200,
      'Founder prepares exact server-stamped review artifact',
    );
    final id = res.data['event_id'] as String;
    final digest = res.data['artifact_sha256'] as String;
    final artifact = res.data['artifact'] as Map;
    check(
      digest == personalisationDigest(artifact),
      'SQL and Dart exact artifact digest agree',
    );
    check(
      (artifact['publication'] as Map)['event_id'] == id,
      'event identity generated by backend',
    );
    check(
      (await call('prepare', preparedInput)).data['event_id'] == id,
      'prepare request retry preserves event and timestamp',
    );
    final conflict = Map<String, Object?>.from(preparedInput)
      ..['input'] = {
        'canonical_text': personalisationCanonicalJson({
          ...definition,
          'canonical_name': 'changed',
        }),
        'approved_binding_kinds': ['runningIntervals'],
      };
    check(
      (await call('prepare', conflict)).status == 409,
      'changed same request ID conflicts',
    );
    check(
      await sql('SELECT count(*) FROM public.publication_approval_events') ==
          '0',
      'preparation is not approval',
    );
    try {
      await store.resolve(id);
      throw StateError('unexpected resolved pending');
    } on PublicationBoundaryException {
      check(true, 'pending event cannot be resolved as approved');
    }
    check(
      (await call('approve', {
            'event_id': id,
            'artifact_sha256': '0' * 64,
          })).status ==
          409,
      'wrong approval digest refuses',
    );
    check(
      (await call('approve', {
            'event_id': id,
            'artifact_sha256': digest,
            'approved_by': actor,
          })).status ==
          422,
      'self-asserted actor/approval keys refuse',
    );
    check(
      (await call('review', {'event_id': id})).data['artifact_sha256'] ==
          digest,
      'complete review reopens exact prepared artifact',
    );
    check(
      (await call('approve', {
            'event_id': id,
            'artifact_sha256': digest,
          })).status ==
          200,
      'explicit authenticated exact-digest approval creates event and outbox',
    );
    check(
      (await call('approve', {
            'event_id': id,
            'artifact_sha256': digest,
          })).status ==
          200,
      'approval replay idempotent',
    );
    check(
      await sql('SELECT count(*) FROM public.publication_approval_events') ==
          '1',
      'one immutable approved event',
    );
    check(
      await sql(
            'SELECT count(*) FROM public.published_exercise_definition_versions',
          ) ==
          '0',
      'approval alone does not retain definitions',
    );
    final pending = await call('pending', {});
    check(
      (pending.data['pending'] as List).length == 1,
      'durable pending delivery visible',
    );
    mode = 'fail';
    check(
      (await call('deliver', {'event_id': id})).status == 503,
      'delivery failure remains pending',
    );
    check(
      await sql(
            "SELECT state FROM public.publication_event_delivery WHERE event_id='$id'",
          ) ==
          'pending',
      'failed delivery persisted as pending',
    );
    check(
      !(await sql(
        'SELECT coalesce(receipt::text,\'\') FROM public.publication_event_delivery',
      )).contains('NEVER_PERSIST_THIS'),
      'private downstream error not persisted',
    );
    check(
      (await call('deliver', {'event_id': id})).status == 409,
      'persisted backoff enforced',
    );
    await sql(
      "UPDATE public.publication_event_delivery SET next_attempt_at=clock_timestamp()-interval '1 second' WHERE event_id='$id'",
    );
    mode = 'lost';
    check(
      (await call('deliver', {'event_id': id})).status == 503,
      'lost acknowledgement remains retryable after committed retention',
    );
    check(
      await sql(
            'SELECT count(*) FROM public.published_exercise_definition_versions',
          ) ==
          '1',
      'real canonical retention committed exactly once',
    );
    await sql(
      "UPDATE public.publication_event_delivery SET next_attempt_at=clock_timestamp()-interval '1 second' WHERE event_id='$id'",
    );
    mode = 'real';
    check(
      (await call('deliver', {'event_id': id})).status == 200,
      'retry after lost acknowledgement succeeds',
    );
    check(
      (await call('deliver', {'event_id': id})).data['status'] == 'delivered',
      'completed delivery replay does not redeliver',
    );
    check(
      await sql(
            'SELECT count(*) FROM public.published_exercise_definition_versions',
          ) ==
          '1',
      'immutable retention remains one version',
    );
    check(
      (await call('approve', {
            'event_id': id,
            'artifact_sha256': digest,
          })).data['delivery_state'] ==
          'delivered',
      'approval replay reports actual delivered state without requeue',
    );
    // Fresh store object proves pending state is not owned by a process/timer.
    final restored = SupabasePublicationApprovalStore(
      supabaseUrl: api,
      anonKey: c['anon'],
      writerCredential: caps['cohort_publication_approval_writer'],
      deliveryCredential: caps['cohort_publication_event_delivery'],
      client: client,
    );
    check(
      (await restored.resolve(id)).id == id,
      'event survives adapter reconstruction',
    );
    for (final role in [
      'anon',
      'authenticated',
      'service_role',
      'cohort_exercise_version_publisher',
    ]) {
      final bearer = role == 'anon'
          ? c['anon']
          : role == 'authenticated'
          ? token
          : role == 'service_role'
          ? c['service']
          : caps[role];
      final r = await client.post(
        api.resolve('/rest/v1/rpc/approve_publication_event_v1'),
        headers: {
          'apikey': c['anon'],
          'authorization': 'Bearer $bearer',
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'p_actor': actor,
          'p_event_id': id,
          'p_artifact_sha256': digest,
        }),
      );
      check(r.statusCode != 200, 'role isolation: $role cannot approve');
    }
    final writerResolve = await client.post(
      api.resolve('/rest/v1/rpc/resolve_publication_approval_event_v1'),
      headers: {
        'apikey': c['anon'],
        'authorization': 'Bearer ${caps['cohort_publication_approval_writer']}',
        'content-type': 'application/json',
      },
      body: jsonEncode({'p_event_id': id}),
    );
    check(
      writerResolve.statusCode != 200,
      'writer cannot deliver/read approved events',
    );
    final delApprove = await client.post(
      api.resolve('/rest/v1/rpc/approve_publication_event_v1'),
      headers: {
        'apikey': c['anon'],
        'authorization': 'Bearer ${caps['cohort_publication_event_delivery']}',
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'p_actor': actor,
        'p_event_id': id,
        'p_artifact_sha256': digest,
      }),
    );
    check(delApprove.statusCode != 200, 'delivery cannot create approval');
    final retire = await call('prepare', {
      'request_id': 'bc260000-0000-4000-8000-000000000002',
      'kind': 'exercise_retired',
      'input': {'publication_event_id': id},
    });
    check(
      retire.status == 200,
      'retirement preparation reuses exact retained original',
    );
    final rid = retire.data['event_id'] as String,
        rd = retire.data['artifact_sha256'] as String;
    await call('approve', {'event_id': rid, 'artifact_sha256': rd});
    check(
      (await store.resolve(id)).artifact['retirement'] != null,
      'publication lookup includes separately approved known retirement',
    );
    mode = 'conflict';
    check(
      (await call('deliver', {'event_id': rid})).status == 409,
      'immutable conflict blocks for review',
    );
    check(
      await sql(
            "SELECT state FROM public.publication_event_delivery WHERE event_id='$rid'",
          ) ==
          'blocked',
      'blocked event survives with unchanged approval',
    );
    check(
      (await call('retry', {
            'event_id': rid,
            'artifact_sha256': '0' * 64,
          })).status !=
          200,
      'unblock requires exact approved digest',
    );
    check(
      (await call('retry', {'event_id': rid, 'artifact_sha256': rd})).status ==
          200,
      'explicit reviewed retry preserves approved bytes',
    );
    final claims = await Future.wait([
      store.claim(actor, rid),
      store.claim(actor, rid),
    ]);
    check(
      claims.where((x) => x['status'] == 'claimed').length == 1 &&
          claims.where((x) => x['status'] == 'wait').length == 1,
      'concurrent delivery claim fenced',
    );
    final oldLease =
        claims.singleWhere((x) => x['status'] == 'claimed')['lease_id']
            as String;
    await sql(
      "UPDATE public.publication_event_delivery SET lease_until=clock_timestamp()-interval '1 second' WHERE event_id='$rid'",
    );
    final next = await store.claim(actor, rid);
    check(
      next['lease_id'] != oldLease,
      'expired lease recoverable after crash',
    );
    try {
      await store.finish(actor, rid, oldLease, 'retry', {
        'code': 'delivery_unavailable',
      });
      throw StateError('stale lease accepted');
    } on PublicationBoundaryException {
      check(true, 'stale worker cannot acknowledge replacement lease');
    }
    await store.finish(actor, rid, next['lease_id'] as String, 'retry', {
      'code': 'delivery_unavailable',
    });
    await sql(
      "UPDATE public.publication_event_delivery SET next_attempt_at=clock_timestamp()-interval '1 second' WHERE event_id='$rid'",
    );
    mode = 'real';
    check(
      (await call('deliver', {'event_id': rid})).status == 200,
      'retirement delivered through unchanged atomic producer boundary',
    );
    check(
      await sql(
            'SELECT count(*) FROM public.published_exercise_version_retirements',
          ) ==
          '1',
      'one canonical retirement retained',
    );
    check(
      (await call('prepare', {
            'request_id': 'bc260000-0000-4000-8000-000000000003',
            'kind': 'programme_approved',
            'input': {
              'source': fixture['payload']['package_canonical_json'],
              'canonical_sha256': '0' * 64,
              'programme_version_id': 'bc260000-0000-4000-8000-000000000030',
              'owner_id': actor,
            },
          })).status ==
          422,
      'programme compiler digest mismatch rejected before preparation',
    );
    final goodProgramme = await call('prepare', {
      'request_id': 'bc260000-0000-4000-8000-000000000004',
      'kind': 'programme_approved',
      'input': {
        'source': fixture['payload']['package_canonical_json'],
        'canonical_sha256': fixture['payload']['package_content_hash'],
        'programme_version_id': 'bc260000-0000-4000-8000-000000000030',
        'owner_id': actor,
      },
    });
    check(
      goodProgramme.status == 200,
      'exact compiler-valid programme artifact prepared without admission',
    );
    final pid = goodProgramme.data['event_id'] as String;
    check(
      (await call('approve', {
            'event_id': pid,
            'artifact_sha256': goodProgramme.data['artifact_sha256'],
          })).status ==
          200,
      'programme approval records exact source owner version and digest',
    );
    check(
      (await store.resolve(pid)).artifact['source'] ==
          fixture['payload']['package_canonical_json'],
      'programme event preserves exact source bytes',
    );
    check(
      {409, 503}.contains((await call('deliver', {'event_id': pid})).status),
      'approved programme still refuses absent authoritative bindings',
    );
    check(
      await sql(
            'SELECT count(*) FROM public.programme_v3_publication_artifacts',
          ) ==
          '0',
      'approval cannot weaken canonical admission',
    );
    final rewriteDraft = await Process.run('docker', [
      'exec',
      '-i',
      c['container'] as String,
      'psql',
      '-X',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-c',
      'UPDATE public.publication_approval_drafts SET artifact=artifact',
    ]);
    check(
      rewriteDraft.exitCode != 0,
      'exact draft artifact cannot be rewritten after review',
    );
    final guard = await Process.run('docker', [
      'exec',
      '-i',
      c['container'] as String,
      'psql',
      '-X',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-c',
      'UPDATE public.publication_approval_events SET record=record',
    ]);
    check(
      guard.exitCode != 0,
      'immutable event trigger refuses privileged rewrite',
    );
    check(
      !logs.join().contains(token) &&
          !logs.join().contains(id) &&
          !logs.join().contains('canonical_text'),
      'runtime logs omit tokens, event IDs and source',
    );
    check(
      await sql(
            "SELECT count(*) FROM public.programme_assignments WHERE athlete_id='$actor'",
          ) ==
          '0',
      'no athlete assignment created by approval/delivery',
    );
    stdout.writeln('LOCAL_DURABLE_APPROVAL_PROOF=PASS checks=$checks');
  } finally {
    await server.close(force: true);
    client.close();
  }
}
