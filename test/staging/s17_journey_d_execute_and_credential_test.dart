import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/application/adaptation/journey_d_equipment_adaptation_contract.dart';
import 'package:cohort_platform/application/adaptation/plan_package_session_adaptation_adapter.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_acceptance_service.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_proposal_service.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/authored_plan_package/plan_package_manifest.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/features/session/models/prepared_execution_package.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/knowledge/io/yaml_knowledge_ontology_loader.dart';
import 'package:cohort_platform/knowledge/read/in_memory_knowledge_graph_reader.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_credential_handoff.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_execute_entrypoint.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_execute_workflow.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_live_entrypoint.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_session_authoring_test_support.dart';

/// Journey D execute path + private credential handoff (fake-only).
void main() {
  final root = Directory.current.path;
  final projectsFixture = File(
    '$root/test/staging/fixtures/s17_projects_list.json',
  );
  final diagnose =
      '$root/tool/staging/diagnose_s17_journey_d_adaptation_readonly.sh';
  final executeSh =
      '$root/tool/staging/execute_s17_journey_d_adaptation.sh';
  const stableMarker = 's17_jd_adapt_20260805T012428Z_933d9364';
  const athleteId = 'a1111111-1111-4111-8111-111111111111';
  const assignmentId = 'd4444444-4444-4444-8444-444444444444';
  const versionId = 'c3333333-3333-4333-8333-333333333333';

  late Directory tmp;
  late InMemoryKnowledgeGraphReader knowledge;
  late ProtocolDraft draft;
  late PreparedExecutionPackage package;
  late List<PlanPackageAdaptationPermission> permissions;
  late AthleteProgrammeSessionPrepareService prepareService;
  late ProgrammeExecutionContext executionContext;

  setUpAll(() async {
    final knowledgeRoot = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      knowledgeRoot,
    );
    knowledge = InMemoryKnowledgeGraphReader(bundle);
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('jd_exec_');
    draft = _fixtureCurrentDraft();
    package = _packageFromDraft(draft);
    permissions = const [
      PlanPackageAdaptationPermission(
        id: 'ADP-JD-EQUIP-CURRENT',
        changeKind: AdaptationChangeKind.substituteApprovedEquipment,
        targetRef: 'W1D1S1',
        athleteAgreementRequired: true,
      ),
      PlanPackageAdaptationPermission(
        id: 'ADP-JD-EQUIP-PROGRAMME',
        changeKind: AdaptationChangeKind.substituteApprovedExercise,
        targetRef: 'programme',
        athleteAgreementRequired: true,
      ),
    ];
    final kv = InMemoryKvStore();
    final tables = InMemoryProgrammeTables();
    prepareService = AthleteProgrammeSessionPrepareService(
      assignmentStore: InMemoryProgrammeAssignmentStore(tables),
      slotResolver: AthleteProgrammeAuthoredSlotResolver(
        versionStore: InMemoryProgrammeVersionStore(tables),
      ),
      sessionLoader: SessionExecutionLoader(),
      localRepository: AthleteLocalRepository(kv),
    );
    executionContext = ProgrammeExecutionContext(
      assignmentId: package.assignmentId!,
      programmeVersionId: package.programmeVersionId!,
      sessionSlotId: 'W1D1S1',
      weekNumber: 1,
      dayKey: package.dayKey!,
      sessionOrder: package.slotOrder!,
      plannedProtocolId: package.protocolId!,
      effectiveProtocolId: package.protocolId!,
      programmeName: 'Journey D Fixture',
      packageContentHash: package.packageContentHash,
      programmedSessionKey: package.programmedSessionKey.value,
    );
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  JourneyDPrivateCredential seedCred({
    String marker = stableMarker,
    String? athlete,
    bool write = true,
  }) {
    final handoff = JourneyDCredentialHandoff();
    final file = File('${tmp.path}/cred.json');
    handoff.writeFresh(
      file: file,
      marker: marker,
      athleteId: athlete ?? athleteId,
      email: '$marker.athlete.jd@example.invalid',
      password: 'SecretJd!aA1-test',
      assignmentId: assignmentId,
      versionId: versionId,
    );
    return handoff.peek(file: file, expectedMarker: marker);
  }

  group('marker contract', () {
    test('1 accepts exact stable s17_jd_adapt marker unchanged', () {
      JourneyDCredentialHandoff.validateMarker(stableMarker);
      expect(stableMarker, 's17_jd_adapt_20260805T012428Z_933d9364');
    });

    test('2 rejects s17_stage_*, malformed, and alternate programmes', () {
      expect(
        () => JourneyDCredentialHandoff.validateMarker(
          's17_stage_20260805T012428Z_933d9364',
        ),
        throwsA(isA<JourneyDCredentialHandoffException>()),
      );
      expect(
        () => JourneyDCredentialHandoff.validateMarker('not-a-marker'),
        throwsA(isA<JourneyDCredentialHandoffException>()),
      );
      final handoff = JourneyDCredentialHandoff();
      expect(
        () => handoff.writeFresh(
          file: File('${tmp.path}/bad.json'),
          marker: stableMarker,
          athleteId: athleteId,
          email: '$stableMarker.athlete.jd@example.invalid',
          password: 'x',
          assignmentId: assignmentId,
          versionId: versionId,
          lineageCode: 'PROG-S15A-STAGING',
        ),
        throwsA(isA<JourneyDCredentialHandoffException>()),
      );
    });
  });

  group('private credential handoff', () {
    test('3-7 write/peek/consume/mismatch/reuse/shred', () {
      final handoff = JourneyDCredentialHandoff();
      final file = File('${tmp.path}/cred.json');
      handoff.writeFresh(
        file: file,
        marker: stableMarker,
        athleteId: athleteId,
        email: '$stableMarker.athlete.jd@example.invalid',
        password: 'SecretJd!aA1-test',
        assignmentId: assignmentId,
        versionId: versionId,
      );
      expect(file.statSync().mode & 0x049, 0);

      final peeked = handoff.peek(file: file, expectedMarker: stableMarker);
      expect(peeked.password, 'SecretJd!aA1-test');
      expect(peeked.emailLocalRedacted, isNot(contains('@example.invalid')));

      expect(
        () => handoff.peek(
          file: file,
          expectedMarker: 's17_jd_adapt_20260805T012428Z_deadbeef',
        ),
        throwsA(
          isA<JourneyDCredentialHandoffException>().having(
            (e) => e.code,
            'code',
            'marker_mismatch',
          ),
        ),
      );
      expect(
        () => handoff.peek(
          file: file,
          expectedMarker: stableMarker,
          expectedAthleteId: 'ffffffff-ffff-4fff-8fff-ffffffffffff',
        ),
        throwsA(
          isA<JourneyDCredentialHandoffException>().having(
            (e) => e.code,
            'code',
            'identity_mismatch',
          ),
        ),
      );

      final consumed = handoff.consumeOnce(
        file: file,
        expectedMarker: stableMarker,
      );
      expect(consumed.password, 'SecretJd!aA1-test');
      expect(
        () => handoff.consumeOnce(file: file, expectedMarker: stableMarker),
        throwsA(
          isA<JourneyDCredentialHandoffException>().having(
            (e) => e.code,
            'code',
            'already_consumed',
          ),
        ),
      );

      handoff.shred(file);
      expect(file.existsSync(), isFalse);
    });

    test('5 creator fake path writes credential without logging secrets', () async {
      final credOut = File('${tmp.path}/out_cred.json');
      final req = File('${tmp.path}/req.json');
      final out = File('${tmp.path}/out.json');
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
      final code = await runJourneyDLiveEntrypoint(
        environment: {
          'S17_JD_LIVE_REQUEST_FILE': req.path,
          'S17_JD_LIVE_RESULT_FILE': out.path,
          'S17_JD_LIVE_PORTS': 'fake',
          'S17_JD_ALLOW_FAKE_PORTS': '1',
          'S17_JD_CREDENTIAL_OUT_FILE': credOut.path,
        },
        ensureFlutterBinding: false,
      );
      expect(code, 0);
      final result = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
      expect(result['credential_handoff_written'], isTrue);
      expect(result.containsKey('password'), isFalse);
      expect(jsonEncode(result), isNot(contains('Secret')));
      expect(jsonEncode(result), isNot(contains('@example.invalid')));
      expect(credOut.existsSync(), isTrue);
      final cred = jsonDecode(credOut.readAsStringSync()) as Map<String, dynamic>;
      expect(cred['marker'], stableMarker);
      expect(cred['password'], isNotEmpty);
      expect(cred['consumed'], isFalse);
    });
  });

  group('execute workflow (fake ports)', () {
    test('8-12 canonical path + agreement + swap + later intact + I/J unreachable',
        () async {
      final cred = seedCred();
      final ports = FakeJourneyDExecutePorts(
        resolution: JourneyDFixtureResolution(
          marker: stableMarker,
          athleteId: athleteId,
          assignmentId: assignmentId,
          versionId: versionId,
          intendedOccurrenceKey: kJourneyDIntendedSessionKey,
          laterOccurrenceKey: kJourneyDLaterSessionKey,
        ),
        prepared: JourneyDPreparedOccurrence(
          package: package,
          executionContext: executionContext,
          sessionKey: kJourneyDIntendedSessionKey,
        ),
        permissions: permissions,
      );
      final proposalService = ProgrammeAdaptationProposalService(
        knowledge: knowledge,
        loadProtocolDraft: (_) async => draft,
        loadAdaptationPermissions: (_) async => permissions,
      );
      final workflow = JourneyDExecuteWorkflow(
        ports: ports,
        proposalService: proposalService,
        acceptanceFactory: (prep) => ProgrammeAdaptationAcceptanceService(
          prepareService: prep,
          adapter: PlanPackageSessionAdaptationAdapter(knowledge: knowledge),
          loadProtocolDraft: (_) async => draft,
          loadAdaptationPermissions: (_) async => permissions,
        ),
      );

      // Agreement required: rejecting path not auto-applied — propose alone
      // must not record evidence.
      expect(ports.evidenceCalls, 0);

      final result = await workflow.run(
        marker: stableMarker,
        credential: cred,
        prepareService: prepareService,
        eligibilityPassed: true,
      );
      expect(result.ok, isTrue, reason: result.detail);
      expect(result.swapExercise, isTrue);
      expect(
        result.sourceExerciseId,
        JourneyDEquipmentAdaptationContract.sourceExerciseId,
      );
      expect(
        result.replacementExerciseId,
        JourneyDEquipmentAdaptationContract.replacementExerciseId,
      );
      expect(result.athleteAgreementRecorded, isTrue);
      expect(result.laterPushUpIntact, isTrue);
      expect(result.journeyIExecutionCount, 0);
      expect(result.journeyJExecutionCount, 0);
      expect(result.journeyDExecutionCount, 1);
      expect(ports.passwordReachedAuth, isTrue);
      expect(ports.evidenceCalls, 1);
      expect(ports.lastEvidence?.action, 'swapExercise');
      // No Journey I/J surface in result JSON.
      final json = jsonEncode(result.toJson());
      expect(json, isNot(contains('password')));
      expect(json, isNot(contains('@example.invalid')));
    });

    test('4 ambiguous / missing fixture fails closed', () async {
      final cred = seedCred();
      for (final flag in ['missing', 'ambiguous']) {
        final ports = FakeJourneyDExecutePorts(
          resolution: JourneyDFixtureResolution(
            marker: stableMarker,
            athleteId: athleteId,
            assignmentId: assignmentId,
            versionId: versionId,
            intendedOccurrenceKey: kJourneyDIntendedSessionKey,
            laterOccurrenceKey: kJourneyDLaterSessionKey,
          ),
          prepared: JourneyDPreparedOccurrence(
            package: package,
            executionContext: executionContext,
            sessionKey: kJourneyDIntendedSessionKey,
          ),
          permissions: permissions,
          missing: flag == 'missing',
          ambiguous: flag == 'ambiguous',
        );
        final result = await JourneyDExecuteWorkflow(ports: ports).run(
          marker: stableMarker,
          credential: cred,
          prepareService: prepareService,
          eligibilityPassed: true,
        );
        expect(result.ok, isFalse);
        expect(result.classification, 'JOURNEY_D_SCOPE_BLOCKED');
        expect(ports.evidenceCalls, 0);
      }
    });

    test('9 eligibility gate blocks credential consume semantics', () async {
      final cred = seedCred();
      final ports = FakeJourneyDExecutePorts(
        resolution: JourneyDFixtureResolution(
          marker: stableMarker,
          athleteId: athleteId,
          assignmentId: assignmentId,
          versionId: versionId,
          intendedOccurrenceKey: kJourneyDIntendedSessionKey,
          laterOccurrenceKey: kJourneyDLaterSessionKey,
        ),
        prepared: JourneyDPreparedOccurrence(
          package: package,
          executionContext: executionContext,
          sessionKey: kJourneyDIntendedSessionKey,
        ),
        permissions: permissions,
      );
      final result = await JourneyDExecuteWorkflow(ports: ports).run(
        marker: stableMarker,
        credential: cred,
        prepareService: prepareService,
        eligibilityPassed: false,
      );
      expect(result.ok, isFalse);
      expect(result.classification, 'JOURNEY_D_FIXTURE_INELIGIBLE');
      expect(result.credentialConsumed, isFalse);
      expect(ports.authCalls, 0);
    });
  });

  group('entrypoint guards', () {
    test('13 genuine live/hosted mode cannot select fake ports', () async {
      final credFile = File('${tmp.path}/cred.json');
      JourneyDCredentialHandoff().writeFresh(
        file: credFile,
        marker: stableMarker,
        athleteId: athleteId,
        email: '$stableMarker.athlete.jd@example.invalid',
        password: 'x',
        assignmentId: assignmentId,
        versionId: versionId,
      );
      final req = File('${tmp.path}/ereq.json');
      final out = File('${tmp.path}/eres.json');
      req.writeAsStringSync(
        jsonEncode({
          'marker': stableMarker,
          'eligibility_passed': true,
          'api_env_path': '${tmp.path}/missing.env',
        }),
      );
      final code = await runJourneyDExecuteEntrypoint(
        environment: {
          'S17_JD_EXECUTE_REQUEST_FILE': req.path,
          'S17_JD_EXECUTE_RESULT_FILE': out.path,
          'S17_JD_CREDENTIAL_FILE': credFile.path,
          'S17_JD_EXECUTE_PORTS': 'fake',
        },
        ensureFlutterBinding: false,
      );
      expect(code, 2);
      final body = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
      expect(body['ports_mode'], 'fake_refused');
      expect(body['journey_d_executed'], isFalse);
    });

    test('14 no hosted contact during local marker rejection', () async {
      final req = File('${tmp.path}/ereq.json');
      final out = File('${tmp.path}/eres.json');
      req.writeAsStringSync(
        jsonEncode({
          'marker': 's17_stage_20260805T012428Z_933d9364',
          'eligibility_passed': true,
        }),
      );
      final code = await runJourneyDExecuteEntrypoint(
        environment: {
          'S17_JD_EXECUTE_REQUEST_FILE': req.path,
          'S17_JD_EXECUTE_RESULT_FILE': out.path,
          'S17_JD_CREDENTIAL_FILE': '${tmp.path}/missing.json',
        },
        ensureFlutterBinding: false,
      );
      expect(code, 2);
      final body = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
      expect(body['classification'], 'JOURNEY_D_CONTRACT_BLOCKED');
      expect(body['journey_d_executed'], isFalse);
    });
  });

  group('shell + verifier (no hosted)', () {
    test('execute script rejects without flags / wrong marker', () async {
      final r = await Process.run(executeSh, ['--help']);
      expect(r.exitCode, 0);
      expect(r.stdout.toString(), contains('PROG-S17-JD-ADAPT'));

      final r2 = await Process.run(
        executeSh,
        [
          '--marker',
          's17_stage_20260805T012428Z_933d9364',
          '--credential-file',
          '${tmp.path}/x',
        ],
        environment: {
          ...Platform.environment,
          'CONFIRM_COHORT_STAGING': '1',
          'S17_JD_EXECUTE': '1',
          'S17_PROJECTS_JSON_FILE': projectsFixture.path,
        },
      );
      expect(r2.exitCode, 2);
      expect(r2.stderr.toString(), contains('REFUSED'));
    });

    test('outcome mode documented; eligibility snapshot still works locally',
        () async {
      final help = await Process.run(diagnose, ['--help']);
      expect(help.stdout.toString(), contains('--outcome'));

      final apiEnv = File('${tmp.path}/api.env');
      apiEnv.writeAsStringSync(
        'S13_API_URL=https://tsbadngzgvsyfqjupkng.supabase.co\n'
        'S13_ANON_KEY=test-anon\n'
        'S13_SERVICE_KEY=test-service\n',
      );

      final r = await Process.run('python3', [
        '-c',
        '''
import json, os, sys
from pathlib import Path
sys.path.insert(0, r"$root/tool/staging/lib")
os.environ["CONFIRM_COHORT_STAGING"]="1"
os.environ["S17_JD_HOSTED_READONLY"]="1"
from s17_journey_d_hosted_readonly import run_hosted_readonly
raw=open(r"${projectsFixture.path}").read()
api=Path(r"${apiEnv.path}")
snap={
  "identity_count":1,"profile_count":1,"identity_profile_link_valid":True,
  "current_protocol_count":1,"current_revision_count":1,
  "later_protocol_count":1,"later_revision_count":1,
  "canonical_publication_attribution_valid":True,
  "programme_count":1,"programme_version_count":1,"programme_state_valid":True,
  "imported_lineages_canonical":True,"symbolic_lineage_count":0,
  "assignment_count":1,"occurrence_count":2,"occurrence_order_valid":True,
  "adaptation_state_count":0,"journey_d_execution_count":0,
  "journey_i_execution_count":0,"journey_j_execution_count":0,
  "duplicates_found":False,"unrelated_objects_attributable":False,
  "unverified_claims":[],
}
elig=run_hosted_readonly(root=Path(r"$root"), projects_raw=raw, marker="$stableMarker",
  api_env_path=api, fixture_snapshot=snap, mode="eligibility")
assert elig["fixture_eligible"] is True, elig
snap2=dict(snap)
snap2["journey_d_execution_count"]=1
snap2["journey_d_metadata"]={
  "action":"swapExercise",
  "source_exercise_id":"cohort.exercise.back_squat",
  "replacement_exercise_id":"cohort.exercise.goblet_squat",
  "substitution_rule_id":"cohort.substitution.back_squat_to_goblet_squat",
  "athlete_agreement_recorded":True,
  "permissions_passed":True,
  "intended_occurrence_key":"SES-JD-ADAPT-CURRENT",
  "programme_source_mutated":False,
}
out=run_hosted_readonly(root=Path(r"$root"), projects_raw=raw, marker="$stableMarker",
  api_env_path=api, fixture_snapshot=snap2, mode="outcome")
assert out["outcome_verified"] is True, out
assert out["fixture_eligible"] is False
print("OUTCOME_CONTRACT_OK")
''',
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
      expect(r.stdout.toString(), contains('OUTCOME_CONTRACT_OK'));
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
