import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Local non-hosted validation of Athlete E bootstrap guards (Python module).
void main() {
  final root = Directory.current.path;
  final script = '$root/test/staging/s17e_athlete_e_bootstrap_test.py';

  test('Athlete E bootstrap unit tests pass without hosted contact', () async {
    final result = await Process.run('python3', [script], workingDirectory: root);
    expect(
      result.exitCode,
      0,
      reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
    );
    final out = '${result.stdout}\n${result.stderr}';
    expect(out, contains('OK'));
    expect(out.toLowerCase(), isNot(contains('db push')));
  });

  test('shell dry-run refuses hosted without S17E_HOSTED_CREATE', () async {
    final creator = '$root/tool/staging/create_s17_athlete_e_fixture.sh';
    final result = await Process.run('bash', [
      '-c',
      'cd "$root" && CONFIRM_COHORT_STAGING=1 '
          'env -u S17E_HOSTED_CREATE "$creator" --hosted',
    ]);
    expect(result.exitCode, isNot(0));
    final out = '${result.stdout}\n${result.stderr}';
    expect(out, contains('REFUSED'));
    expect(out, isNot(contains('ATHLETE_CREATED=true')));
  });

  test('shell refuses cleanup mode', () async {
    final creator = '$root/tool/staging/create_s17_athlete_e_fixture.sh';
    final result = await Process.run(creator, ['--cleanup']);
    expect(result.exitCode, isNot(0));
    expect('${result.stdout}\n${result.stderr}', contains('REFUSED'));
  });
}
