import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/data/repositories/session_lineage_supabase_store.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:flutter/widgets.dart';

import 'fake_journey_d_live_ports.dart';
import 'fake_journey_d_protocol_publisher.dart';
import 'journey_d_credential_handoff.dart';
import 'journey_d_hosted_live_ports.dart';
import 'journey_d_live_fixture_creator.dart';
import 'journey_d_non_test_runtime.dart';
import 'journey_d_rebind_pipeline.dart';
import 'protocol_builder_journey_d_publisher.dart';

/// Supported Journey D live entrypoint body.
///
/// Must be launched through the non-test Flutter executable via
/// `tool/staging/run_s17_journey_d_live_dart.sh` (`flutter run --no-pub`).
/// Hosted mode refuses [TestWidgetsFlutterBinding]. Plain `dart run` cannot
/// compile this Flutter-bound graph (FFI NativeCallable crash).
///
/// Port selection:
/// * default / `S17_JD_LIVE_PORTS=hosted` → hosted HTTP + ProtocolBuilder
/// * `S17_JD_LIVE_PORTS=fake` requires `S17_JD_ALLOW_FAKE_PORTS=1` (local only)
Future<int> runJourneyDLiveEntrypoint({
  Map<String, String>? environment,
  bool ensureFlutterBinding = true,
}) async {
  final env = environment ?? Platform.environment;
  final reqPath = env['S17_JD_LIVE_REQUEST_FILE'];
  final outPath = env['S17_JD_LIVE_RESULT_FILE'];
  if (reqPath == null || outPath == null) {
    stderr.writeln('REFUSED: live request/result env missing');
    return 2;
  }

  if (env[JourneyDNonTestRuntime.loopbackProofEnv] == '1') {
    return JourneyDNonTestRuntime.runLoopbackHttpProof(
      env: env,
      resultPath: outPath,
      surface: 'live',
    );
  }

  Map<String, dynamic> request;
  try {
    request =
        jsonDecode(File(reqPath).readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    _write(outPath, {
      'ok': false,
      'classification': 'B4D21D3_REQUEST_MALFORMED',
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
      'detail': 'request_json_parse_failed',
    });
    return 2;
  }

  final root = Directory(request['root'] as String);
  final marker = (request['marker'] as String?)?.trim() ?? '';
  if (marker.isEmpty) {
    _write(outPath, {
      'ok': false,
      'classification': 'B4D21D3_MARKER_REQUIRED',
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
      'detail': 'explicit_marker_required',
    });
    return 2;
  }

  final packageYaml = File(
    '${root.path}/${request['package_rel']}',
  ).readAsStringSync();
  final intentJson = File(
    '${root.path}/${request['protocol_intent_rel']}',
  ).readAsStringSync();

  final portsMode = (env['S17_JD_LIVE_PORTS'] ?? 'hosted').trim();
  final allowFake = env['S17_JD_ALLOW_FAKE_PORTS'] == '1';

  if (portsMode == 'fake') {
    if (!allowFake) {
      _write(outPath, {
        'ok': false,
        'classification': 'B4D21D3_FAKE_PORTS_REFUSED',
        'marker': marker,
        'fixture_marker': marker,
        'hosted_writes_executed': 0,
        'publish_draft_invocations': 0,
        'detail': 'S17_JD_ALLOW_FAKE_PORTS=1 required for fake ports',
        'ports_mode': 'fake_refused',
      });
      return 2;
    }
    final result = await _runWithFakePorts(
      marker: marker,
      packageYaml: packageYaml,
      intentJson: intentJson,
    );
    final json = result.toJson();
    // Local fakes are never hosted writes — report separately.
    final fakeMutations = result.hostedWritesExecuted;
    json['hosted_writes_executed'] = 0;
    json['synthetic_mutations'] = fakeMutations;
    json['ports_mode'] = 'fake';
    json['reached_main'] = true;
    json['mutation_backend'] = 'fake_local';
    json['fixture_marker'] = marker;
    json['credential_handoff_written'] = _maybeWriteCredential(
      env: env,
      result: result,
    );
    _write(outPath, json);
    return result.ok ? 0 : 2;
  }

  if (portsMode != 'hosted') {
    _write(outPath, {
      'ok': false,
      'classification': 'B4D21D3_UNKNOWN_PORTS_MODE',
      'marker': marker,
      'fixture_marker': marker,
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
      'detail': 'S17_JD_LIVE_PORTS must be hosted or fake',
    });
    return 2;
  }

  if (ensureFlutterBinding) {
    WidgetsFlutterBinding.ensureInitialized();
  }

  final apiEnvPath = request['api_env_path'] as String? ?? '/tmp/s13b_api.env';
  final creds = _loadEnv(File(apiEnvPath));
  final url = (creds['S13_API_URL'] ?? creds['SUPABASE_URL'] ?? '').trim();
  final anon = (creds['S13_ANON_KEY'] ?? creds['SUPABASE_ANON_KEY'] ?? '')
      .trim();
  final service =
      (creds['S13_SERVICE_KEY'] ?? creds['SUPABASE_SERVICE_ROLE_KEY'] ?? '')
          .trim();
  if (url.isEmpty || anon.isEmpty || service.isEmpty) {
    _write(outPath, {
      'ok': false,
      'classification': 'B4D21D1_HOSTED_CONFIG_MISSING',
      'marker': marker,
      'fixture_marker': marker,
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
      'detail': 'missing_api_env',
      'reached_main': true,
      'ports_mode': 'hosted',
    });
    return 2;
  }
  if (url.contains('otnhhdxs')) {
    _write(outPath, {
      'ok': false,
      'classification': 'B4D21D1_PRODUCTION_URL_REFUSED',
      'marker': marker,
      'fixture_marker': marker,
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
      'reached_main': true,
      'ports_mode': 'hosted',
    });
    return 2;
  }
  if (!url.contains('tsbadngz')) {
    _write(outPath, {
      'ok': false,
      'classification': 'B4D21D1_NON_STAGING_URL_REFUSED',
      'marker': marker,
      'fixture_marker': marker,
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
      'reached_main': true,
      'ports_mode': 'hosted',
    });
    return 2;
  }

  // After target allowlisting: refuse test binding before any hosted client.
  try {
    JourneyDNonTestRuntime.refuseTestBinding(surface: 'journey_d_live_hosted');
  } on StateError catch (e) {
    _write(outPath, {
      'ok': false,
      'classification': 'JOURNEY_D_VALIDATION_SOURCE_BLOCKED',
      'marker': marker,
      'fixture_marker': marker,
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
      'detail': e.message,
      'test_binding_present': true,
      'reached_main': true,
      'ports_mode': 'hosted',
    });
    return 2;
  }

  await JourneyDNonTestRuntime.initializeSupabase(
    url: url,
    anonOrServiceKey: service,
  );

  final publisher = ProtocolBuilderJourneyDPublisher(
    protocolBuilderService: ProtocolBuilderService(),
    sessionLineageStore: const SessionLineageSupabaseStore(),
  );
  final creator = JourneyDLiveFixtureCreator(
    preflight: JourneyDHostedHttpPreflight(apiUrl: url, serviceKey: service),
    athleteFactory: JourneyDHostedHttpAthleteFactory(
      apiUrl: url,
      serviceKey: service,
      anonKey: anon,
    ),
    rebindPipeline: JourneyDRebindPipeline(publisher: publisher),
    programmeLifecycle: JourneyDHostedProgrammeLifecycle(
      apiUrl: url,
      serviceKey: service,
    ),
    enrolment: JourneyDHostedEnrolment(apiUrl: url, anonKey: anon),
    materialisation: JourneyDHostedMaterialisation(apiUrl: url, anonKey: anon),
  );

  final result = await creator.run(
    marker: marker,
    protocolIntentJson: intentJson,
    packageYaml: packageYaml,
    stagingConfirmed: true,
    liveAuthorized: true,
  );
  final credentialWritten = _maybeWriteCredential(env: env, result: result);
  JourneyDHostedSession.instance.clearSecrets();
  _write(outPath, {
    ...result.toJson(),
    'reached_main': true,
    'ports_mode': 'hosted',
    'mutation_backend': 'hosted',
    'credential_handoff_written': credentialWritten,
  });
  return result.ok ? 0 : 2;
}

/// Writes private credential artifact when `S17_JD_CREDENTIAL_OUT_FILE` is set.
/// Never logs password or full email. Returns whether a file was written.
bool _maybeWriteCredential({
  required Map<String, String> env,
  required JourneyDLiveCreateResult result,
}) {
  final out = env['S17_JD_CREDENTIAL_OUT_FILE']?.trim() ?? '';
  if (out.isEmpty || !result.ok) return false;
  final seed = result.credentialSeed;
  if (seed == null) return false;
  try {
    JourneyDCredentialHandoff().writeFresh(
      file: File(out),
      marker: seed.marker,
      athleteId: seed.athleteId,
      email: seed.email,
      password: seed.password,
      assignmentId: seed.assignmentId,
      versionId: seed.versionId,
    );
    return true;
  } catch (_) {
    return false;
  }
}

Future<JourneyDLiveCreateResult> _runWithFakePorts({
  required String marker,
  required String packageYaml,
  required String intentJson,
}) async {
  const currentUuid = 'a1111111-1111-4111-8111-111111111111';
  const laterUuid = 'b2222222-2222-4222-8222-222222222222';
  final publisher = FakeJourneyDProtocolPublisher(
    lineageByProtocolId: {
      'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
      'PROT-S17-JD-ADAPT-LATER': laterUuid,
    },
  );
  final creator = JourneyDLiveFixtureCreator(
    preflight: FakeJourneyDLivePreflight(),
    athleteFactory: FakeJourneyDLiveAthleteFactory(),
    rebindPipeline: JourneyDRebindPipeline(publisher: publisher),
    programmeLifecycle: FakeJourneyDLiveProgrammeLifecycle(),
    enrolment: FakeJourneyDLiveEnrolment(),
    materialisation: FakeJourneyDLiveMaterialisation(),
  );
  return creator.run(
    marker: marker,
    protocolIntentJson: intentJson,
    packageYaml: packageYaml,
    stagingConfirmed: true,
    liveAuthorized: true,
  );
}

Map<String, String> _loadEnv(File file) {
  final out = <String, String>{};
  if (!file.existsSync()) return out;
  for (final line in file.readAsLinesSync()) {
    var text = line.trim();
    if (text.startsWith('export ')) text = text.substring(7);
    if (text.isEmpty || text.startsWith('#') || !text.contains('=')) continue;
    final i = text.indexOf('=');
    final k = text.substring(0, i).trim();
    var v = text.substring(i + 1).trim();
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      v = v.substring(1, v.length - 1);
    }
    out[k] = v;
  }
  return out;
}

void _write(String path, Map<String, Object?> data) {
  File(
    path,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
}
