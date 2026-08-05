import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_session_authoring_test_support.dart';

/// B4d.20 Journey D adaptation fixture creator — local tooling only.
/// Uses fakes / offline projects list. Never contacts hosted environments.
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
  final diagnose =
      '$root/tool/staging/diagnose_s17_journey_d_adaptation_readonly.sh';

  Future<ProcessResult> runPython(String body) {
    return Process.run('python3', [
      '-c',
      "import sys, json, os\n"
          "sys.path.insert(0, r'$root/tool/staging/lib')\n"
          'from s17_journey_d_fixture import *\n'
          'from s17_staging_guard import *\n'
          'os.environ["CONFIRM_COHORT_STAGING"]="1"\n'
          '$body',
    ], workingDirectory: root);
  }

  Future<ProcessResult> runCreator({
    required String modeFlag,
    Map<String, String> env = const {},
    bool includeProjectsFile = true,
  }) {
    final extraEnv = env.entries.map((e) => '${e.key}=${e.value}').join(' ');
    if (includeProjectsFile) {
      return Process.run('bash', [
        '-c',
        'cd "$root" && CONFIRM_COHORT_STAGING=1 '
            'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
            '$extraEnv "$creator" $modeFlag',
      ]);
    }
    return Process.run('bash', [
      '-c',
      'cd "$root" && env -u S17_PROJECTS_JSON_FILE '
          'CONFIRM_COHORT_STAGING=1 $extraEnv "$creator" $modeFlag',
    ]);
  }

  group('B4d.20 environment guards (fakes only)', () {
    test('1 allowlist succeeds with fixture projects list', () async {
      expect(projectsFixture.existsSync(), isTrue);
      final result = await runPython('''
projects=parse_projects_json(open(r"${projectsFixture.path}").read())
selected=select_staging_project(projects)
assert selected["name"]=="Cohort Staging"
assert selected["ref"].startswith("tsbadngz")
assert selected["region"]=="eu-west-2"
print("ALLOWLIST_OK")
''');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('ALLOWLIST_OK'));
    });

    test('2 production project ID is rejected', () async {
      final result = await runPython(r'''
try:
    select_staging_project([{
        "name":"Cohort Field Manual",
        "ref":"otnhhdxstdnwccehacku",
        "region":"eu-west-1",
        "status":"ACTIVE_HEALTHY",
        "linked":True,
    }])
    raise SystemExit("should_refuse")
except StagingGuardError as e:
    assert "REFUSED" in str(e)
    print("PROD_ID_REFUSED")
''');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('PROD_ID_REFUSED'));
    });

    test('3 production project name is rejected', () async {
      final result = await runPython(r'''
assert classify_project({
    "name":"Cohort Field Manual",
    "ref":"zzzzzzzzzzzzzzzzzzzz",
    "region":"eu-west-2",
    "status":"ACTIVE_HEALTHY",
})=="production"
print("PROD_NAME_REFUSED")
''');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('PROD_NAME_REFUSED'));
    });

    test('4 missing target is rejected', () async {
      final result = await runCreator(
        modeFlag: '--dry-run',
        includeProjectsFile: false,
      );
      expect(result.exitCode, 2);
      expect(result.stderr.toString(), contains('S17_PROJECTS_JSON_FILE'));
    });

    test('5 ambiguous/conflicting target configuration is rejected', () async {
      final result = await runPython(r'''
try:
    select_staging_project([
        {"name":"Cohort Staging","ref":"tsbadngzgvsyfqjupkng","region":"eu-west-2","status":"ACTIVE_HEALTHY"},
        {"name":"Cohort Staging","ref":"tsbadngzAAAAAAAAAAAAAAAA","region":"eu-west-2","status":"ACTIVE_HEALTHY"},
        {"name":"Cohort Field Manual","ref":"otnhhdxstdnwccehacku","region":"eu-west-1","status":"ACTIVE_HEALTHY"},
    ])
    raise SystemExit("should_refuse")
except StagingGuardError as e:
    assert "exactly one" in str(e).lower() or "REFUSED" in str(e)
    print("AMBIGUOUS_REFUSED")
''');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('AMBIGUOUS_REFUSED'));
    });
  });

  group('B4d.20 dry-run / live separation', () {
    test('6 dry-run performs zero writes', () async {
      final result = await runCreator(modeFlag: '--dry-run');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final out = '${result.stdout}\n${result.stderr}';
      expect(out, contains('DRY_RUN_OK'));
      expect(out, contains('HOSTED_WRITES=0'));
      expect(out, contains('JOURNEY_D_EXECUTION=disabled'));
      expect(out, isNot(contains('ATHLETE_CREATED')));
      expect(out, isNot(contains('import_authored_plan_package')));
    });

    test('7 live mode requires separate explicit flag', () async {
      final result = await runCreator(modeFlag: '--live');
      expect(result.exitCode, 2);
      final err = result.stderr.toString();
      expect(err, contains('S17_JD_LIVE_CREATE'));
    });

    test('7b live with flag still refuses hosted mutation in B4d.20', () async {
      final result = await runCreator(
        modeFlag: '--live',
        env: const {'S17_JD_LIVE_CREATE': '1'},
      );
      expect(result.exitCode, 2);
      expect(result.stderr.toString(), contains('B4d.20'));
      expect(result.stderr.toString(), contains('separately authorised'));
    });
  });

  group('B4d.20 marker and reserved identities', () {
    test('8 existing fixture marker fails before writing', () async {
      final result = await runPython('''
from pathlib import Path
raw=open(r"${projectsFixture.path}").read()
try:
    run_dry_run(
        root=Path(r"$root"),
        projects_raw=raw,
        marker="s17_jd_adapt_20260804T120000Z_deadbeef",
        existing_markers={"s17_jd_adapt_20260804T120000Z_deadbeef"},
    )
    raise SystemExit("should_refuse")
except StagingGuardError as e:
    assert "already exists" in str(e)
    print("MARKER_EXISTS_REFUSED")
''');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('MARKER_EXISTS_REFUSED'));
    });

    test(
      '9 reserved Athlete C/D and S15A/S13 identities are rejected',
      () async {
        final result = await runPython(r'''
for value in [
    "PROG-S15A-STAGING",
    "PROG-S13-ELIG",
    "Athlete C",
    "Athlete D",
    "s17_stage_20260803T065749Z_55ec68c6",
    "e9bd7e19-6eb9-4f7e-abf6-d08ac4368748",
]:
    try:
        if value.startswith("s17_stage_"):
            validate_marker(value)
        else:
            reject_reserved_identity(value)
        raise SystemExit(f"should_refuse:{value}")
    except StagingGuardError:
        pass
print("RESERVED_REFUSED")
''');
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout.toString(), contains('RESERVED_REFUSED'));
      },
    );

    test('10 exactly one athlete and one dedicated fixture planned', () async {
      final result = await runCreator(modeFlag: '--dry-run');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('"athletes_targeted":1'));
      expect(result.stdout.toString(), contains('"programmes_targeted":1'));
      expect(
        result.stdout.toString(),
        contains('REBIND_PATH=REBIND_PATH_READY'),
      );
      final py = await runPython('''
from pathlib import Path
raw=open(r"${projectsFixture.path}").read()
r=run_dry_run(root=Path(r"$root"), projects_raw=raw)
m=r["manifest"]
assert m["targets"]["synthetic_athletes"]==1
assert m["targets"]["dedicated_programmes"]==1
assert m["targets"]["reserved_athlete_c"] is False
assert m["targets"]["reserved_athlete_d"] is False
assert m["targets"]["reserved_s15a"] is False
assert m["targets"]["reserved_s13"] is False
assert m["lineage_code"]=="PROG-S17-JD-ADAPT"
print("SINGLE_TARGET_OK")
''');
      expect(py.exitCode, 0, reason: '${py.stdout}\n${py.stderr}');
      expect(py.stdout.toString(), contains('SINGLE_TARGET_OK'));
    });
  });

  group('B4d.20 package compile and B4d.19 contract', () {
    late PlanPackageCompileResult compileResult;
    late Map<String, dynamic> intent;
    late InMemoryKnowledgeGraphReader knowledge;

    setUpAll(() async {
      expect(packageYaml.existsSync(), isTrue);
      expect(protocolIntent.existsSync(), isTrue);
      compileResult = const PlanPackageCompiler().compile(
        packageYaml.readAsStringSync(),
      );
      intent =
          jsonDecode(protocolIntent.readAsStringSync()) as Map<String, dynamic>;
      final knowledgeRoot = _findKnowledgeRoot(Directory.current);
      final bundle = await const YamlKnowledgeOntologyLoader()
          .loadFromDirectory(knowledgeRoot);
      knowledge = InMemoryKnowledgeGraphReader(bundle);
    });

    test('11 package compiles, validates, canonicalises, and hashes', () {
      expect(
        compileResult.isValid,
        isTrue,
        reason: compileResult.issues.toString(),
      );
      expect(compileResult.manifest, isNotNull);
      expect(compileResult.contentHashSha256, isNotNull);
      expect(compileResult.contentHashSha256!.length, 64);
      expect(compileResult.canonicalJson, isNotNull);
    });

    test('12 package is unpublished and fixture-only', () {
      final m = compileResult.manifest!;
      expect(m.programme.lineageCode, 'PROG-S17-JD-ADAPT');
      expect(m.programme.name, contains('Journey D'));
      expect(m.programme.lineageCode, isNot(contains('S15A')));
      expect(m.programme.lineageCode, isNot(contains('S13')));
      // Import creates draft; publication is a later staging-only stage.
      expect(packageYaml.readAsStringSync(), contains('Staging-only'));
    });

    test('13 package contains at least two ordered executable occurrences', () {
      final slots = [
        for (final w in compileResult.manifest!.weeks)
          for (final d in w.days)
            for (final s in d.slots) s.slotKey,
      ];
      expect(slots, containsAll(['W1D1S1', 'W1D2S1']));
      expect(compileResult.manifest!.sessions.length, greaterThanOrEqualTo(2));
    });

    test(
      '14 current occurrence contains exact canonical back_squat conflict',
      () {
        final current = intent['current_protocol'] as Map<String, dynamic>;
        expect(
          current['exercise_id'],
          JourneyDEquipmentAdaptationContract.sourceExerciseId,
        );
        expect(
          current['replacement_exercise_id'],
          JourneyDEquipmentAdaptationContract.replacementExerciseId,
        );
        expect(
          current['substitution_rule_id'],
          JourneyDEquipmentAdaptationContract.substitutionRuleId,
        );
        final omitted = (intent['omitted_required_equipment'] as List)
            .cast<String>();
        expect(
          omitted,
          containsAll(
            JourneyDEquipmentAdaptationContract.omittedRequiredEquipment,
          ),
        );
      },
    );

    test('15 available-equipment set matches Journey D harness contract', () {
      final available = (intent['available_equipment'] as List)
          .cast<String>()
          .toSet();
      expect(available, JourneyDEquipmentAdaptationContract.availableEquipment);
    });

    test('16 KnowledgeGraphReader resolves back_squat → goblet_squat', () {
      final rules = knowledge.substitutionsForSource(
        JourneyDEquipmentAdaptationContract.sourceExerciseId,
      );
      expect(
        rules.any(
          (r) =>
              r.id == JourneyDEquipmentAdaptationContract.substitutionRuleId &&
              r.candidateExerciseId ==
                  JourneyDEquipmentAdaptationContract.replacementExerciseId,
        ),
        isTrue,
        reason: 'rules=${rules.map((r) => r.id).toList()}',
      );
    });

    test('17 planner produces expected curated swapExercise', () {
      final draft = _fixtureCurrentDraft();
      final session = PlannedSessionAdaptationInputAdapter.fromProtocolDraft(
        draft,
      );
      final plan = SessionAdaptationPlanner(knowledge: knowledge).plan(
        session: session,
        constraints: AdaptationConstraintContext(
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
      );
      expect(plan.status, AdaptationPlanStatus.planGenerated);
      expect(
        plan.steps.any(
          (s) =>
              s.actionType == AdaptationActionType.swapExercise &&
              s.originalValueReference ==
                  JourneyDEquipmentAdaptationContract.sourceExerciseId &&
              s.proposedValueReference ==
                  JourneyDEquipmentAdaptationContract.replacementExerciseId,
        ),
        isTrue,
        reason:
            'steps=${plan.steps.map((s) => '${s.actionType}:${s.originalValueReference}->${s.proposedValueReference}').toList()}',
      );
    });

    test('18 mapper produces acceptable reviewable proposal locally', () async {
      final draft = _fixtureCurrentDraft();
      final proposal =
          await ProgrammeAdaptationProposalService(
            knowledge: knowledge,
            loadProtocolDraft: (_) async => draft,
            loadAdaptationPermissions: (_) async =>
                compileResult.manifest!.adaptationPermissions,
          ).propose(
            package: _packageFromDraft(draft),
            request: const AdaptationRequest(
              reason: AdaptationReason.equipment,
              availableEquipment:
                  JourneyDEquipmentAdaptationContract.availableEquipment,
            ),
          );
      expect(proposal.outcome, ProgrammeAdaptationProposalOutcome.reviewable);
      expect(proposal.isAcceptable, isTrue);
      expect(
        compileResult.manifest!.adaptationPermissions.every(
          (p) => p.athleteAgreementRequired,
        ),
        isTrue,
      );
    });

    test('19 no name-based or fallback substitution is used', () {
      expect(
        JourneyDEquipmentAdaptationContract.substitutionRuleId,
        'cohort.substitution.back_squat_to_goblet_squat',
      );
      expect(
        protocolIntent.readAsStringSync(),
        contains('cohort.substitution.back_squat_to_goblet_squat'),
      );
      expect(protocolIntent.readAsStringSync(), isNot(contains('fallback')));
      expect(protocolIntent.readAsStringSync(), isNot(contains('by_name')));
    });

    test('20 permissions are non-empty', () {
      expect(compileResult.manifest!.adaptationPermissions, isNotEmpty);
    });

    test('21 every permission requires athlete agreement', () {
      for (final p in compileResult.manifest!.adaptationPermissions) {
        expect(p.athleteAgreementRequired, isTrue, reason: p.id);
      }
    });

    test('22 every permission change kind passes AdaptationPolicyGate', () {
      for (final p in compileResult.manifest!.adaptationPermissions) {
        expect(AdaptationPolicyGate.allowed.contains(p.changeKind), isTrue);
      }
    });

    test('23 package grants no unnecessary adaptation capability', () {
      final kinds = compileResult.manifest!.adaptationPermissions
          .map((p) => p.changeKind)
          .toSet();
      final equipmentKinds = AdaptationPolicyGate.kindsForDayOf(
        AdaptationReason.equipment,
      ).toSet();
      expect(kinds.difference(equipmentKinds), isEmpty);
      expect(
        kinds.contains(AdaptationChangeKind.substituteApprovedEquipment),
        isTrue,
      );
      expect(kinds.contains(AdaptationChangeKind.rewritePlan), isFalse);
      expect(kinds.contains(AdaptationChangeKind.compressForTime), isFalse);
    });

    test('24 later unaffected baseline occurrence exists', () {
      final later = intent['later_protocol'] as Map<String, dynamic>;
      expect(later['role'], 'unaffected_occurrence_baseline');
      expect(later['exercise_id'], 'cohort.exercise.push_up');
      expect(
        compileResult.manifest!.sessions.any(
          (s) => s.protocolId == later['protocol_id'],
        ),
        isTrue,
      );
    });

    test('25 accepted adaptation is absent initially', () {
      final draft = _fixtureCurrentDraft();
      final package = _packageFromDraft(draft);
      expect(package.acceptedAdaptation, isNull);
    });

    test('26 proposal-consumed state is false initially', () {
      final draft = _fixtureCurrentDraft();
      final package = _packageFromDraft(draft);
      expect(package.acceptedAdaptation, isNull);
      // Creator contract: no consumed proposal at prepare-ready stop.
      expect(intent.containsKey('consumed_proposal'), isFalse);
    });
  });

  group('B4d.20 ledger, failure, verifier, journey isolation', () {
    test('27 creation order is deterministic', () async {
      final result = await runPython(r'''
assert STAGE_ORDER == [
    "validate_environment",
    "validate_inputs_and_marker",
    "compile_validate_package_local",
    "resolve_substitution_local",
    "emit_intended_write_manifest",
    "check_marker_uniqueness_readonly",
    "create_synthetic_athlete",
    "publish_fixture_protocol_current",
    "publish_fixture_protocol_later",
    "rebind_validate_package_for_import",
    "import_programme_version_and_permissions",
    "publish_approve_staging_fixture_version",
    "enrol_assignment",
    "materialise_schedule",
    "stop_prepare_ready",
    "post_create_readonly_eligibility",
    "stop_without_journey_d",
]
assert REBIND_PATH_STATUS == "REBIND_PATH_READY"
print("ORDER_OK")
''');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('ORDER_OK'));
    });

    test('28 failed stage prevents every later stage', () async {
      final result = await runPython(r'''
ledger=build_empty_ledger("s17_jd_adapt_20260804T120000Z_aabbccdd", "live", False)
fail_closed(ledger, "create_synthetic_athlete", "simulated_failure")
assert ledger.further_mutation_prohibited is True
seen=False
for s in ledger.stages:
    if s.name=="create_synthetic_athlete":
        assert s.status=="failed"
        seen=True
        continue
    if seen:
        assert s.status=="not_started"
        assert "blocked_by_prior_failure" in s.detail
print("FAIL_CLOSED_OK")
''');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('FAIL_CLOSED_OK'));
    });

    test(
      '29 ambiguous result produces unknown ledger state and stops',
      () async {
        final result = await runPython(r'''
ledger=build_empty_ledger("s17_jd_adapt_20260804T120000Z_aabbccdd", "live", False)
ambiguous_stop(ledger, "import_programme_version_and_permissions", "timeout")
assert ledger.further_mutation_prohibited is True
for s in ledger.stages:
    if s.name=="import_programme_version_and_permissions":
        assert s.status=="unknown"
print("AMBIGUOUS_OK")
''');
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout.toString(), contains('AMBIGUOUS_OK'));
      },
    );

    test(
      '30 no retry, compensation, deletion, repair, or resume pathway',
      () async {
        final result = await runPython('''
from pathlib import Path
raw=open(r"${projectsFixture.path}").read()
r=run_dry_run(root=Path(r"$root"), projects_raw=raw)
m=r["manifest"]
assert m["retry"] is False
assert m["compensation"] is False
assert m["deletion"] is False
assert m["repair"] is False
assert m["resume"] is False
assert m["automatic_retry"] is False
assert m["cleanup"] is False
src=open(r"$root/tool/staging/lib/s17_journey_d_fixture.py").read()
assert "def resume" not in src
assert "def retry" not in src
assert "def cleanup" not in src
assert "def delete" not in src
print("NO_REPAIR_OK")
''');
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        expect(result.stdout.toString(), contains('NO_REPAIR_OK'));
      },
    );

    test('31 post-create verification is fixture-scoped and read-only', () async {
      final result = await Process.run('bash', [
        '-c',
        'cd "$root" && "$diagnose" s17_jd_adapt_20260804T120000Z_aabbccdd --local-contract',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      final out = result.stdout.toString();
      expect(out, contains('JD_READONLY_LOCAL_CONTRACT_OK'));
      expect(out, contains('"mutation": false'));
      expect(out, contains('"propose_reject_accept": false'));
      expect(out, contains('"journey_execution": false'));
      final hosted = await Process.run('bash', [
        '-c',
        'cd "$root" && "$diagnose" s17_jd_adapt_20260804T120000Z_aabbccdd --hosted',
      ]);
      expect(hosted.exitCode, 2);
      expect(hosted.stderr.toString(), contains('not authorised'));
    });

    test(
      '32 Journey execution is unreachable from creator and verifier',
      () async {
        final result = await runPython(r'''
src=open("tool/staging/lib/s17_journey_d_fixture.py").read()
assert "journey_execution_reachable" in src
assert "JOURNEY_D" in open("tool/staging/create_s17_journey_d_adaptation_fixture.sh").read()
shell=open("tool/staging/create_s17_journey_d_adaptation_fixture.sh").read()
assert "run_s17_flutter_staging_verify" not in shell
assert "main_s17_staging_verify" not in shell
diag=open("tool/staging/diagnose_s17_journey_d_adaptation_readonly.sh").read()
assert "Journey D" in diag or "journey" in diag.lower()
assert "propose" not in diag.lower() or "propose_reject_accept" in open("tool/staging/diagnose_s17_journey_d_adaptation_readonly.sh").read()
print("JOURNEY_UNREACHABLE_OK")
''');
        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        final dry = await runCreator(modeFlag: '--dry-run');
        expect(dry.stdout.toString(), contains('JOURNEY_D_EXECUTION=disabled'));
        expect(dry.stdout.toString(), contains('"journeys_enabled":0'));
      },
    );

    test('33 dry-run manifest and logs redact private identifiers', () async {
      final result = await runPython('''
from pathlib import Path
raw=open(r"${projectsFixture.path}").read()
r=run_dry_run(root=Path(r"$root"), projects_raw=raw)
blob=json.dumps(r)
assert "@example.invalid" in r["manifest"]["email_redacted"]
assert "…" in r["manifest"]["email_redacted"] or "..." in r["manifest"]["email_redacted"]
assert "otnhhdxstdnwccehacku" not in blob
assert r["manifest"]["staging"]["ref_prefix"].endswith("…") or "…" in r["manifest"]["staging"]["ref_prefix"]
print("REDACTION_OK")
''');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect(result.stdout.toString(), contains('REDACTION_OK'));
    });

    test('34 existing creator behavior remains unchanged', () async {
      final athleteD = await Process.run('bash', [
        '-c',
        'cd "$root" && CONFIRM_COHORT_STAGING=1 '
            'S17_PROJECTS_JSON_FILE="${projectsFixture.path}" '
            './tool/staging/create_s17_athlete_d_fixture.sh --dry-run',
      ]);
      expect(
        athleteD.exitCode,
        0,
        reason: '${athleteD.stdout}\n${athleteD.stderr}',
      );
      expect(athleteD.stdout.toString(), contains('DRY_RUN_OK'));
      expect(athleteD.stdout.toString(), contains('Athlete D not created'));
    });
  });
}

