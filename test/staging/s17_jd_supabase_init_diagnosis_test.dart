import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/staging_tooling/journey_d/journey_d_non_test_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Local-only diagnosis/acceptance for the 441812a initialize_supabase failure.
///
/// No staging/production contact.
void main() {
  final root = Directory.current.path;
  final liveLauncher = '$root/tool/staging/run_s17_journey_d_live_dart.sh';
  final execLauncher = '$root/tool/staging/run_s17_journey_d_execute_dart.sh';
  final gate = '$root/tool/staging/lib/s17_jd_flutter_package_gate.sh';

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('jd_supabase_init_');
    JourneyDNonTestRuntime.debugResetOwnership();
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('1 pre-repair pattern: Supabase.instance asserts before initialize', () {
    // Exact failure mode from 441812a debug flutter run:
    // JourneyDNonTestRuntime previously gated on Supabase.instance.isInitialized.
    expect(
      () => Supabase.instance.isInitialized,
      throwsA(
        isA<AssertionError>().having(
          (e) => e.message?.toString() ?? e.toString(),
          'message',
          contains('initialize the supabase instance before calling Supabase.instance'),
        ),
      ),
    );
  });

  test('2 repaired source never reads Supabase.instance before initialize', () {
    final src = File(
      '$root/lib/staging_tooling/journey_d/journey_d_non_test_runtime.dart',
    ).readAsStringSync();
    expect(src, isNot(contains('Supabase.instance.isInitialized')));
    expect(src, contains('Do NOT read Supabase.instance'));
    expect(src, contains('EmptyLocalStorage'));
    expect(src, contains('JourneyDMemoryGotrueAsyncStorage'));
  });

  test('3 invalid/missing/production config fails before client construction', () {
    expect(
      () => JourneyDNonTestRuntime.validateSupabaseConfig(
        url: '',
        anonOrServiceKey: 'k',
      ),
      throwsA(
        isA<JourneyDSupabaseInitException>().having(
          (e) => e.code,
          'code',
          'config_missing',
        ),
      ),
    );
    expect(
      () => JourneyDNonTestRuntime.validateSupabaseConfig(
        url: 'not-a-url',
        anonOrServiceKey: 'k',
      ),
      throwsA(
        isA<JourneyDSupabaseInitException>().having(
          (e) => e.code,
          'code',
          'config_invalid_url',
        ),
      ),
    );
    expect(
      () => JourneyDNonTestRuntime.validateSupabaseConfig(
        url: 'https://otnhhdxsXXXX.supabase.co',
        anonOrServiceKey: 'k',
      ),
      throwsA(
        isA<JourneyDSupabaseInitException>().having(
          (e) => e.code,
          'code',
          'config_production_refused',
        ),
      ),
    );
  });

  test('4 redaction strips tokens and emails from exception payloads', () {
    final map = JourneyDNonTestRuntime.redactException(
      StateError('Bearer eyJabc.def.ghi user@example.invalid'),
      StackTrace.fromString(
        '#0      x (package:cohort_platform/staging_tooling/journey_d/journey_d_non_test_runtime.dart:1:1)\n',
      ),
    );
    final text = jsonEncode(map);
    expect(text, isNot(contains('eyJabc')));
    expect(text, isNot(contains('user@example.invalid')));
    expect(text, contains('Bearer <redacted>'));
    expect(text, contains('<email>'));
  });

  test('5-9 nontest init proof via supported launcher (debug build)', () async {
    final prep = await Process.run('bash', [
      '-c',
      'set -euo pipefail; export S17_ROOT="$root"; '
          'source "$gate"; s17_jd_flutter_package_prepare',
    ], workingDirectory: root);
    expect(prep.exitCode, 0, reason: '${prep.stdout}\n${prep.stderr}');

    final out = File('${tmp.path}/init_out.json');
    final progress = File('${tmp.path}/init_progress.json');
    final req = File('${tmp.path}/init_req.json');
    req.writeAsStringSync('{}');

    final sw = Stopwatch()..start();
    final r = await Process.run(
      liveLauncher,
      [],
      environment: {
        ...Platform.environment,
        'S17_ROOT': root,
        'S17_JD_INIT_PROOF': '1',
        'S17_JD_LIVE_REQUEST_FILE': req.path,
        'S17_JD_LIVE_RESULT_FILE': out.path,
        'S17_JD_PROGRESS_FILE': progress.path,
        'S17_JD_FLUTTER_LOG_DIR': tmp.path,
        'S17_JD_NONTEST_TIMEOUT_SEC': '120',
        'S17_JD_FLUTTER_DEVICE':
            Platform.environment['S17_JD_FLUTTER_DEVICE'] ?? 'macos',
      },
      workingDirectory: root,
    );
    expect(sw.elapsedMilliseconds, lessThan(180000));
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(out.existsSync(), isTrue);
    final json = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    expect(json['ok'], isTrue);
    expect(json['classification'], 'JOURNEY_D_SUPABASE_INIT_PROOF_OK');
    expect(json['current_status'], 'succeeded');
    expect(json['test_binding_present'], isFalse);
    expect(progress.existsSync(), isTrue);
    final prog = jsonDecode(progress.readAsStringSync()) as Map<String, dynamic>;
    expect(prog['current_status'], 'succeeded');
    expect(prog['terminal'], isTrue);
    expect(jsonEncode(json).toLowerCase(), isNot(contains('password')));
    expect(jsonEncode(json), isNot(contains('otnhhdxs')));
    expect(jsonEncode(json), isNot(contains('tsbadngz')));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('10 execute loopback proof still works', () async {
    final prep = await Process.run('bash', [
      '-c',
      'set -euo pipefail; export S17_ROOT="$root"; '
          'source "$gate"; s17_jd_flutter_package_prepare',
    ], workingDirectory: root);
    expect(prep.exitCode, 0);

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async => server.close(force: true));
    server.listen((req) async {
      await req.drain<void>();
      final fail = req.uri.path.contains('fail');
      req.response.statusCode = fail ? 503 : (req.method == 'POST' ? 201 : 200);
      req.response.write(fail ? '{"ok":false}' : '{"ok":true}');
      await req.response.close();
    });

    final out = File('${tmp.path}/exec_out.json');
    final req = File('${tmp.path}/exec_req.json');
    req.writeAsStringSync(jsonEncode({'marker': 's17_jd_adapt_20260805T012428Z_933d9364'}));
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
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('11 live cannot silent-fake; production denied in init validator', () {
    expect(
      () => JourneyDNonTestRuntime.validateSupabaseConfig(
        url: 'https://otnhhdxs.example.supabase.co',
        anonOrServiceKey: 'x',
      ),
      throwsA(isA<JourneyDSupabaseInitException>()),
    );
    final launcher = File(liveLauncher).readAsStringSync();
    expect(launcher, contains('S17_JD_INIT_PROOF'));
    expect(launcher, contains('S17_JD_ALLOW_FAKE_PORTS'));
  });
}
