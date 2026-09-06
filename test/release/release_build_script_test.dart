import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'synthetic_jwts.dart';

void main() {
  final root = Directory.current.path;
  final script = File('$root/tool/release/build_app.sh');
  final runDev = File('$root/tool/release/run_development.sh');

  test('build script dry-run keeps repo .env untouched and hides keys', () async {
    final envFile = File('$root/.env');
    final before = envFile.existsSync() ? envFile.lastModifiedSync() : null;
    final config = File('${Directory.systemTemp.path}/cohort-script-test.json')
      ..writeAsStringSync(
        '{"COHORT_BUILD_ENV":"loopbackPreview",'
        '"COHORT_SUPABASE_URL":"http://127.0.0.1:54321",'
        '"COHORT_SUPABASE_ANON_KEY":"${SyntheticJwts.anon}"}',
      );

    final first = await Process.run('bash', [
      script.path,
      '--env',
      'loopbackPreview',
      '--target',
      'macos',
      '--config',
      config.path,
      '--dry-run',
    ]);
    final second = await Process.run('bash', [
      script.path,
      '--env',
      'loopbackPreview',
      '--target',
      'ios',
      '--config',
      config.path,
      '--dry-run',
    ]);

    expect(first.exitCode, 0, reason: first.stderr.toString());
    expect(second.exitCode, 0, reason: second.stderr.toString());
    expect(first.stdout, contains('ENV=loopbackPreview'));
    expect(first.stdout, contains('TARGET=macos'));
    expect(second.stdout, contains('TARGET=ios'));
    expect(first.stdout, isNot(contains(SyntheticJwts.anon)));
    expect(second.stdout, isNot(contains(SyntheticJwts.anon)));
    expect(first.stdout.toLowerCase(), isNot(contains('service_role')));
    if (before != null) {
      expect(envFile.lastModifiedSync(), before);
    }
  });

  test('production dry-run rejects loopback config before flutter', () async {
    final config = File('${Directory.systemTemp.path}/cohort-invalid-prod.json')
      ..writeAsStringSync(
        '{"COHORT_BUILD_ENV":"production",'
        '"COHORT_SUPABASE_URL":"http://127.0.0.1:54321",'
        '"COHORT_SUPABASE_ANON_KEY":"${SyntheticJwts.anon}"}',
      );
    final result = await Process.run('bash', [
      script.path,
      '--env',
      'production',
      '--target',
      'macos',
      '--config',
      config.path,
      '--dry-run',
    ]);
    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('production config host class rejected'));
    expect(result.stdout, isNot(contains(SyntheticJwts.anon)));
    expect(result.stderr, isNot(contains(SyntheticJwts.anon)));
  });

  test('development runner dry-run does not rewrite .env', () async {
    final repoEnv = File('$root/.env');
    final before = repoEnv.existsSync() ? repoEnv.lastModifiedSync() : null;
    final tempEnv = File('${Directory.systemTemp.path}/cohort-dev-test.env')
      ..writeAsStringSync(
        'SUPABASE_URL=http://127.0.0.1:54321\n'
        'SUPABASE_ANON_KEY=${SyntheticJwts.anon}\n',
      );
    final result = await Process.run('bash', [
      runDev.path,
      '--dry-run',
    ], environment: {...Platform.environment, 'COHORT_DEV_ENV_FILE': tempEnv.path});
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('ENV=development'));
    expect(result.stdout, isNot(contains(SyntheticJwts.anon)));
    if (before != null) {
      expect(repoEnv.lastModifiedSync(), before);
    }
  });
}