ProtocolDraft _fixtureCurrentDraft() {
  return programmeSession(
    protocolId: 'PROT-S17-JD-ADAPT-CURRENT',
    name: 'Journey D Current Equipment Session',
    programmeVersionId: testProgrammeVersionId,
    ownerId: 'dev-coach',
    durationMin: 45,
    primarySessionIntent: SessionIntent.lowerBodyStrength,
    minimumViableDurationMin: 25,
    blocks: [
      block(
        localId: 'block-strength',
        type: SessionBlockType.strength,
        position: 1,
        title: 'Main',
        blockPriority: BlockPriority.essential,
        adaptationPolicy: const BlockAdaptationPolicy(
          canRemove: false,
          canShorten: false,
          canReduceVolume: true,
          canReduceIntensity: true,
          canIncreaseRest: true,
          canSuperset: false,
          canReplaceExercises: true,
          canReplaceBlock: false,
          minimumViablePrescription: MinimumViablePrescription(sets: 2),
        ),
        linkedExercises: [
          SessionBlockExerciseLink(
            localId: 'link-strength-1',
            exerciseId: JourneyDEquipmentAdaptationContract.sourceExerciseId,
            position: 1,
            prescription: StrengthExercisePrescription(
              sets: 3,
              reps: StrengthRepPrescription.exact(5),
              restSeconds: 120,
            ),
          ),
        ],
      ),
    ],
  );
}

