import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Isolated package-config freshness. Does not mutate the repository
/// `.dart_tool/package_config.json`.
void main() {
  final repo = Directory.current.path;
  final gate = '$repo/tool/staging/lib/s17_jd_flutter_package_gate.sh';

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('jd_pkg_gate_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  File writeConfig({required String dir, required String body}) {
    Directory('$dir/.dart_tool').createSync();
    final file = File('$dir/.dart_tool/package_config.json');
    file.writeAsStringSync(body);
    return file;
  }

  const validConfig = '''
{
  "configVersion": 2,
  "packages": [
    {"name": "cohort_platform", "rootUri": "../", "packageUri": "lib/"}
  ]
}
''';

  test('pubspec.yaml version stamp does not stale a lock-consistent config',
      () async {
    File('$repo/pubspec.yaml').copySync('${tmp.path}/pubspec.yaml');
    File('$repo/pubspec.lock').copySync('${tmp.path}/pubspec.lock');
    final config = writeConfig(dir: tmp.path, body: validConfig);
    final past = DateTime.now().subtract(const Duration(hours: 2));
    config.setLastModifiedSync(past);
    File('${tmp.path}/pubspec.lock').setLastModifiedSync(past);
    File('${tmp.path}/pubspec.yaml').setLastModifiedSync(DateTime.now());

    final r = await Process.run('bash', [
      '-c',
      'set -euo pipefail; export S17_ROOT="${tmp.path}"; '
          'source "$gate"; s17_jd_flutter_package_require',
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    expect(r.stdout.toString(), contains('required_ok'));
  });

  test('lockfile newer than package_config is stale', () async {
    File('$repo/pubspec.yaml').copySync('${tmp.path}/pubspec.yaml');
    File('$repo/pubspec.lock').copySync('${tmp.path}/pubspec.lock');
    final config = writeConfig(dir: tmp.path, body: validConfig);
    config.setLastModifiedSync(
      DateTime.now().subtract(const Duration(hours: 2)),
    );
    File('${tmp.path}/pubspec.lock').setLastModifiedSync(DateTime.now());

    final r = await Process.run('bash', [
      '-c',
      'set -euo pipefail; export S17_ROOT="${tmp.path}"; '
          'source "$gate"; s17_jd_flutter_package_require',
    ]);
    expect(r.exitCode, 2);
    expect('${r.stdout}\n${r.stderr}', contains('stale package_config'));
  });

  test('missing package_config fails require without touching repo config',
      () async {
    File('$repo/pubspec.yaml').copySync('${tmp.path}/pubspec.yaml');
    File('$repo/pubspec.lock').copySync('${tmp.path}/pubspec.lock');
    final r = await Process.run('bash', [
      '-c',
      'set -euo pipefail; export S17_ROOT="${tmp.path}"; '
          'source "$gate"; s17_jd_flutter_package_require',
    ]);
    expect(r.exitCode, 2);
    expect('${r.stdout}\n${r.stderr}', contains('missing .dart_tool/package_config.json'));
    expect(File('$repo/.dart_tool/package_config.json').existsSync(), isTrue);
  });
}
