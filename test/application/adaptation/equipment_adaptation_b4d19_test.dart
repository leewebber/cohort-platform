import 'dart:io';

import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_proposal.dart';
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
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_planning_test_support.dart';
import '../../support/in_memory_programme_stores.dart';
import '../../support/programme_session_authoring_test_support.dart';

void main() {
  late InMemoryKnowledgeGraphReader knowledge;
  late ProtocolDraft draft;
  late PreparedExecutionPackage package;
  late List<PlanPackageAdaptationPermission> permissions;

  setUpAll(() async {
    final root = _findKnowledgeRoot(Directory.current);
    final bundle = await const YamlKnowledgeOntologyLoader().loadFromDirectory(
      root,
    );
    knowledge = InMemoryKnowledgeGraphReader(bundle);
  });

  setUp(() {
    draft = buildEquipmentPlanningSession();
    package = _packageFromDraft(draft);
    permissions = const [
      PlanPackageAdaptationPermission(
        id: 'ADP-EQUIP-W1',
        changeKind: AdaptationChangeKind.substituteApprovedEquipment,
        targetRef: 'programme',
        athleteAgreementRequired: true,
        scopeNote: 'Equipment substitutions for Journey D contract',
      ),
    ];
  });

  ProgrammeAdaptationProposalService service({
    List<PlanPackageAdaptationPermission>? perms,
    ProtocolDraft? draftOverride,
    PreparedExecutionPackage? packageOverride,
  }) {
    final d = draftOverride ?? draft;
    return ProgrammeAdaptationProposalService(
      knowledge: knowledge,
      loadProtocolDraft: (_) async => d,
      loadAdaptationPermissions: (_) async => perms ?? permissions,
    );
  }

  group('B4d.19 equipment request validation', () {
    test('missing availableEquipment fails closed', () async {
      final proposal = await service().propose(
        package: package,
        request: const AdaptationRequest(reason: AdaptationReason.equipment),
      );
      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(
        proposal.noSafeReason,
        ProgrammeAdaptationNoSafeReason.availableEquipmentRequired,
      );
    });

    test('empty availableEquipment fails closed', () async {
      final proposal = await service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment: {},
        ),
      );
      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(
        proposal.noSafeReason,
        ProgrammeAdaptationNoSafeReason.availableEquipmentRequired,
      );
    });

    test('unknown equipment token fails closed', () async {
      final proposal = await service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment: {'not_a_real_equipment_token'},
        ),
      );
      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(
        proposal.noSafeReason,
        ProgrammeAdaptationNoSafeReason.availableEquipmentRequired,
      );
    });
  });

  group('B4d.19 equipment permission gate', () {
    test('empty package permissions prohibit adaptation', () async {
      final proposal = await service(perms: const []).propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
      );
      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(
        proposal.noSafeReason,
        ProgrammeAdaptationNoSafeReason.substitutionNotPermitted,
      );
    });

    test('athlete_agreement_required=false is rejected', () async {
      final proposal =
          await service(
            perms: const [
              PlanPackageAdaptationPermission(
                id: 'ADP-BAD',
                changeKind: AdaptationChangeKind.substituteApprovedEquipment,
                targetRef: 'programme',
                athleteAgreementRequired: false,
              ),
            ],
          ).propose(
            package: package,
            request: const AdaptationRequest(
              reason: AdaptationReason.equipment,
              availableEquipment:
                  JourneyDEquipmentAdaptationContract.availableEquipment,
            ),
          );
      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(
        proposal.noSafeReason,
        ProgrammeAdaptationNoSafeReason.substitutionNotPermitted,
      );
    });

    test('disallowed change kind is outside AdaptationPolicyGate.allowed', () {
      expect(
        AdaptationPolicyGate.allowed.contains(
          AdaptationChangeKind.substituteApprovedEquipment,
        ),
        isTrue,
      );
      expect(
        AdaptationPolicyGate.allowed.contains(AdaptationChangeKind.rewritePlan),
        isFalse,
      );
    });
  });

  group('B4d.19 equipment conflict and substitution', () {
    test('no session conflict produces no unnecessary plan', () async {
      final proposal = await service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment: {
            'cohort.equipment.barbell',
            'cohort.equipment.squat_rack',
            'cohort.equipment.kettlebell',
            'cohort.equipment.bodyweight',
          },
        ),
      );
      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noAdaptationRequired,
      );
      expect(proposal.allMaterialChanges, isEmpty);
    });

    test('conflict with no approved substitution fails closed', () async {
      final pullDraft = buildEquipmentPlanningSession(
        exerciseId: 'cohort.exercise.pull_up',
      );
      final pullPackage = _packageFromDraft(pullDraft);
      final proposal = await service(draftOverride: pullDraft).propose(
        package: pullPackage,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment: {'cohort.equipment.kettlebell'},
        ),
      );
      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(
        proposal.noSafeReason,
        ProgrammeAdaptationNoSafeReason.noApprovedSubstitution,
      );
    });

    test(
      'valid conflict + approved substitution produces acceptable proposal',
      () async {
        final proposal = await service().propose(
          package: package,
          request: const AdaptationRequest(
            reason: AdaptationReason.equipment,
            availableEquipment:
                JourneyDEquipmentAdaptationContract.availableEquipment,
          ),
          proposedAt: DateTime.utc(2026, 8, 4, 10),
        );

        expect(
          proposal.outcome,
          ProgrammeAdaptationProposalOutcome.reviewable,
          reason:
              'noSafeReason=${proposal.noSafeReason} '
              'msg=${proposal.athleteFacingMessage} '
              'provenance=${proposal.evaluationProvenance}',
        );
        expect(proposal.isAcceptable, isTrue);
        expect(proposal.request?.availableEquipment, isNotEmpty);
        expect(
          proposal.exerciseChanges.any(
            (c) =>
                c.beforeValue ==
                    JourneyDEquipmentAdaptationContract.sourceExerciseId &&
                c.afterValue ==
                    JourneyDEquipmentAdaptationContract.replacementExerciseId,
          ),
          isTrue,
        );
        expect(
          proposal.policyKinds,
          contains(AdaptationChangeKind.substituteApprovedEquipment.name),
        );
      },
    );

    test('proposal is deterministic across repeated evaluation', () async {
      Future<ProgrammeAdaptationProposal> once() => service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
        proposedAt: DateTime.utc(2026, 8, 4, 11),
      );
      final a = await once();
      final b = await once();
      expect(a.proposalId, b.proposalId);
      expect(a.reviewedPlanFingerprint, b.reviewedPlanFingerprint);
      expect(
        a.exerciseChanges.map((c) => '${c.beforeValue}->${c.afterValue}'),
        b.exerciseChanges.map((c) => '${c.beforeValue}->${c.afterValue}'),
      );
    });

    test('proposal generation does not mutate prepared execution', () async {
      final before = ProgrammeAdaptationFingerprints.plan(package.plan);
      await service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
      );
      expect(ProgrammeAdaptationFingerprints.plan(package.plan), before);
      expect(package.acceptedAdaptation, isNull);
    });
  });

  group('B4d.19 accept / reject / reload boundaries', () {
    late AthleteProgrammeSessionPrepareService prepareService;
    late ProgrammeAdaptationAcceptanceService acceptanceService;
    late ProgrammeExecutionContext executionContext;

    setUp(() async {
      final kv = InMemoryKvStore();
      final tables = InMemoryProgrammeTables();
      prepareService = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: _FixedLoader(package.plan),
        localRepository: AthleteLocalRepository(kv),
      );
      acceptanceService = ProgrammeAdaptationAcceptanceService(
        prepareService: prepareService,
        loadProtocolDraft: (_) async => draft,
        loadAdaptationPermissions: (_) async => permissions,
        adapter: PlanPackageSessionAdaptationAdapter(knowledge: knowledge),
      );
      executionContext = ProgrammeExecutionContext(
        assignmentId: package.assignmentId!,
        programmeVersionId: package.programmeVersionId!,
        sessionSlotId: 'slot.equip.1',
        weekNumber: 1,
        dayKey: package.dayKey!,
        sessionOrder: package.slotOrder!,
        plannedProtocolId: package.protocolId!,
        effectiveProtocolId: package.protocolId!,
        programmeName: 'Equipment Fixture',
        packageContentHash: package.packageContentHash,
        programmedSessionKey: package.programmedSessionKey.value,
      );
      await prepareService.replacePreparedPackage(
        athleteId: 'athlete.equip.1',
        package: package,
        executionContext: executionContext,
      );
    });

    test('reject leaves all state unchanged', () async {
      final before = ProgrammeAdaptationFingerprints.plan(package.plan);
      final proposal = await service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
      );
      expect(proposal.isAcceptable, isTrue);
      expect(ProgrammeAdaptationFingerprints.plan(package.plan), before);
      expect(package.acceptedAdaptation, isNull);
    });

    test('accept changes only current prepared execution', () async {
      final proposal = await service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
        proposedAt: DateTime.utc(2026, 8, 4, 12),
      );
      expect(proposal.isAcceptable, isTrue);

      final beforeKey = package.programmedSessionKey.value;
      final beforeAssignment = package.assignmentId;
      final beforeHash = package.packageContentHash;

      final result = await acceptanceService.accept(
        athleteId: 'athlete.equip.1',
        currentPackage: package,
        proposal: proposal,
        executionContext: executionContext,
      );

      expect(result.success, isTrue);
      final updated = result.package!;
      expect(updated.programmedSessionKey.value, beforeKey);
      expect(updated.assignmentId, beforeAssignment);
      expect(updated.packageContentHash, beforeHash);
      expect(updated.acceptedAdaptation, isNotNull);
      expect(
        updated.plan.blocks.first.linkedExercises.any(
          (e) =>
              e.exerciseId ==
              JourneyDEquipmentAdaptationContract.replacementExerciseId,
        ),
        isTrue,
      );
      expect(
        updated.plan.blocks.first.linkedExercises.any(
          (e) =>
              e.exerciseId ==
              JourneyDEquipmentAdaptationContract.sourceExerciseId,
        ),
        isFalse,
      );
      // Later accessory block remains as authored baseline.
      expect(
        updated.plan.blocks.last.linkedExercises.first.exerciseId,
        'cohort.exercise.push_up',
      );
    });

    test('consumed and already-adapted proposals fail closed', () async {
      final proposal = await service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
        proposedAt: DateTime.utc(2026, 8, 4, 13),
      );
      final first = await acceptanceService.accept(
        athleteId: 'athlete.equip.1',
        currentPackage: package,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(first.success, isTrue);

      final second = await acceptanceService.accept(
        athleteId: 'athlete.equip.1',
        currentPackage: first.package!,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(second.success, isFalse);
      expect(
        second.errorCode == 'proposal_consumed' ||
            second.errorCode == 'already_adapted',
        isTrue,
      );
    });

    test(
      'reload restores accepted adaptation for same programmed key',
      () async {
        final proposal = await service().propose(
          package: package,
          request: const AdaptationRequest(
            reason: AdaptationReason.equipment,
            availableEquipment:
                JourneyDEquipmentAdaptationContract.availableEquipment,
          ),
          proposedAt: DateTime.utc(2026, 8, 4, 14),
        );
        final accepted = await acceptanceService.accept(
          athleteId: 'athlete.equip.1',
          currentPackage: package,
          proposal: proposal,
          executionContext: executionContext,
        );
        expect(accepted.success, isTrue);

        final restored = prepareService.cachedPackageForKey(
          package.programmedSessionKey.value,
        );
        expect(restored, isNotNull);
        expect(restored!.acceptedAdaptation, isNotNull);
        expect(
          restored.plan.blocks.first.linkedExercises.any(
            (e) =>
                e.exerciseId ==
                JourneyDEquipmentAdaptationContract.replacementExerciseId,
          ),
          isTrue,
        );
      },
    );
  });

  group('B4d.19 regressions and Journey D harness contract', () {
    test('time adaptation still produces acceptable proposal', () async {
      final timed = buildTimedPlanningSession(protocolId: 'proto.time.reg');
      final timedPackage = _packageFromDraft(timed);
      final proposal =
          await ProgrammeAdaptationProposalService(
            knowledge: knowledge,
            loadProtocolDraft: (_) async => timed,
            loadAdaptationPermissions: (_) async => const [],
          ).propose(
            package: timedPackage,
            request: const AdaptationRequest(
              reason: AdaptationReason.time,
              availableMinutes: 40,
            ),
          );
      expect(proposal.isAcceptable, isTrue);
    });

    test('environment still fails closed', () async {
      final proposal = await service().propose(
        package: package,
        request: const AdaptationRequest(reason: AdaptationReason.environment),
      );
      expect(
        proposal.outcome,
        ProgrammeAdaptationProposalOutcome.noSafeAdaptation,
      );
      expect(
        proposal.noSafeReason,
        ProgrammeAdaptationNoSafeReason.unsupportedConstraintFamily,
      );
    });

    test('Journey D harness constructs expected equipment request', () {
      const request = AdaptationRequest(
        reason: AdaptationReason.equipment,
        availableEquipment:
            JourneyDEquipmentAdaptationContract.availableEquipment,
      );
      expect(request.reason, AdaptationReason.equipment);
      expect(
        request.availableEquipment,
        JourneyDEquipmentAdaptationContract.availableEquipment,
      );
      expect(
        request.availableEquipment!.containsAll(
          JourneyDEquipmentAdaptationContract.omittedRequiredEquipment,
        ),
        isFalse,
      );
    });

    test(
      'Journey D local contract fixture reaches isAcceptable=true',
      () async {
        final proposal = await service().propose(
          package: package,
          request: const AdaptationRequest(
            reason: AdaptationReason.equipment,
            availableEquipment:
                JourneyDEquipmentAdaptationContract.availableEquipment,
          ),
        );
        expect(proposal.isAcceptable, isTrue);
      },
    );

    test('non-acceptable proposal cannot be treated as PASS', () async {
      final proposal = await service(perms: const []).propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
      );
      expect(proposal.isAcceptable, isFalse);
      expect(
        proposal.outcome,
        isNot(ProgrammeAdaptationProposalOutcome.reviewable),
      );
    });

    test('no auto-apply path on proposal service', () async {
      final before = package.acceptedAdaptation;
      await service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
      );
      expect(package.acceptedAdaptation, before);
    });
  });
}

