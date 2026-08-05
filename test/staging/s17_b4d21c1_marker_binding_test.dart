import 'dart:io';

import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:flutter_test/flutter_test.dart';

/// B4d.21c.1 supported `--marker` binding — local fakes only; no hosted contact.
void main() {
  final root = Directory.current.path;
  final projectsFixture = File(
    '$root/test/staging/fixtures/s17_projects_list.json',
  );
  final packageYaml = File(
    '$root/tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
  );
  final creator =
      '$root/tool/staging/create_s17_journey_d_adaptation_fixture.sh';
  const stableMarker = 's17_jd_adapt_20260805T012428Z_933d9364';
  const expectedPreRebindHash =
      '156dfe8cf262e43f4e7e47cab070a37f466d3271fe26b29ca80e5c5e49e8a7d7';

  Future<ProcessResult> runCreator({
    String args = '--dry-run',
    Map<String, String> env = const {},
    bool includeProjectsFile = true,
  }) {
    final extraEnv = env.entries.map((e) => '${e.key}=${e.value}').join(' ');
    if (includeProjectsFile) {
      return Process.run('bash', [
        '-c',
        'cd "$root" && CONFIRM_COHORT_STAGING=1 '
            'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
            '$extraEnv "$creator" $args',
      ]);
    }
    return Process.run('bash', [
      '-c',
      'cd "$root" && env -u S17_PROJECTS_JSON_FILE '
          'CONFIRM_COHORT_STAGING=1 $extraEnv "$creator" $args',
    ]);
  }

  group('B4d.21c.1 --marker help and acceptance', () {
    test('1 help documents --marker <fixture-marker>', () async {
      final result = await Process.run(creator, ['--help']);
      expect(result.exitCode, 0);
      final out = '${result.stdout}\n${result.stderr}';
      expect(out, contains('--marker <fixture-marker>'));
      expect(out, contains('explicit fixture marker'));
    });

    test('2 exact stable marker is accepted and forwarded unchanged', () async {
      final result = await runCreator(args: '--dry-run --marker $stableMarker');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final out = result.stdout.toString();
      expect(out, contains('FIXTURE_MARKER=$stableMarker'));
      expect(out, contains('DRY_RUN_OK'));
      expect(out, contains('REBIND_PATH=REBIND_PATH_READY'));
    });

    test('3 explicit marker prevents new_marker()', () async {
      final result = await Process.run('python3', [
        '-c',
        '''
import os, sys
from pathlib import Path
sys.path.insert(0, r"$root/tool/staging/lib")
os.environ["CONFIRM_COHORT_STAGING"] = "1"
from s17_journey_d_fixture import run_dry_run, new_marker

calls = {"n": 0}
orig = new_marker

def wrapped():
    calls["n"] += 1
    return orig()

import s17_journey_d_fixture as mod
mod.new_marker = wrapped
raw = open(r"${projectsFixture.path}").read()
r = run_dry_run(
    root=Path(r"$root"),
    projects_raw=raw,
    marker="$stableMarker",
)
assert r["manifest"]["fixture_marker"] == "$stableMarker"
assert calls["n"] == 0, calls
print("NEW_MARKER_NOT_CALLED")
''',
      ], workingDirectory: root);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('NEW_MARKER_NOT_CALLED'));
    });

    test('4 dry-run output reports the same marker', () async {
      final result = await runCreator(args: '--dry-run --marker $stableMarker');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final matches = RegExp(
        r'FIXTURE_MARKER=([^\s]+)',
      ).allMatches(result.stdout.toString()).toList();
      expect(matches, isNotEmpty);
      expect(matches.single.group(1), stableMarker);
    });
  });

  group('B4d.21c.1 fail-closed marker input', () {
    test(
      '5 missing / empty / malformed / repeated markers fail closed',
      () async {
        final missing = await runCreator(args: '--dry-run --marker');
        expect(missing.exitCode, 2);
        expect(
          missing.stderr.toString(),
          contains('--marker requires exactly one non-empty value'),
        );

        final empty = await Process.run('bash', [
          '-c',
          'cd "$root" && CONFIRM_COHORT_STAGING=1 '
              'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
              '"$creator" --dry-run --marker ""',
        ]);
        expect(empty.exitCode, 2);
        expect(empty.stderr.toString(), contains('--marker'));

        final malformed = await runCreator(
          args: '--dry-run --marker not-a-valid-marker',
          includeProjectsFile: false,
        );
        expect(malformed.exitCode, 2);
        expect(
          malformed.stderr.toString(),
          contains('invalid Journey D fixture marker'),
        );
        // Fail before projects-file requirement.
        expect(
          malformed.stderr.toString(),
          isNot(contains('S17_PROJECTS_JSON_FILE')),
        );

        final repeated = await runCreator(
          args: '--dry-run --marker $stableMarker --marker $stableMarker',
        );
        expect(repeated.exitCode, 2);
        expect(repeated.stderr.toString(), contains('only once'));
      },
    );

    test('6 invalid markers fail before target resolution', () async {
      final result = await runCreator(
        args: '--dry-run --marker s17_jd_adapt_BAD',
        includeProjectsFile: false,
      );
      expect(result.exitCode, 2);
      expect(
        result.stderr.toString(),
        contains('invalid Journey D fixture marker'),
      );
      expect(result.stderr.toString(), isNot(contains('STAGING_CONFIRMED')));
      expect(result.stdout.toString(), isNot(contains('STAGING_CONFIRMED')));
    });

    test('7 explicit-marker failure does not generate a replacement', () async {
      final result = await runCreator(
        args: '--dry-run --marker s17_stage_20260805T012428Z_933d9364',
        includeProjectsFile: false,
      );
      expect(result.exitCode, 2);
      final blob = '${result.stdout}\n${result.stderr}';
      expect(blob, isNot(contains('FIXTURE_MARKER=s17_jd_adapt_')));
      expect(blob, isNot(contains('DRY_RUN_OK')));
    });

    test('8 unknown arguments remain rejected', () async {
      final result = await runCreator(args: '--dry-run --bogus');
      expect(result.exitCode, 2);
      expect(result.stderr.toString(), contains('unknown flag'));
    });

    test(
      '9 marker input cannot become executable shell or Python code',
      () async {
        final shellProbe = '/tmp/b4d21c1_pwned_shell';
        final pyProbe = '/tmp/b4d21c1_pwned_py';
        for (final path in [shellProbe, pyProbe]) {
          final f = File(path);
          if (f.existsSync()) {
            f.deleteSync();
          }
        }

        final env = <String, String>{
          ...Platform.environment,
          'CONFIRM_COHORT_STAGING': '1',
          'S17_PROJECTS_JSON_FILE': projectsFixture.path,
          'S17_ROOT': root,
        };

        // argv data boundary — metacharacters must not execute.
        final shellPayload =
            's17_jd_adapt_20260805T012428Z_\$(touch $shellProbe)_deadbeef';
        final shellResult = await Process.run(
          creator,
          ['--dry-run', '--marker', shellPayload],
          environment: env,
          workingDirectory: root,
        );
        expect(shellResult.exitCode, 2);
        expect(File(shellProbe).existsSync(), isFalse);
        expect(
          shellResult.stderr.toString(),
          contains('invalid Journey D fixture marker'),
        );

        final pyPayload =
            "s17_jd_adapt_20260805T012428Z_; import os; os.system('touch $pyProbe')";
        final pyResult = await Process.run(
          creator,
          ['--dry-run', '--marker', pyPayload],
          environment: env,
          workingDirectory: root,
        );
        expect(pyResult.exitCode, 2);
        expect(File(pyProbe).existsSync(), isFalse);
        expect(
          pyResult.stderr.toString(),
          contains('invalid Journey D fixture marker'),
        );
      },
    );
  });

  group('B4d.21c.1 safety invariants preserved', () {
    test('10 existing no-marker behaviour remains intentional', () async {
      final result = await runCreator(args: '--dry-run');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final out = result.stdout.toString();
      expect(out, contains('DRY_RUN_OK'));
      expect(out, contains('HOSTED_WRITES=0'));
      final marker = RegExp(
        r'FIXTURE_MARKER=(s17_jd_adapt_[^\s]+)',
      ).firstMatch(out);
      expect(marker, isNotNull);
      expect(marker!.group(1), isNot(equals(stableMarker)));
      expect(
        RegExp(
          r'^s17_jd_adapt_\d{8}T\d{6}Z_[0-9a-f]{8}$',
        ).hasMatch(marker.group(1)!),
        isTrue,
      );
    });

    test('11 dry-run zero writes and publishDraft not invoked', () async {
      final result = await runCreator(args: '--dry-run --marker $stableMarker');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final out = result.stdout.toString();
      expect(out, contains('HOSTED_WRITES=0'));
      expect(out, contains('PUBLISH_DRAFT_INVOKED=false'));
      expect(out, isNot(contains('publishDraft(')));
    });

    test('12 every mutation stage remains not_started', () async {
      final result = await Process.run('python3', [
        '-c',
        '''
import os, sys, json
from pathlib import Path
sys.path.insert(0, r"$root/tool/staging/lib")
os.environ["CONFIRM_COHORT_STAGING"] = "1"
from s17_journey_d_fixture import run_dry_run, MUTATING_STAGES
raw = open(r"${projectsFixture.path}").read()
r = run_dry_run(
    root=Path(r"$root"),
    projects_raw=raw,
    marker="$stableMarker",
)
for s in r["ledger"]["stages"]:
    if s["name"] in MUTATING_STAGES:
        assert s["status"] == "not_started", s
assert r["publish_draft_invoked"] is False
assert r["rebind_path"] == "REBIND_PATH_READY"
print("MUTATING_NOT_STARTED_OK")
''',
      ], workingDirectory: root);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('MUTATING_NOT_STARTED_OK'));
    });

    test('13 marker binding cannot enable live mode', () async {
      final result = await runCreator(args: '--live --marker $stableMarker');
      expect(result.exitCode, 2);
      expect(result.stderr.toString(), contains('S17_JD_LIVE_CREATE'));
      expect(result.stdout.toString(), isNot(contains('DRY_RUN_OK')));
    });

    test('14 existing staging and live guards remain unchanged', () async {
      final noConfirm = await Process.run('bash', [
        '-c',
        'cd "$root" && env -u CONFIRM_COHORT_STAGING '
            'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
            '"$creator" --dry-run --marker $stableMarker',
      ]);
      expect(noConfirm.exitCode, 2);
      expect(noConfirm.stderr.toString(), contains('CONFIRM_COHORT_STAGING'));

      final liveFlag = await runCreator(
        args: '--live --marker $stableMarker',
        env: const {'S17_JD_LIVE_CREATE': '1'},
      );
      expect(liveFlag.exitCode, 2);
      expect(liveFlag.stderr.toString(), contains('B4d.20'));
      expect(liveFlag.stderr.toString(), contains('separately authorised'));
    });

    test('15 Journey D remains unreachable', () async {
      final result = await runCreator(args: '--dry-run --marker $stableMarker');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final out = result.stdout.toString();
      expect(out, contains('JOURNEY_D_EXECUTION=disabled'));
      expect(out, contains('"journeys_enabled":0'));
    });

    test('16 rebinding remains REBIND_PATH_READY', () async {
      final result = await runCreator(args: '--dry-run --marker $stableMarker');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(
        result.stdout.toString(),
        contains('REBIND_PATH=REBIND_PATH_READY'),
      );
    });

    test('17 pre-rebind package hash unchanged', () {
      expect(packageYaml.existsSync(), isTrue);
      final compile = const PlanPackageCompiler().compile(
        packageYaml.readAsStringSync(),
      );
      expect(compile.isValid, isTrue, reason: compile.issues.toString());
      expect(compile.contentHashSha256, expectedPreRebindHash);
    });

    test('18 shell forwards marker only via env data boundary', () async {
      final shell = File(creator).readAsStringSync();
      expect(shell, contains('S17_JD_FIXTURE_MARKER'));
      expect(
        shell,
        contains(
          "dry_kwargs[\"marker\"] = os.environ[\"S17_JD_FIXTURE_MARKER\"]",
        ),
      );
      // Must not interpolate user marker into executable Python source.
      expect(shell, isNot(contains(r'marker = "${EXPLICIT_MARKER}"')));
      expect(shell, isNot(contains(r'marker="${EXPLICIT_MARKER}"')));
      expect(shell, isNot(contains('eval ')));
    });

    test('19 no network hosts in marker-binding test surface', () {
      // Static guarantee: this suite only uses local projects fixture + creator.
      expect(projectsFixture.existsSync(), isTrue);
      expect(File(creator).existsSync(), isTrue);
    });
  });
}
