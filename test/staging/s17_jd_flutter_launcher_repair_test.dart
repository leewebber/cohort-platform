import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Deterministic Flutter launcher repair for Journey D create/execute.
///
/// Proves package preparation is separated from --no-pub live invocation.
/// Fake ports only — no hosted contact.
void main() {
  final root = Directory.current.path;
  final liveLauncher = '$root/tool/staging/run_s17_journey_d_live_dart.sh';
  final execLauncher = '$root/tool/staging/run_s17_journey_d_execute_dart.sh';
  final gate = '$root/tool/staging/lib/s17_jd_flutter_package_gate.sh';
  const stableMarker = 's17_jd_adapt_20260805T012428Z_933d9364';

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('jd_launcher_repair_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Map<String, String> liveEnv({String? resultPath}) {
    final req = File('${tmp.path}/req.json');
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
    return {
      ...Platform.environment,
      'CONFIRM_COHORT_STAGING': '1',
      'S17_JD_LIVE_CREATE': '1',
      'S17_JD_LIVE_PORTS': 'fake',
      'S17_JD_ALLOW_FAKE_PORTS': '1',
      'S17_JD_LIVE_REQUEST_FILE': req.path,
      'S17_JD_LIVE_RESULT_FILE': resultPath ?? '${tmp.path}/out.json',
      'S17_ROOT': root,
    };
  }

  group('package gate + --no-pub launchers', () {
    test('1 gate and launchers encode prepare/require/--no-pub contract', () {
      final gateSrc = File(gate).readAsStringSync();
      expect(gateSrc, contains('s17_jd_flutter_package_prepare'));
      expect(gateSrc, contains('s17_jd_flutter_package_require'));
      expect(gateSrc, contains('pubspec.lock'));
      expect(gateSrc, contains('package_config.json'));

      for (final path in [liveLauncher, execLauncher]) {
        final src = File(path).readAsStringSync();
        expect(src, contains('--no-pub'));
        expect(src, contains('s17_jd_flutter_package_require'));
        // Launchers must not invoke pub get as a command (comments may mention it).
        expect(src, isNot(contains('\nflutter pub get')));
        expect(src, isNot(contains('flutter pub get\n')));
        expect(RegExp(r'^\s*flutter pub get\b', multiLine: true).hasMatch(src),
            isFalse);
      }
    });

    test('2 creator launcher reaches fake orchestration without resolution',
        () async {
      final prep = await Process.run('bash', [
        '-c',
        'set -euo pipefail; export S17_ROOT="$root"; '
            'source "$gate"; s17_jd_flutter_package_prepare',
      ], workingDirectory: root);
      expect(prep.exitCode, 0, reason: '${prep.stdout}\n${prep.stderr}');

      final r = await Process.run(
        liveLauncher,
        [],
        environment: liveEnv(),
        workingDirectory: root,
      );
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      final out = '${r.stdout}\n${r.stderr}';
      expect(out, isNot(contains('Resolving dependencies...')));
      expect(out, contains('All tests passed'));
      final result =
          jsonDecode(File('${tmp.path}/out.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(result['ok'], isTrue);
      expect(result['ports_mode'], 'fake');
      expect(result['hosted_writes_executed'], 0);
      expect(result['fixture_marker'] ?? result['marker'], stableMarker);
      expect(jsonEncode(result), isNot(contains('@example.invalid')));
      expect(jsonEncode(result).toLowerCase(), isNot(contains('"password"')));
    });

    test('3 execute launcher requires package config and uses --no-pub', () async {
      final src = File(execLauncher).readAsStringSync();
      expect(src, contains('--no-pub'));
      // Missing credential/env fails before flutter resolve.
      final r = await Process.run(
        execLauncher,
        [],
        environment: {
          ...Platform.environment,
          'CONFIRM_COHORT_STAGING': '1',
          'S17_JD_EXECUTE': '1',
          'S17_ROOT': root,
          // request/result/credential intentionally missing
        },
        workingDirectory: root,
      );
      expect(r.exitCode, 2);
      final err = '${r.stdout}\n${r.stderr}';
      expect(err, contains('REFUSED'));
      expect(err, isNot(contains('Resolving dependencies...')));
    });

    test('4 missing package_config fails before hosted contact', () async {
      final cfg = File('$root/.dart_tool/package_config.json');
      final bak = File('${tmp.path}/package_config.json.bak');
      expect(cfg.existsSync(), isTrue);
      cfg.copySync(bak.path);
      cfg.deleteSync();
      try {
        final r = await Process.run(
          liveLauncher,
          [],
          environment: liveEnv(resultPath: '${tmp.path}/missing_cfg_out.json'),
          workingDirectory: root,
        );
        expect(r.exitCode, 2);
        final err = '${r.stdout}\n${r.stderr}';
        expect(err, contains('package_config'));
        expect(err, isNot(contains('Resolving dependencies...')));
        expect(File('${tmp.path}/missing_cfg_out.json').existsSync(), isFalse);
      } finally {
        bak.copySync(cfg.path);
      }
    });

    test('5 genuine live mode still selects hosted ports (no silent fake)',
        () async {
      // Direct entrypoint contract preserved by existing suite; assert launcher
      // does not hardcode fake ports.
      final src = File(liveLauncher).readAsStringSync();
      expect(src, isNot(contains('S17_JD_LIVE_PORTS=fake')));
      expect(src, isNot(contains('ALLOW_FAKE_PORTS=1')));
    });

    test('6 working directory is repository package root', () async {
      final r = await Process.run('bash', [
        '-c',
        'set -euo pipefail; export S17_ROOT="$root"; '
            'source "$gate"; s17_jd_flutter_package_paths; '
            'test "\$JD_PUBSPEC" = "$root/pubspec.yaml"; '
            'test "\$JD_LOCKFILE" = "$root/pubspec.lock"; '
            'echo PATHS_OK',
      ], workingDirectory: root);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(r.stdout.toString(), contains('PATHS_OK'));
    });
  });
}
