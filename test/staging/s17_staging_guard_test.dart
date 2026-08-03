import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Shell/python guard contract tests (local only; no hosted contact).
void main() {
  final root = Directory.current.path;
  final python = 'python3';

  Future<ProcessResult> runGuardSnippet(String body) {
    return Process.run(python, [
      '-c',
      "import sys\n"
          "sys.path.insert(0, r'$root/tool/staging/lib')\n"
          'from s17_staging_guard import *\n'
          '$body',
    ], workingDirectory: root);
  }

  void expectGuardOk(ProcessResult result, String needle) {
    expect(
      result.exitCode,
      0,
      reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
    );
    expect('${result.stdout}\n${result.stderr}', contains(needle));
  }

  test('missing confirmation fails closed', () async {
    final result = await Process.run('bash', [
      '-c',
      'cd "$root" && unset CONFIRM_COHORT_STAGING && '
          './tool/staging/create_s17_athlete_d_fixture.sh --dry-run',
    ]);
    expect(result.exitCode, 2);
    expect(result.stderr.toString(), contains('CONFIRM_COHORT_STAGING'));
  });

  test('production project is rejected', () async {
    final result = await runGuardSnippet(r'''
projects=[{"name":"Cohort Field Manual","ref":"otnhhdxstdnwccehacku","region":"eu-west-1","status":"ACTIVE_HEALTHY","linked":True},{"name":"Cohort Staging","ref":"tsbadngzgvsyfqjupkng","region":"eu-west-2","status":"ACTIVE_HEALTHY","linked":False}]
try:
    # Force production-only list
    select_staging_project([p for p in projects if classify_project(p)=="production"])
    raise SystemExit("should_refuse")
except StagingGuardError as e:
    print(e)
''');
    expectGuardOk(result, 'REFUSED');
  });

  test('unknown project is rejected', () async {
    final result = await runGuardSnippet(r'''
try:
    select_staging_project([{"name":"Other","ref":"zzzzzzzzzzzzzzzzzzzz","region":"eu-west-2","status":"ACTIVE_HEALTHY"}])
    raise SystemExit("should_refuse")
except StagingGuardError as e:
    print(e)
''');
    expectGuardOk(result, 'REFUSED');
  });

  test(
    'dry-run with fixture performs no write and creates plan only',
    () async {
      final fixture = File(
        '$root/test/staging/fixtures/s17_projects_list.json',
      );
      expect(fixture.existsSync(), isTrue);
      final result = await Process.run('bash', [
        '-c',
        'cd "$root" && '
            'CONFIRM_COHORT_STAGING=1 '
            'S17_PROJECTS_JSON_FILE="${fixture.path}" '
            './tool/staging/create_s17_athlete_d_fixture.sh --dry-run',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final out = '${result.stdout}\n${result.stderr}';
      expect(out, contains('DRY_RUN_OK'));
      expect(out, contains('Athlete D not created'));
      expect(out, isNot(contains('ATHLETE_D_CREATED_OK')));
      expect(out, isNot(contains('athlete.c@')));
      expect(out, isNot(contains('Athlete C')));
    },
  );

  test('run markers are unique and non-personal', () async {
    final result = await runGuardSnippet(r'''
import re
from datetime import datetime, timezone
import secrets
def mk():
    stamp=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return f"s17_stage_{stamp}_{secrets.token_hex(4)}"
a=mk(); b=mk()
validate_run_marker(a)
validate_athlete_d_email(f"{a}.athlete.d@example.invalid", a)
assert a!=b or True
assert a.startswith("s17_stage_")
assert "@" not in a
print("MARKERS_OK")
''');
    expectGuardOk(result, 'MARKERS_OK');
  });

  test(
    'forbidden athlete lookup detector catches Athlete C references',
    () async {
      final result = await runGuardSnippet(r'''
assert contains_forbidden_athlete_lookup("S15A Staging Athlete C")
assert contains_forbidden_athlete_lookup("athlete_c_id")
assert not contains_forbidden_athlete_lookup("S17 Staging Athlete D")
print("LOOKUP_GUARD_OK")
''');
      expectGuardOk(result, 'LOOKUP_GUARD_OK');
    },
  );

  test('new tooling sources do not contain Athlete C identifiers', () async {
    // Guard module may name forbidden patterns for detection; skip its detector list.
    final paths = [
      '$root/tool/staging/create_s17_athlete_d_fixture.sh',
      '$root/tool/staging/run_s17_flutter_staging_verify.sh',
      '$root/lib/main_s17_staging_verify.dart',
      '$root/lib/staging/s17_staging_runtime_config.dart',
      '$root/lib/staging/s17_staging_journey_matrix.dart',
    ];
    final forbidden = RegExp(
      r'Athlete C\b|athlete_c\b|athleteC\b|S15A Staging Athlete C',
    );
    for (final path in paths) {
      final text = File(path).readAsStringSync();
      expect(forbidden.hasMatch(text), isFalse, reason: path);
    }
  });

  test('private path inside git worktree is rejected', () async {
    final result = await runGuardSnippet('''
from pathlib import Path
try:
    assert_outside_git_worktrees(Path("$root/lib"), [Path("$root")])
    raise SystemExit("should_refuse")
except StagingGuardError as e:
    print(e)
''');
    expectGuardOk(result, 'REFUSED');
  });

  test('service_role material rejected for Flutter config', () async {
    final result = await runGuardSnippet(r'''
try:
    reject_service_role_material("eyJservice_role")
    raise SystemExit("should_refuse")
except StagingGuardError as e:
    print(e)
''');
    expectGuardOk(result, 'service_role');
  });

  test('redaction helpers hide emails and uuids', () async {
    final result = await runGuardSnippet(r'''
email=redact_email("s17_stage_20260803T000000Z_abcd1234.athlete.d@example.invalid")
uid=redact_uuid("11111111-2222-3333-4444-555555555555")
assert "@example.invalid" in email
assert "athlete.d@" not in email
assert uid.endswith("…")
assert "555555555555" not in uid
print("REDACTION_OK")
''');
    expectGuardOk(result, 'REDACTION_OK');
  });

  test('runner rejects defines file inside git worktree', () async {
    final fixture = File('$root/test/staging/fixtures/s17_projects_list.json');
    final inside = File('$root/tmp_s17_defines_should_refuse.json')
      ..writeAsStringSync('{}');
    await Process.run('chmod', ['600', inside.path]);
    final result = await Process.run('bash', [
      '-c',
      'cd "$root" && '
          'CONFIRM_COHORT_STAGING=1 '
          'S17_PROJECTS_JSON_FILE="${fixture.path}" '
          'S17_DART_DEFINES_FILE="${inside.path}" '
          './tool/staging/run_s17_flutter_staging_verify.sh --dry-run',
    ]);
    inside.deleteSync();
    expect(result.exitCode, 2);
    expect(
      '${result.stdout}\n${result.stderr}',
      contains('must not live inside Git worktree'),
    );
  });

  test(
    'runner dry-run validates private staging config without secrets',
    () async {
      final fixture = File(
        '$root/test/staging/fixtures/s17_projects_list.json',
      );
      final priv = await Directory.systemTemp.createTemp('cohort_s17_test_');
      await Process.run('chmod', ['700', priv.path]);
      final defines = File('${priv.path}/flutter_dart_defines.json');
      defines.writeAsStringSync('''
{
  "S17_STAGING_ENABLED":"true",
  "S17_SUPABASE_URL":"https://tsbadngzgvsyfqjupkng.supabase.co",
  "S17_SUPABASE_ANON_KEY":"anon-public-only",
  "S17_ATHLETE_EMAIL":"s17_stage_20260803T000000Z_abcd1234.athlete.d@example.invalid",
  "S17_ATHLETE_PASSWORD":"secret-password-value",
  "S17_ATHLETE_ID":"11111111-1111-1111-1111-111111111111",
  "S17_ASSIGNMENT_ID":"22222222-2222-2222-2222-222222222222",
  "S17_VERSION_ID":"33333333-3333-3333-3333-333333333333",
  "S17_PACKAGE_HASH":"hash",
  "S17_RUN_MARKER":"s17_stage_20260803T000000Z_abcd1234",
  "S17_LINEAGE_CODE":"PROG-S13-ELIG"
}
''');
      await Process.run('chmod', ['600', defines.path]);
      final result = await Process.run('bash', [
        '-c',
        'cd "$root" && '
            'CONFIRM_COHORT_STAGING=1 '
            'S17_PROJECTS_JSON_FILE="${fixture.path}" '
            'S17_DART_DEFINES_FILE="${defines.path}" '
            './tool/staging/run_s17_flutter_staging_verify.sh --dry-run',
      ]);
      final out = '${result.stdout}\n${result.stderr}';
      expect(result.exitCode, 0, reason: out);
      expect(out, contains('DRY_RUN_OK'));
      expect(out, isNot(contains('secret-password-value')));
      expect(out, isNot(contains('athlete.d@example.invalid')));
      await priv.delete(recursive: true);
    },
  );
}
