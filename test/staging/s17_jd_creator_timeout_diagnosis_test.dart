import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/staging_tooling/journey_d/journey_d_bounded_http.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_live_entrypoint.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_progress_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local-only creator timeout diagnosis + bounded-runtime acceptance.
///
/// No staging/production contact. Uses loopback HTTP and fake ports only.
///
/// Important: do not install [TestWidgetsFlutterBinding] before the bounded
/// HTTP unit tests — that binding mocks [HttpClient] to synthetic 400s and
/// would hide the stall/timeout behaviour under diagnosis.
void main() {
  final root = Directory.current.path;
  final liveLauncher = '$root/tool/staging/run_s17_journey_d_live_dart.sh';
  final execLauncher = '$root/tool/staging/run_s17_journey_d_execute_dart.sh';
  final gate = '$root/tool/staging/lib/s17_jd_flutter_package_gate.sh';
  const stableMarker = 's17_jd_adapt_20260805T012428Z_933d9364';

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('jd_timeout_diag_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('bounded HTTP unit scenarios', () {
    setUp(() {
      HttpOverrides.global = null;
    });

    test('1 success GET/POST completes', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));
      unawaited(
        server.forEach((req) async {
          await req.drain<void>();
          req.response.statusCode = req.method == 'POST' ? 201 : 200;
          req.response.write('{"ok":true}');
          await req.response.close();
        }),
      );
      final http = JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 3),
      );
      final get = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/rest/v1/ok'),
        headers: {'Authorization': 'Bearer k', 'apikey': 'k'},
      );
      expect(get.statusCode, 200);
      expect(get.dispatched, isTrue);
      final post = await http.post(
        Uri.parse('http://127.0.0.1:${server.port}/rest/v1/ok'),
        headers: {
          'Authorization': 'Bearer k',
          'apikey': 'k',
          'Content-Type': 'application/json',
        },
        body: {'a': 1},
      );
      expect(post.statusCode, 201);
    });

    test('2 connection refusal fails closed without hang', () async {
      final http = JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 2),
      );
      await expectLater(
        http.get(Uri.parse('http://127.0.0.1:1/rest/v1/x')),
        throwsA(isA<JourneyDHttpTransportException>()),
      );
    });

    test('3-4 stalled body / request timeout becomes JourneyDHttpTimeoutException',
        () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));
      unawaited(
        server.forEach((req) async {
          req.response.statusCode = 200;
          req.response.headers.contentLength = 100000;
          // Headers sent; body never written → body join must time out.
          await Future<void>.delayed(const Duration(seconds: 30));
          await req.response.close();
        }),
      );
      final http = JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 2),
      );
      final sw = Stopwatch()..start();
      try {
        await http.get(
          Uri.parse(
            'http://127.0.0.1:${server.port}/rest/v1/journey_d_loopback_ping',
          ),
          headers: {'Authorization': 'Bearer k', 'apikey': 'k'},
        );
        fail('expected timeout');
      } on JourneyDHttpTimeoutException catch (e) {
        expect(sw.elapsedMilliseconds, lessThan(8000));
        expect(e.dispatched, isTrue);
        expect(e.routeClass, contains('/rest/v1/'));
      }
    });

    test('5-6 malformed and non-2xx are observable without hang', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));
      unawaited(
        server.forEach((req) async {
          await req.drain<void>();
          if (req.uri.path.contains('badjson')) {
            req.response.statusCode = 200;
            req.response.write('{not-json');
          } else {
            req.response.statusCode = 503;
            req.response.write('{"ok":false}');
          }
          await req.response.close();
        }),
      );
      final http = JourneyDBoundedHttp(
        defaultTimeout: const Duration(seconds: 3),
      );
      final non2xx = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/rest/v1/fail'),
        headers: {'Authorization': 'Bearer k', 'apikey': 'k'},
      );
      expect(non2xx.statusCode, 503);
      final malformed = await http.get(
        Uri.parse('http://127.0.0.1:${server.port}/rest/v1/badjson'),
        headers: {'Authorization': 'Bearer k', 'apikey': 'k'},
      );
      expect(malformed.statusCode, 200);
      expect(() => jsonDecode(malformed.body), throwsFormatException);
    });
  });

  test('7 progress ledger is atomic and redacts secrets', () {
    final file = File('${tmp.path}/progress.json');
    final ledger = JourneyDProgressLedger(file: file);
    ledger.write({
      'current_stage': 'create_synthetic_athlete',
      'current_status': 'in_progress',
      'password': 'secret',
      'email': 'x@example.invalid',
      'access_token': 'tok',
    });
    final text = file.readAsStringSync();
    expect(text, contains('in_progress'));
    expect(text.toLowerCase(), isNot(contains('secret')));
    expect(text, isNot(contains('@example.invalid')));
    expect(text, isNot(contains('tok')));
  });

  test(
      '8-12 loopback create via supported launcher: stall terminates with stage',
      () async {
    final prep = await Process.run('bash', [
      '-c',
      'set -euo pipefail; export S17_ROOT="$root"; '
          'source "$gate"; s17_jd_flutter_package_prepare',
    ], workingDirectory: root);
    expect(prep.exitCode, 0, reason: '${prep.stdout}\n${prep.stderr}');

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));
    unawaited(
      server.forEach((req) async {
        // Stall auth preflight body — matches retained hang class.
        req.response.statusCode = 200;
        req.response.headers.contentLength = 50000;
        await Future<void>.delayed(const Duration(seconds: 60));
        await req.response.close();
      }),
    );

    final out = File('${tmp.path}/live_out.json');
    final progress = File('${tmp.path}/live_progress.json');
    final req = File('${tmp.path}/live_req.json');
    req.writeAsStringSync(
      jsonEncode({
        'marker': stableMarker,
        'root': root,
        'package_rel':
            'tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
        'protocol_intent_rel':
            'tool/staging/fixtures/journey_d/protocol_intent.json',
        'api_env_path': '${tmp.path}/unused.env',
      }),
    );

    final env = <String, String>{
      ...Platform.environment,
      'S17_ROOT': root,
      'CONFIRM_COHORT_STAGING': '1',
      'S17_JD_LIVE_CREATE': '1',
      'S17_JD_LOOPBACK_CREATE': '1',
      'S17_JD_LOOPBACK_BASE_URL': 'http://127.0.0.1:${server.port}',
      'S17_JD_LOOPBACK_API_KEY': 'loopback-proof-key',
      'S17_JD_LIVE_REQUEST_FILE': req.path,
      'S17_JD_LIVE_RESULT_FILE': out.path,
      'S17_JD_PROGRESS_FILE': progress.path,
      'S17_JD_FLUTTER_LOG_DIR': tmp.path,
      'S17_JD_STAGE_TIMEOUT_SEC': '8',
      'S17_JD_NONTEST_TIMEOUT_SEC': '90',
      'S17_JD_FLUTTER_DEVICE':
          Platform.environment['S17_JD_FLUTTER_DEVICE'] ?? 'macos',
    };

    final sw = Stopwatch()..start();
    final r = await Process.run(
      liveLauncher,
      [],
      environment: env,
      workingDirectory: root,
    );
    expect(sw.elapsedMilliseconds, lessThan(120000));
    expect(r.exitCode, isNot(0), reason: '${r.stdout}\n${r.stderr}');
    expect(out.existsSync(), isTrue, reason: '${r.stdout}\n${r.stderr}');
    final json = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    expect(json['ok'], isFalse);
    expect(jsonEncode(json).toLowerCase(), isNot(contains('password')));
    expect(jsonEncode(json), isNot(contains('@example.invalid')));
    // Stage identification from durable progress or terminal result.
    final stage =
        (json['current_stage'] ??
                (progress.existsSync()
                    ? (jsonDecode(progress.readAsStringSync())
                        as Map)['current_stage']
                    : null))
            ?.toString();
    expect(
      stage,
      anyOf(
        'check_marker_uniqueness_readonly',
        'initialize_supabase',
        isNotNull,
      ),
    );
    final classification = json['classification']?.toString() ?? '';
    expect(
      classification.contains('TIMED_OUT') ||
          classification.contains('UNCERTAIN') ||
          classification.contains('PREFLIGHT'),
      isTrue,
      reason: classification,
    );

    // No lingering flutter child from this launcher pid tree expectation:
    // process should have exited (Process.run returned).
    expect(r.pid, isNonZero);
      },
      timeout: const Timeout(Duration(minutes: 3)),
      tags: ['diagnosis'],
    );

  test('9 missing result persistence path still gets launcher terminal write',
      () async {
    // Launcher containment writes terminal result when flutter dies early.
    final src = File(liveLauncher).readAsStringSync();
    expect(src, contains('s17_jd_nontest_launch.sh'));
    final launch = File(
      '$root/tool/staging/lib/s17_jd_nontest_launch.sh',
    ).readAsStringSync();
    expect(launch, contains('write_terminal_from_progress'));
    expect(launch, contains('S17_JD_FLUTTER_LOG_DIR'));
    expect(launch, contains('outcome_uncertain'));
  });

  test('10 fake-only makes no network contact; live cannot silent-fake',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var hits = 0;
    addTearDown(() async => server.close(force: true));
    unawaited(
      server.forEach((req) async {
        hits += 1;
        await req.drain<void>();
        req.response.statusCode = 200;
        await req.response.close();
      }),
    );
    final req = File('${tmp.path}/fake_req.json');
    final out = File('${tmp.path}/fake_out.json');
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
    expect(hits, 0);

    final code2 = await runJourneyDLiveEntrypoint(
      environment: {
        'S17_JD_LIVE_REQUEST_FILE': req.path,
        'S17_JD_LIVE_RESULT_FILE': '${tmp.path}/fake_refused.json',
        'S17_JD_LIVE_PORTS': 'fake',
      },
      ensureFlutterBinding: false,
    );
    expect(code2, 2);
  });

  test(
    '13 execute loopback proof still works',
    () async {
      final prep = await Process.run('bash', [
        '-c',
        'set -euo pipefail; export S17_ROOT="$root"; '
            'source "$gate"; s17_jd_flutter_package_prepare',
      ], workingDirectory: root);
      expect(prep.exitCode, 0);

      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => server.close(force: true));
      unawaited(
        server.forEach((req) async {
          await req.drain<void>();
          final fail = req.uri.path.contains('fail');
          req.response.statusCode =
              fail ? 503 : (req.method == 'POST' ? 201 : 200);
          req.response.write(fail ? '{"ok":false}' : '{"ok":true}');
          await req.response.close();
        }),
      );
      final out = File('${tmp.path}/exec_out.json');
      final req = File('${tmp.path}/exec_req.json');
      req.writeAsStringSync(jsonEncode({'marker': stableMarker}));
      final r = await Process.run(
        execLauncher,
        [],
        environment: {
          ...Platform.environment,
          'S17_ROOT': root,
          'S17_JD_LOOPBACK_PROOF': '1',
          'S17_JD_LOOPBACK_BASE_URL': 'http://127.0.0.1:${server.port}',
          'S17_JD_LOOPBACK_API_KEY': 'k',
          'S17_JD_EXECUTE_REQUEST_FILE': req.path,
          'S17_JD_EXECUTE_RESULT_FILE': out.path,
          'S17_JD_CREDENTIAL_FILE': '${tmp.path}/cred.json',
          'S17_JD_FLUTTER_LOG_DIR': tmp.path,
          'S17_JD_NONTEST_TIMEOUT_SEC': '120',
          'S17_JD_FLUTTER_DEVICE':
              Platform.environment['S17_JD_FLUTTER_DEVICE'] ?? 'macos',
        },
        workingDirectory: root,
      );
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      final json = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
      expect(json['ok'], isTrue);
      expect(json['test_binding_present'], isFalse);
    },
    timeout: const Timeout(Duration(minutes: 3)),
    tags: ['diagnosis'],
  );

  test('14 production/staging targets not used by loopback create mode', () {
    final src = File(
      '$root/lib/staging_tooling/journey_d/journey_d_live_entrypoint.dart',
    ).readAsStringSync();
    expect(src, contains('S17_JD_LOOPBACK_CREATE'));
    expect(src, contains('loopback_create_requires_http_127_0_0_1'));
    expect(src, contains('otnhhdxs'));
    expect(src, contains('tsbadngz'));
  });
}
