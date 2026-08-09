@Tags(['harness'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/application/adaptation/journey_d_equipment_adaptation_contract.dart';
import 'package:cohort_platform/application/adaptation/plan_package_session_adaptation_adapter.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_acceptance_service.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_proposal_service.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_policy_gate.dart';
import 'package:cohort_platform/features/authored_plan_package/plan_package_manifest.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
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
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_session_authoring_test_support.dart';

/// Fake-only Journey D execute harness.
///
/// Invoked by `tool/staging/run_s17_journey_d_execute_dart.sh` or
/// `tool/testing/run_phase2_harness_tests.sh` when `S17_JD_EXECUTE_PORTS=fake`
/// and `S17_JD_ALLOW_FAKE_PORTS=1`. Skipped in the default `flutter test` suite.
///
/// Fake execute requires injected ports/workflow/prepare (product contract).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const marker = 's17_jd_adapt_20260809T120000Z_a1b2c3d4';
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
    tmp = Directory.systemTemp.createTempSync('jd_exec_harness_');
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

  test(
    'journey_d_execute_entrypoint_fake_harness',
    () async {
      final ports = Platform.environment['S17_JD_EXECUTE_PORTS'] ?? '';
      final allow = Platform.environment['S17_JD_ALLOW_FAKE_PORTS'] ?? '';
      expect(ports, 'fake');
      expect(allow, '1');

      final reqPath =
          Platform.environment['S17_JD_EXECUTE_REQUEST_FILE'] ??
          '${tmp.path}/exec_req.json';
      final outPath =
          Platform.environment['S17_JD_EXECUTE_RESULT_FILE'] ??
          '${tmp.path}/exec_out.json';
      final credPath =
          Platform.environment['S17_JD_CREDENTIAL_FILE'] ??
          '${tmp.path}/cred.json';

      File(reqPath).writeAsStringSync(
        jsonEncode({
          'marker': marker,
          'eligibility_passed': true,
        }),
      );
      JourneyDCredentialHandoff().writeFresh(
        file: File(credPath),
        marker: marker,
        athleteId: athleteId,
        email: '$marker.athlete.jd@example.invalid',
        password: 'SecretJd!aA1-harness',
        assignmentId: assignmentId,
        versionId: versionId,
      );

      final fakePorts = FakeJourneyDExecutePorts(
        resolution: JourneyDFixtureResolution(
          marker: marker,
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
        ports: fakePorts,
        proposalService: proposalService,
        acceptanceFactory: (prep) => ProgrammeAdaptationAcceptanceService(
          prepareService: prep,
          adapter: PlanPackageSessionAdaptationAdapter(knowledge: knowledge),
          loadProtocolDraft: (_) async => draft,
          loadAdaptationPermissions: (_) async => permissions,
        ),
      );

      final code = await runJourneyDExecuteEntrypoint(
        environment: {
          ...Platform.environment,
          'S17_JD_EXECUTE_PORTS': 'fake',
          'S17_JD_ALLOW_FAKE_PORTS': '1',
          'S17_JD_EXECUTE_REQUEST_FILE': reqPath,
          'S17_JD_EXECUTE_RESULT_FILE': outPath,
          'S17_JD_CREDENTIAL_FILE': credPath,
        },
        ensureFlutterBinding: false,
        portsOverride: fakePorts,
        workflowOverride: workflow,
        prepareOverride: prepareService,
      );
      expect(
        code,
        0,
        reason:
            'Journey D fake execute entrypoint returned $code '
            '(see $outPath)',
      );
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
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
