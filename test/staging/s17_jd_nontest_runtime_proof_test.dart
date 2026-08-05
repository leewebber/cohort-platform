import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/staging_tooling/journey_d/journey_d_live_entrypoint.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_non_test_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local proof that Journey D live/execute use a non-test runtime with real HTTP.
///
/// Fake-only suites remain on flutter test. This suite drives the supported
/// launchers in loopback-proof mode (no staging contact).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final root = Directory.current.path;
  final liveLauncher = '$root/tool/staging/run_s17_journey_d_live_dart.sh';
  final execLauncher = '$root/tool/staging/run_s17_journey_d_execute_dart.sh';
  final gate = '$root/tool/staging/lib/s17_jd_flutter_package_gate.sh';
  const stableMarker = 's17_jd_adapt_20260805T012428Z_933d9364';

  late Directory tmp;
  final received = <Map<String, String>>[];

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('jd_nontest_proof_');
    received.clear();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<HttpServer> startLoopback() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((req) async {
        final auth = req.headers.value('authorization') ?? '';
        final marker = req.headers.value('x-fixture-marker') ?? '';
        final surface = req.headers.value('x-journey-d-surface') ?? '';
        received.add({
          'method': req.method,
          'path': req.uri.path,
          'auth': auth.isNotEmpty ? 'present' : 'missing',
          'marker': marker,
          'surface': surface,
        });
        await req.drain<void>();
        if (req.uri.path.contains('journey_d_loopback_fail')) {
          req.response.statusCode = 503;
          req.response.write('{"ok":false}');
        } else if (req.uri.path.contains('journey_d_loopback_auth')) {
          req.response.statusCode = 201;
          req.response.write('{"ok":true,"auth":true}');
        } else {
          req.response.statusCode = 200;
          req.response.write('{"ok":true}');
        }
        await req.response.close();
      }),
    );
    return server;
  }

  test('1 launchers encode non-test hosted path and fake-only flutter test', () {
    for (final path in [liveLauncher, execLauncher]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('flutter run'));
      expect(src, contains('--no-pub'));
      expect(src, contains('s17_jd_nontest_launch.sh'));
      expect(src, contains('flutter_test_fake_only'));
      expect(src, isNot(contains('exec dart run')));
      expect(
        RegExp(r'^\s*flutter pub get\b', multiLine: true).hasMatch(src),
        isFalse,
      );
    }
    expect(
      File('$root/lib/staging_tooling/journey_d/journey_d_live_main.dart')
          .existsSync(),
      isTrue,
    );
    expect(
      File('$root/lib/staging_tooling/journey_d/journey_d_execute_main.dart')
          .existsSync(),
      isTrue,
    );
    expect(
      File(
        '$root/lib/staging_tooling/journey_d/journey_d_non_test_runtime.dart',
      ).readAsStringSync(),
      contains('EmptyLocalStorage'),
    );
  });

  test('2-7 creator + execute loopback HTTP proof via supported launchers',
      () async {
    final prep = await Process.run('bash', [
      '-c',
      'set -euo pipefail; export S17_ROOT="$root"; '
          'source "$gate"; s17_jd_flutter_package_prepare',
    ], workingDirectory: root);
    expect(prep.exitCode, 0, reason: '${prep.stdout}\n${prep.stderr}');

    final server = await startLoopback();
    final base = 'http://127.0.0.1:${server.port}';
    addTearDown(() async => server.close(force: true));

    Future<void> runSurface({
      required String launcher,
      required String resultEnv,
      required String surface,
    }) async {
      final out = File('${tmp.path}/${surface}_out.json');
      final req = File('${tmp.path}/${surface}_req.json');
      req.writeAsStringSync(
        jsonEncode({
          'marker': stableMarker,
          'root': root,
          'package_rel':
              'tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
          'protocol_intent_rel':
              'tool/staging/fixtures/journey_d/protocol_intent.json',
          'api_env_path': '${tmp.path}/unused.env',
          'eligibility_passed': true,
        }),
      );
      final env = <String, String>{
        ...Platform.environment,
        'S17_ROOT': root,
        'S17_JD_LOOPBACK_PROOF': '1',
        'S17_JD_LOOPBACK_BASE_URL': base,
        'S17_JD_LOOPBACK_API_KEY': 'loopback-proof-key',
        resultEnv: out.path,
        if (resultEnv == 'S17_JD_LIVE_RESULT_FILE')
          'S17_JD_LIVE_REQUEST_FILE': req.path,
        if (resultEnv == 'S17_JD_EXECUTE_RESULT_FILE') ...{
          'S17_JD_EXECUTE_REQUEST_FILE': req.path,
          'S17_JD_CREDENTIAL_FILE': '${tmp.path}/unused_cred.json',
        },
        // Ensure hosted path (not fake test harness).
        'S17_JD_LIVE_PORTS': 'hosted',
        'S17_JD_EXECUTE_PORTS': 'hosted',
        'S17_JD_FLUTTER_DEVICE': Platform.environment['S17_JD_FLUTTER_DEVICE'] ??
            'macos',
        'S17_JD_NONTEST_TIMEOUT_SEC': '420',
      };
      final r = await Process.run(
        launcher,
        [],
        environment: env,
        workingDirectory: root,
      );
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect('${r.stdout}\n${r.stderr}', contains('JD_RUNTIME=flutter_run_nontest'));
      expect('${r.stdout}\n${r.stderr}', isNot(contains('Resolving dependencies...')));
      expect(out.existsSync(), isTrue);
      final json = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
      expect(json['ok'], isTrue);
      expect(json['test_binding_present'], isFalse);
      expect(json['plugin_init_required'], isFalse);
      expect(json['shared_preferences_required'], isFalse);
      expect(json['real_http'], isTrue);
      expect(json['surface'], surface);
      expect(jsonEncode(json).toLowerCase(), isNot(contains('password')));
      expect(jsonEncode(json), isNot(contains('@example.invalid')));
    }

    await runSurface(
      launcher: liveLauncher,
      resultEnv: 'S17_JD_LIVE_RESULT_FILE',
      surface: 'live',
    );
    await runSurface(
      launcher: execLauncher,
      resultEnv: 'S17_JD_EXECUTE_RESULT_FILE',
      surface: 'execute',
    );

    expect(received.any((e) => e['method'] == 'GET'), isTrue);
    expect(received.any((e) => e['method'] == 'POST'), isTrue);
    expect(
      received.any((e) => e['auth'] == 'present' && e['surface'] == 'live'),
      isTrue,
    );
    expect(
      received.any((e) => e['auth'] == 'present' && e['surface'] == 'execute'),
      isTrue,
    );
    expect(
      received.every(
        (e) =>
            e['marker'] == 's17_jd_adapt_loopback_proof' || e['marker']!.isEmpty,
      ),
      isTrue,
    );
  }, timeout: const Timeout(Duration(minutes: 12)));

  test('8 production / ambiguous targets fail before client creation', () async {
    final prodEnv = File('${tmp.path}/prod.env');
    prodEnv.writeAsStringSync(
      'S13_API_URL=https://otnhhdxs.supabase.co\n'
      'S13_ANON_KEY=anon\n'
      'S13_SERVICE_KEY=service\n',
    );
    final req = File('${tmp.path}/req_prod.json');
    final out = File('${tmp.path}/out_prod.json');
    req.writeAsStringSync(
      jsonEncode({
        'marker': stableMarker,
        'root': root,
        'package_rel':
            'tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
        'protocol_intent_rel':
            'tool/staging/fixtures/journey_d/protocol_intent.json',
        'api_env_path': prodEnv.path,
      }),
    );
    final code = await runJourneyDLiveEntrypoint(
      environment: {
        'S17_JD_LIVE_REQUEST_FILE': req.path,
        'S17_JD_LIVE_RESULT_FILE': out.path,
      },
      ensureFlutterBinding: false,
    );
    expect(code, 2);
    final json = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    expect(json['classification'], 'B4D21D1_PRODUCTION_URL_REFUSED');
  });

  test('9 genuine hosted mode cannot select fake ports silently', () async {
    final req = File('${tmp.path}/req_fake.json');
    final out = File('${tmp.path}/out_fake.json');
    req.writeAsStringSync(
      jsonEncode({
        'marker': stableMarker,
        'root': root,
        'package_rel':
            'tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
        'protocol_intent_rel':
            'tool/staging/fixtures/journey_d/protocol_intent.json',
        'api_env_path': '${tmp.path}/missing.env',
      }),
    );
    final code = await runJourneyDLiveEntrypoint(
      environment: {
        'S17_JD_LIVE_REQUEST_FILE': req.path,
        'S17_JD_LIVE_RESULT_FILE': out.path,
        'S17_JD_LIVE_PORTS': 'fake',
      },
      ensureFlutterBinding: false,
    );
    expect(code, 2);
    final json = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    expect(json['classification'], 'B4D21D3_FAKE_PORTS_REFUSED');
  });

  test('10 fake-only orchestration makes no network contact', () async {
    final server = await startLoopback();
    addTearDown(() async => server.close(force: true));
    final before = received.length;
    final req = File('${tmp.path}/req_fake2.json');
    final out = File('${tmp.path}/out_fake2.json');
    req.writeAsStringSync(
      jsonEncode({
        'marker': stableMarker,
        'root': root,
        'package_rel':
            'tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
        'protocol_intent_rel':
            'tool/staging/fixtures/journey_d/protocol_intent.json',
        'api_env_path': '${tmp.path}/missing.env',
      }),
    );
    final code = await runJourneyDLiveEntrypoint(
      environment: {
        'S17_JD_LIVE_REQUEST_FILE': req.path,
        'S17_JD_LIVE_RESULT_FILE': out.path,
        'S17_JD_LIVE_PORTS': 'fake',
        'S17_JD_ALLOW_FAKE_PORTS': '1',
        'S17_JD_LOOPBACK_BASE_URL': 'http://127.0.0.1:${server.port}',
      },
      ensureFlutterBinding: false,
    );
    expect(code, 0);
    expect(received.length, before);
  });

  test('11 hosted path refuses Flutter test binding before client init', () async {
    // This suite runs under TestWidgetsFlutterBinding.
    expect(JourneyDNonTestRuntime.isTestBinding, isTrue);
    final stagingEnv = File('${tmp.path}/staging.env');
    stagingEnv.writeAsStringSync(
      'S13_API_URL=https://tsbadngzgvsyfqjupkng.supabase.co\n'
      'S13_ANON_KEY=anon\n'
      'S13_SERVICE_KEY=service\n',
    );
    final req = File('${tmp.path}/req_bind.json');
    final out = File('${tmp.path}/out_bind.json');
    req.writeAsStringSync(
      jsonEncode({
        'marker': stableMarker,
        'root': root,
        'package_rel':
            'tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
        'protocol_intent_rel':
            'tool/staging/fixtures/journey_d/protocol_intent.json',
        'api_env_path': stagingEnv.path,
      }),
    );
    final code = await runJourneyDLiveEntrypoint(
      environment: {
        'S17_JD_LIVE_REQUEST_FILE': req.path,
        'S17_JD_LIVE_RESULT_FILE': out.path,
      },
      ensureFlutterBinding: false,
    );
    expect(code, 2);
    final json = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    expect(json['classification'], 'JOURNEY_D_VALIDATION_SOURCE_BLOCKED');
    expect(json['test_binding_present'], isTrue);
    expect(json['hosted_writes_executed'], 0);
  });

  test('12 loopback proof rejects hosted/production base URLs', () async {
    final out = File('${tmp.path}/bad_loopback.json');
    final code = await JourneyDNonTestRuntime.runLoopbackHttpProof(
      env: {
        'S17_JD_LOOPBACK_BASE_URL':
            'https://tsbadngzgvsyfqjupkng.supabase.co',
        'S17_JD_LOOPBACK_API_KEY': 'x',
      },
      resultPath: out.path,
      surface: 'live',
    );
    expect(code, 2);
    final json = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    expect(json['classification'], 'JOURNEY_D_SCOPE_BLOCKED');
  });

  test('13-15 orchestration still references canonical services; I/J unreachable',
      () {
    final liveMain = File(
      '$root/lib/staging_tooling/journey_d/journey_d_live_entrypoint.dart',
    ).readAsStringSync();
    expect(liveMain, contains('ProtocolBuilderJourneyDPublisher'));
    expect(liveMain, contains('ProtocolBuilderService'));
    expect(liveMain, contains('JourneyDLiveFixtureCreator'));
    expect(liveMain, isNot(contains('Journey I')));
    expect(liveMain, isNot(contains('Journey J')));

    final exec = File(
      '$root/lib/staging_tooling/journey_d/journey_d_execute_entrypoint.dart',
    ).readAsStringSync();
    expect(exec, contains('JourneyDExecuteWorkflow'));
    expect(exec, contains('ProgrammeAdaptationProposalService'));
    expect(exec, contains('ProgrammeAdaptationAcceptanceService'));
    expect(exec, isNot(contains('journey_i')));
    expect(exec, isNot(contains('journey_j')));

    final create = File(
      '$root/tool/staging/create_s17_journey_d_adaptation_fixture.sh',
    ).readAsStringSync();
    expect(create, isNot(contains('run_s17_flutter_staging_verify')));
    final fixturePy = File(
      '$root/tool/staging/lib/s17_journey_d_fixture.py',
    ).readAsStringSync();
    expect(fixturePy, contains('run_s17_journey_d_live_dart.sh'));
    expect(fixturePy, contains('non-test'));
  });
}
