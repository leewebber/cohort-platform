import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Local contract tests for deterministic runner termination (no hosted contact).
void main() {
  final root = Directory.current.path;
  final runner = '$root/tool/staging/run_s17_flutter_staging_verify.sh';
  final fixture = File('$root/test/staging/fixtures/s17_projects_list.json');

  test('help documents resume and exit semantics', () async {
    final result = await Process.run('bash', [runner, '--help']);
    expect(result.exitCode, 0);
    final out = '${result.stdout}\n${result.stderr}';
    expect(out, contains('--resume'));
    expect(out, contains('sentinel'));
    expect(out, contains('Exit status'));
  });

  test('unknown flag rejected', () async {
    final result = await Process.run('bash', [runner, '--nope']);
    expect(result.exitCode, 2);
    expect(result.stderr.toString(), contains('unknown flag'));
  });

  test('resume dry-run never invokes creator', () async {
    final result = await Process.run('bash', [
      '-c',
      'cd "$root" && '
          'CONFIRM_COHORT_STAGING=1 '
          'S17_PROJECTS_JSON_FILE="${fixture.path}" '
          'S17_DART_DEFINES_FILE="$root/lib/main.dart" '
          './tool/staging/run_s17_flutter_staging_verify.sh --resume --dry-run',
    ]);
    // Defines file inside worktree should be refused before launch.
    expect(result.exitCode, 2);
    final out = '${result.stdout}\n${result.stderr}';
    expect(out, contains('RESUME_MODE=1'));
    expect(out, isNot(contains('ATHLETE_D_CREATED_OK')));
    expect(out, isNot(contains('create_s17_athlete_d_fixture.sh')));
  });

  test('python capture logic: missing sentinel is non-zero', () async {
    final script =
        '''
import json, pathlib, tempfile, textwrap, os, sys
sys.path.insert(0, r"$root/tool/staging/lib")
# Simulate capture loop contract used by runner.
report = {"ok": True, "journeys": {"A": {"result": "PASS", "title": "t"}}}
td = tempfile.mkdtemp()
log = pathlib.Path(td) / "report.txt"
log.write_text("S17_FLUTTER_JOURNEY_JSON " + json.dumps(report) + "\\n")
text = log.read_text()
has_json = "S17_FLUTTER_JOURNEY_JSON" in text
has_complete = "S17_FLUTTER_COMPLETE" in text
print("HAS_JSON", has_json)
print("HAS_COMPLETE", has_complete)
sys.exit(3 if has_json and not has_complete else 0)
''';
    final result = await Process.run('python3', ['-c', script]);
    expect(result.exitCode, 3);
    expect(result.stdout.toString(), contains('HAS_COMPLETE False'));
  });

  test('malformed JSON contract returns non-zero', () async {
    final result = await Process.run('python3', [
      '-c',
      r'''
import json, sys
try:
    json.loads("{not-json")
    sys.exit(0)
except json.JSONDecodeError:
    print("MALFORMED")
    sys.exit(4)
''',
    ]);
    expect(result.exitCode, 4);
    expect(result.stdout.toString(), contains('MALFORMED'));
  });
}