PreparedExecutionPackage _packageFromDraft(ProtocolDraft draft) {
  final key = ProgrammedSessionKey(
    planId: 'lineage.jd.adapt',
    planVersion: 'version.jd.adapt',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
    programmeAssignmentId: 'assignment.jd.adapt',
    packageContentHash: 'hash.jd.adapt',
  );

  final plan = SessionExecutionPlan(
    sessionId: draft.protocolId,
    sessionTitle: draft.name,
    durationMin: draft.durationMin,
    blocks: draft.blocks
        .map(
          (b) => SessionExecutionBlock.fromSessionBlock(
            b,
            exercisesById: const {},
          ),
        )
        .toList(growable: false),
  );

  return PreparedExecutionPackage(
    programmedSessionKey: key,
    plan: plan,
    brief: WorkoutSessionBrief(
      sessionName: draft.name,
      estimatedDurationMinutes: draft.durationMin,
    ),
    preparedAt: DateTime.utc(2026, 8, 4),
    assignmentId: 'assignment.jd.adapt',
    programmeVersionId: testProgrammeVersionId,
    packageContentHash: 'hash.jd.adapt',
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
  );
}

String _findKnowledgeRoot(Directory start) {
  var dir = start;
  for (var i = 0; i < 8; i++) {
    final candidate = Directory('${dir.path}/knowledge/reference');
    if (candidate.existsSync()) return '${dir.path}/knowledge';
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  throw StateError('knowledge root not found from ${start.path}');
}
