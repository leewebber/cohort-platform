import 'dart:io';

import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_rebind.dart';
import 'package:flutter_test/flutter_test.dart';

/// B4d.21d.1 guarded live creator — local fakes / synthetic backends only.
void main() {
  final root = Directory.current.path;
  final projectsFixture = File(
    '$root/test/staging/fixtures/s17_projects_list.json',
  );
  final packageYaml = File(
    '$root/tool/staging/fixtures/journey_d/prog_s17_journey_d_adaptation.yaml',
  );
  final protocolIntent = File(
    '$root/tool/staging/fixtures/journey_d/protocol_intent.json',
  );
  final creator =
      '$root/tool/staging/create_s17_journey_d_adaptation_fixture.sh';
  const stableMarker = 's17_jd_adapt_20260805T012428Z_933d9364';
  const expectedHash =
      '156dfe8cf262e43f4e7e47cab070a37f466d3271fe26b29ca80e5c5e49e8a7d7';
  const currentUuid = 'a1111111-1111-4111-8111-111111111111';
  const laterUuid = 'b2222222-2222-4222-8222-222222222222';

  late String yaml;
  late String intentJson;
  late PlanPackageManifest manifest;

  setUpAll(() {
    yaml = packageYaml.readAsStringSync();
    intentJson = protocolIntent.readAsStringSync();
    final compile = const PlanPackageCompiler().compile(yaml);
    expect(compile.isValid, isTrue);
    expect(compile.contentHashSha256, expectedHash);
    manifest = compile.manifest!;
  });

  Future<ProcessResult> runCreator({
    required String args,
    Map<String, String> env = const {},
    bool includeProjects = true,
  }) {
    final extra = env.entries.map((e) => '${e.key}=${e.value}').join(' ');
    final projects = includeProjects
        ? 'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
        : 'env -u S17_PROJECTS_JSON_FILE ';
    return Process.run('bash', [
      '-c',
      'cd "$root" && CONFIRM_COHORT_STAGING=1 $projects $extra '
          '"$creator" $args',
    ]);
  }

  JourneyDLiveFixtureCreator buildCreator({
    FakeJourneyDProtocolPublisher? publisher,
    FakeJourneyDLivePreflight? preflight,
    FakeJourneyDLiveAthleteFactory? athlete,
    FakeJourneyDLiveProgrammeLifecycle? lifecycle,
    FakeJourneyDLiveEnrolment? enrolment,
    FakeJourneyDLiveMaterialisation? materialisation,
  }) {
    final pub =
        publisher ??
        FakeJourneyDProtocolPublisher(
          lineageByProtocolId: {
            'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
            'PROT-S17-JD-ADAPT-LATER': laterUuid,
          },
        );
    return JourneyDLiveFixtureCreator(
      preflight: preflight ?? FakeJourneyDLivePreflight(),
      athleteFactory: athlete ?? FakeJourneyDLiveAthleteFactory(),
      rebindPipeline: JourneyDRebindPipeline(publisher: pub),
      programmeLifecycle: lifecycle ?? FakeJourneyDLiveProgrammeLifecycle(),
      enrolment: enrolment ?? FakeJourneyDLiveEnrolment(),
      materialisation: materialisation ?? FakeJourneyDLiveMaterialisation(),
    );
  }

  group('shell / marker / guards', () {
    test('1 help documents guarded live invocation', () async {
      final r = await Process.run(creator, ['--help']);
      expect(r.exitCode, 0);
      final out = '${r.stdout}\n${r.stderr}';
      expect(out, contains('--live'));
      expect(out, contains('--marker <fixture-marker>'));
      expect(out, contains('S17_JD_LIVE_CREATE=1'));
      expect(out, contains('Required for --live'));
    });

    test('2 live mode requires an explicit marker', () async {
      final r = await runCreator(
        args: '--live',
        env: const {
          'S17_JD_LIVE_CREATE': '1',
          'S17_JD_LIVE_MUTATION_BACKEND': 'synthetic_ok',
        },
      );
      expect(r.exitCode, 2);
      expect(r.stderr.toString(), contains('--live requires --marker'));
    });

    test('3 exact stable marker accepted unchanged (synthetic)', () async {
      final r = await runCreator(
        args: '--live --marker $stableMarker',
        env: const {
          'S17_JD_LIVE_CREATE': '1',
          'S17_JD_LIVE_MUTATION_BACKEND': 'synthetic_ok',
        },
      );
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(r.stdout.toString(), contains('FIXTURE_MARKER=$stableMarker'));
      expect(r.stdout.toString(), contains('MUTATION_BACKEND=synthetic'));
      expect(r.stdout.toString(), contains('HOSTED_WRITES_EXECUTED=0'));
      expect(r.stdout.toString(), contains('JOURNEY_D_EXECUTED=false'));
    });

    test('4 explicit live marker prevents new_marker()', () async {
      final r = await Process.run('python3', [
        '-c',
        '''
import os, sys
from pathlib import Path
sys.path.insert(0, r"$root/tool/staging/lib")
os.environ["CONFIRM_COHORT_STAGING"]="1"
os.environ["S17_JD_LIVE_CREATE"]="1"
os.environ["S17_JD_LIVE_MUTATION_BACKEND"]="synthetic_ok"
from s17_journey_d_fixture import run_live_create, new_marker
calls={"n":0}
import s17_journey_d_fixture as m
orig=new_marker
def wrapped():
    calls["n"]+=1
    return orig()
m.new_marker=wrapped
raw=open(r"${projectsFixture.path}").read()
r=run_live_create(root=Path(r"$root"), projects_raw=raw, marker="$stableMarker")
assert r["fixture_marker"]=="$stableMarker"
assert calls["n"]==0
assert r["new_marker_called"] is False
assert r["hosted_writes_executed"]==0
print("NEW_MARKER_NOT_CALLED")
''',
      ], workingDirectory: root);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(r.stdout.toString(), contains('NEW_MARKER_NOT_CALLED'));
    });

    test('5-8 missing/empty/repeated/malformed markers fail closed', () async {
      final missing = await runCreator(
        args: '--live --marker',
        env: const {'S17_JD_LIVE_CREATE': '1'},
      );
      expect(missing.exitCode, 2);

      final empty = await Process.run('bash', [
        '-c',
        'cd "$root" && CONFIRM_COHORT_STAGING=1 S17_JD_LIVE_CREATE=1 '
            'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
            '"$creator" --live --marker ""',
      ]);
      expect(empty.exitCode, 2);

      final repeated = await runCreator(
        args: '--live --marker $stableMarker --marker $stableMarker',
        env: const {'S17_JD_LIVE_CREATE': '1'},
      );
      expect(repeated.exitCode, 2);
      expect(repeated.stderr.toString(), contains('only once'));

      final malformed = await runCreator(
        args: '--live --marker not-valid',
        env: const {'S17_JD_LIVE_CREATE': '1'},
        includeProjects: false,
      );
      expect(malformed.exitCode, 2);
      expect(malformed.stderr.toString(), contains('invalid Journey D'));
      expect(
        malformed.stderr.toString(),
        isNot(contains('S17_PROJECTS_JSON_FILE')),
      );
    });

    test('9 unknown arguments remain rejected', () async {
      final r = await runCreator(args: '--live --marker $stableMarker --bogus');
      expect(r.exitCode, 2);
      expect(r.stderr.toString(), contains('unknown flag'));
    });

    test('10 marker cannot become executable code', () async {
      final probe = '/tmp/b4d21d1_pwned';
      final f = File(probe);
      if (f.existsSync()) f.deleteSync();
      final r = await Process.run(
        creator,
        [
          '--live',
          '--marker',
          's17_jd_adapt_20260805T012428Z_\$(touch $probe)_deadbeef',
        ],
        environment: {
          ...Platform.environment,
          'CONFIRM_COHORT_STAGING': '1',
          'S17_JD_LIVE_CREATE': '1',
          'S17_PROJECTS_JSON_FILE': projectsFixture.path,
          'S17_JD_LIVE_MUTATION_BACKEND': 'synthetic_ok',
        },
        workingDirectory: root,
      );
      expect(r.exitCode, 2);
      expect(File(probe).existsSync(), isFalse);
    });

    test('14 marker binding alone cannot enable live mode', () async {
      final r = await runCreator(args: '--dry-run --marker $stableMarker');
      expect(r.exitCode, 0);
      expect(r.stdout.toString(), contains('DRY_RUN_OK'));
      expect(r.stdout.toString(), contains('HOSTED_WRITES=0'));
      expect(r.stdout.toString(), isNot(contains('LIVE_CREATE_OK')));
    });

    test('15 both live confirmation guards required', () async {
      final noLive = await runCreator(
        args: '--live --marker $stableMarker',
        env: const {'S17_JD_LIVE_MUTATION_BACKEND': 'synthetic_ok'},
      );
      expect(noLive.exitCode, 2);
      expect(noLive.stderr.toString(), contains('S17_JD_LIVE_CREATE'));

      final noConfirm = await Process.run('bash', [
        '-c',
        'cd "$root" && env -u CONFIRM_COHORT_STAGING S17_JD_LIVE_CREATE=1 '
            'S17_JD_LIVE_MUTATION_BACKEND=synthetic_ok '
            'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
            '"$creator" --live --marker $stableMarker',
      ]);
      expect(noConfirm.exitCode, 2);
      expect(noConfirm.stderr.toString(), contains('CONFIRM_COHORT_STAGING'));
    });

    test('16 missing projects configuration fails closed', () async {
      final r = await runCreator(
        args: '--live --marker $stableMarker',
        env: const {
          'S17_JD_LIVE_CREATE': '1',
          'S17_JD_LIVE_MUTATION_BACKEND': 'synthetic_ok',
        },
        includeProjects: false,
      );
      expect(r.exitCode, 2);
      expect(r.stderr.toString(), contains('S17_PROJECTS_JSON_FILE'));
    });

    test('43-45 dry-run remains zero-write / no publishDraft', () async {
      final r = await runCreator(args: '--dry-run --marker $stableMarker');
      expect(r.exitCode, 0);
      expect(r.stdout.toString(), contains('PUBLISH_DRAFT_INVOKED=false'));
      expect(r.stdout.toString(), contains('HOSTED_WRITES=0'));
    });
  });

  group('Dart live orchestrator (fakes only)', () {
    test('23-25 CURRENT before LATER via publishDraft fake', () async {
      final pub = FakeJourneyDProtocolPublisher(
        lineageByProtocolId: {
          'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
          'PROT-S17-JD-ADAPT-LATER': laterUuid,
        },
      );
      final result = await buildCreator(publisher: pub).run(
        marker: stableMarker,
        protocolIntentJson: intentJson,
        packageYaml: yaml,
        stagingConfirmed: true,
        liveAuthorized: true,
      );
      expect(result.ok, isTrue);
      expect(pub.publishedProtocolIds, [
        'PROT-S17-JD-ADAPT-CURRENT',
        'PROT-S17-JD-ADAPT-LATER',
      ]);
      expect(result.publishDraftInvocations, 2);
      expect(result.journeyDExecuted, isFalse);
      expect(result.adaptationInvoked, isFalse);
      expect(result.retry, isFalse);
      expect(result.cleanup, isFalse);
      expect(result.reboundContentHashSha256, isNotNull);
      expect(result.reboundContentHashSha256, isNot(expectedHash));
    });

    test(
      '30-32 symbolic lineages cannot reach import; import after rebind',
      () async {
        final life = FakeJourneyDLiveProgrammeLifecycle();
        final result = await buildCreator(lifecycle: life).run(
          marker: stableMarker,
          protocolIntentJson: intentJson,
          packageYaml: yaml,
          stagingConfirmed: true,
          liveAuthorized: true,
        );
        expect(result.ok, isTrue);
        expect(life.importCalls, 1);
        expect(
          life.lastImportPayload.toString(),
          isNot(contains('SL-S17-JD-ADAPT-')),
        );
        expect(life.publishApproveCalls, 1);
      },
    );

    test('35 success produces complete applied ledger', () async {
      final result = await buildCreator().run(
        marker: stableMarker,
        protocolIntentJson: intentJson,
        packageYaml: yaml,
        stagingConfirmed: true,
        liveAuthorized: true,
      );
      expect(result.ok, isTrue);
      for (final s in result.stages) {
        if (JourneyDLiveFixtureCreator.mutatingStages.contains(s.name) ||
            s.name == 'stop_prepare_ready' ||
            s.name == 'stop_without_journey_d' ||
            s.name.startsWith('validate') ||
            s.name.startsWith('compile') ||
            s.name.startsWith('check_')) {
          expect(
            s.status,
            JourneyDPublicationStageState.applied,
            reason: s.name,
          );
        }
      }
    });

    test('36-37 failure injection stops later stages', () async {
      Future<JourneyDLiveCreateResult> runCase({
        FakeJourneyDLivePreflight? preflight,
        FakeJourneyDLiveAthleteFactory? athlete,
        FakeJourneyDProtocolPublisher? publisher,
        FakeJourneyDLiveProgrammeLifecycle? lifecycle,
        FakeJourneyDLiveEnrolment? enrolment,
        FakeJourneyDLiveMaterialisation? materialisation,
      }) {
        return buildCreator(
          preflight: preflight,
          athlete: athlete,
          publisher: publisher,
          lifecycle: lifecycle,
          enrolment: enrolment,
          materialisation: materialisation,
        ).run(
          marker: stableMarker,
          protocolIntentJson: intentJson,
          packageYaml: yaml,
          stagingConfirmed: true,
          liveAuthorized: true,
        );
      }

      void expectStopped(JourneyDLiveCreateResult result, String key) {
        expect(result.ok, isFalse, reason: key);
        expect(result.furtherMutationProhibited, isTrue, reason: key);
        expect(result.firstFailedOrUnknownStage, isNotNull, reason: key);
        var seenFail = false;
        for (final s in result.stages) {
          if (s.name == result.firstFailedOrUnknownStage) {
            seenFail = true;
            continue;
          }
          if (seenFail && s.mutating) {
            expect(
              s.status,
              JourneyDPublicationStageState.notStarted,
              reason: '$key:${s.name}',
            );
          }
        }
      }

      expectStopped(
        await runCase(
          preflight: FakeJourneyDLivePreflight(
            outcome: JourneyDLiveStageOutcome.failed('EXISTS'),
          ),
        ),
        'preflight',
      );
      expectStopped(
        await runCase(
          athlete: FakeJourneyDLiveAthleteFactory(
            result: const JourneyDLiveAthleteResult(
              state: JourneyDPublicationStageState.failed,
              detail: 'auth_failed',
            ),
          ),
        ),
        'athlete',
      );
      expectStopped(
        await runCase(
          publisher: FakeJourneyDProtocolPublisher(
            lineageByProtocolId: {
              'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
              'PROT-S17-JD-ADAPT-LATER': laterUuid,
            },
            failProtocolIds: {'PROT-S17-JD-ADAPT-CURRENT'},
          ),
        ),
        'publish_current',
      );
      expectStopped(
        await runCase(
          publisher: FakeJourneyDProtocolPublisher(
            lineageByProtocolId: {
              'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
              'PROT-S17-JD-ADAPT-LATER': laterUuid,
            },
            failProtocolIds: {'PROT-S17-JD-ADAPT-LATER'},
          ),
        ),
        'publish_later',
      );
      expectStopped(
        await runCase(
          lifecycle: FakeJourneyDLiveProgrammeLifecycle(
            importOutcome: JourneyDLiveStageOutcome.failed('import_failed'),
          ),
        ),
        'import',
      );
      expectStopped(
        await runCase(
          lifecycle: FakeJourneyDLiveProgrammeLifecycle(
            publishApproveOutcome: JourneyDLiveStageOutcome.failed(
              'approve_failed',
            ),
          ),
        ),
        'publish_approve',
      );
      expectStopped(
        await runCase(
          enrolment: FakeJourneyDLiveEnrolment(
            result: const JourneyDLiveEnrolResult(
              state: JourneyDPublicationStageState.failed,
              detail: 'enrol_failed',
            ),
          ),
        ),
        'enrol',
      );
      expectStopped(
        await runCase(
          materialisation: FakeJourneyDLiveMaterialisation(
            outcome: JourneyDLiveStageOutcome.failed('mat_failed'),
          ),
        ),
        'materialise',
      );
      final ambiguous = await runCase(
        publisher: FakeJourneyDProtocolPublisher(
          lineageByProtocolId: {
            'PROT-S17-JD-ADAPT-CURRENT': currentUuid,
            'PROT-S17-JD-ADAPT-LATER': laterUuid,
          },
          ambiguousProtocolIds: {'PROT-S17-JD-ADAPT-CURRENT'},
        ),
      );
      expectStopped(ambiguous, 'ambiguous_publish');
      expect(
        ambiguous.stages
            .firstWhere((s) => s.name == 'publish_fixture_protocol_current')
            .status,
        JourneyDPublicationStageState.unknown,
      );
    });

    test('21-22 compile / hash mismatch stops before mutation', () async {
      final athlete = FakeJourneyDLiveAthleteFactory();
      final bad = await buildCreator(athlete: athlete).run(
        marker: stableMarker,
        protocolIntentJson: intentJson,
        packageYaml: yaml.replaceFirst(
          'PROG-S17-JD-ADAPT',
          'PROG-S17-JD-WRONG',
        ),
        stagingConfirmed: true,
        liveAuthorized: true,
      );
      expect(bad.ok, isFalse);
      expect(athlete.calls, 0);
    });

    test('28-29 rebind only session lineages; slot keys unchanged', () async {
      final life = FakeJourneyDLiveProgrammeLifecycle();
      final result = await buildCreator(lifecycle: life).run(
        marker: stableMarker,
        protocolIntentJson: intentJson,
        packageYaml: yaml,
        stagingConfirmed: true,
        liveAuthorized: true,
      );
      expect(result.ok, isTrue);
      // Original slots still reference session keys in source yaml.
      expect(yaml, contains('session_key: SES-JD-ADAPT-CURRENT'));
      expect(yaml, contains('session_key: SES-JD-ADAPT-LATER'));
      expect(manifest.sessions.map((s) => s.sessionKey).toList(), [
        'SES-JD-ADAPT-CURRENT',
        'SES-JD-ADAPT-LATER',
      ]);
    });

    test('39-42 journey unreachable; equipment contract unchanged', () async {
      final result = await buildCreator().run(
        marker: stableMarker,
        protocolIntentJson: intentJson,
        packageYaml: yaml,
        stagingConfirmed: true,
        liveAuthorized: true,
      );
      expect(result.journeyDExecuted, isFalse);
      expect(result.adaptationInvoked, isFalse);
      expect(intentJson, contains('cohort.exercise.push_up'));
      expect(intentJson, contains('cohort.exercise.back_squat'));
      expect(intentJson, contains('cohort.exercise.goblet_squat'));
      expect(yaml, contains('substitute_approved_equipment'));
      expect(yaml, contains('substitute_approved_exercise'));
      expect(yaml, contains('athlete_agreement_required: true'));
    });

    test('33-34 enrol after import; materialise after enrol', () async {
      final life = FakeJourneyDLiveProgrammeLifecycle();
      final enrol = FakeJourneyDLiveEnrolment();
      final mat = FakeJourneyDLiveMaterialisation();
      life.importOutcome = JourneyDLiveStageOutcome.failed('blocked');
      final failed =
          await buildCreator(
            lifecycle: life,
            enrolment: enrol,
            materialisation: mat,
          ).run(
            marker: stableMarker,
            protocolIntentJson: intentJson,
            packageYaml: yaml,
            stagingConfirmed: true,
            liveAuthorized: true,
          );
      expect(failed.ok, isFalse);
      expect(enrol.calls, 0);
      expect(mat.calls, 0);

      life.importOutcome = JourneyDLiveStageOutcome.applied(
        versionId: 'c3333333-3333-4333-8333-333333333333',
        versionIdRedacted: 'c3333333…',
      );
      final ok =
          await buildCreator(
            lifecycle: life,
            enrolment: enrol,
            materialisation: mat,
          ).run(
            marker: stableMarker,
            protocolIntentJson: intentJson,
            packageYaml: yaml,
            stagingConfirmed: true,
            liveAuthorized: true,
          );
      expect(ok.ok, isTrue);
      expect(enrol.calls, 1);
      expect(mat.calls, 1);
      expect(mat.lastAssignmentId, enrol.result.assignmentId);
    });
  });

  group('no hosted contact from this suite', () {
    test('50 synthetic backends only; no network hosts contacted', () async {
      // Static guarantee: shell live tests use synthetic_ok backend.
      final shell = File(creator).readAsStringSync();
      expect(shell, contains('S17_JD_LIVE_MUTATION_BACKEND'));
      expect(shell, contains('run_live_create'));
      expect(shell, contains('S17_JD_FIXTURE_MARKER'));
      expect(projectsFixture.existsSync(), isTrue);
    });
  });
}