ProtocolDraft buildEquipmentPlanningSession({
  String protocolId = 'proto.equip.1',
  String exerciseId = JourneyDEquipmentAdaptationContract.sourceExerciseId,
}) {
  return programmeSession(
    protocolId: protocolId,
    name: 'Equipment planning session',
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
            exerciseId: exerciseId,
            position: 1,
            prescription: StrengthExercisePrescription(
              sets: 3,
              reps: StrengthRepPrescription.exact(5),
              restSeconds: 120,
            ),
          ),
        ],
      ),
      block(
        localId: 'block-later',
        type: SessionBlockType.accessory,
        position: 2,
        blockPriority: BlockPriority.secondary,
        linkedExercises: [
          SessionBlockExerciseLink(
            localId: 'link-later-1',
            exerciseId: 'cohort.exercise.push_up',
            position: 1,
            prescription: StrengthExercisePrescription(
              sets: 2,
              reps: StrengthRepPrescription.exact(10),
            ),
          ),
        ],
      ),
    ],
  );
}

PreparedExecutionPackage _packageFromDraft(ProtocolDraft draft) {
  final key = ProgrammedSessionKey(
    planId: 'lineage.equip',
    planVersion: 'version.equip',
    week: 1,
    day: 1,
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
    programmeAssignmentId: 'assignment.equip',
    packageContentHash: 'hash.equip',
  );

  final plan = SessionExecutionPlan(
    sessionId: draft.protocolId,
    sessionTitle: draft.name,
    durationMin: draft.durationMin,
    blocks: draft.blocks
        .map(
          (block) => SessionExecutionBlock.fromSessionBlock(
            block,
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
    assignmentId: 'assignment.equip',
    programmeVersionId: testProgrammeVersionId,
    packageContentHash: 'hash.equip',
    dayKey: 'day_1',
    slotOrder: 1,
    protocolId: draft.protocolId,
  );
}

class _FixedLoader extends SessionExecutionLoader {
  _FixedLoader(this.plan) : super();

  final SessionExecutionPlan plan;

  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    return SessionExecutionLoadResult(plan: plan);
  }
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
