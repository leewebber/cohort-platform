import 'dart:convert';
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
import 'package:cohort_platform/application/adaptation/programme_adaptation_permission_reader.dart';
import 'package:cohort_platform/core/persistence/athlete_persistence.dart';
import 'package:cohort_platform/features/home/services/programme_adapt_flow.dart';
import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/screens/training_history_detail_screen.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_store.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/features/session/services/production_restore_envelope_store.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_launcher.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_planning_test_support.dart';
import '../../support/in_memory_programme_stores.dart';
import '../../support/programme_session_authoring_test_support.dart';
import '../../support/programme_schedule_test_fixtures.dart';

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

  testWidgets('equipment review, accept, cold restore and programme History', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(AthletePersistence.resetForTests);
    addTearDown(AthleteSessionMemoryStore.instance.clearAll);

    const athlete = 'equipment-fixture-athlete';
    final tables = InMemoryProgrammeTables();
    final assignments = InMemoryProgrammeAssignmentStore(tables);
    final versions = InMemoryProgrammeVersionStore(tables);
    final assignment = ProgrammeScheduleTestFixtures.materialisedAssignment(
      athleteId: athlete,
    ).copyWith(scheduleMode: 'fixed_schedule');
    tables.assignments.add(assignment);
    final version = ProgrammeVersion(
      id: assignment.programmeVersionId,
      lineageId: ProgrammeScheduleTestFixtures.lineageId,
      versionNumber: 1,
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      libraryScope: ProgrammeLibraryScope.cohortGlobal,
      ownerType: ProgrammeOwnerType.global,
      name: 'Equipment fixture programme',
      packageContentHash: assignment.materialisedPackageContentHash,
      packageSchemaVersion: 2,
    );
    await versions.saveTemplateTree(
      version: version,
      tree: ProgrammeScheduleTestFixtures.singleWeekTree(
        days: [
          ProgrammeScheduleTestFixtures.trainingDay(
            id: ProgrammeScheduleTestFixtures.day1Id,
            weekId: ProgrammeScheduleTestFixtures.week1Id,
            dayKey: 'day_1',
            dayOrder: 1,
            slots: [
              ProgrammeScheduleTestFixtures.requiredSlot(
                id: ProgrammeScheduleTestFixtures.slot1Id,
                dayId: ProgrammeScheduleTestFixtures.day1Id,
                sessionOrder: 1,
                protocolId: draft.protocolId,
              ),
            ],
          ),
        ],
      ),
    );
    final resolver = AthleteProgrammeAuthoredSlotResolver(
      versionStore: versions,
    );
    final resolved = await resolver.resolve(
      assignment,
      scheduleDate: DateTime.utc(2026, 11, 9),
    );
    FixedProgrammeOccurrenceProjection occurrence({required bool resumed}) =>
        FixedProgrammeOccurrenceProjection(
          assignmentId: assignment.id,
          occurrenceId: 'fixture-occurrence',
          sessionSlotId: resolved.slot.id,
          programmeVersionId: version.id,
          protocolId: draft.protocolId,
          programmedSessionKey: resolved.programmedSessionKey.value,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          scheduledDate: '2026-11-09',
          originalScheduledDate: '2026-11-09',
          state: resumed
              ? FixedProgrammeOccurrenceState.inProgress
              : FixedProgrammeOccurrenceState.today,
          sessionTitle: draft.name,
          trainingSessionId: resumed ? 91 : null,
        );

    var permitted = false;
    final permissionReads = <String>[];
    final client = (await tester.runAsync(
      () async => SupabaseClient(
        'http://localhost:12345',
        'local-test-key',
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/rest/v1/programme_version_adaptation_permissions',
          );
          permissionReads.add(request.url.queryParameters['version_id']!);
          return Response(
            jsonEncode([
              if (permitted)
                {
                  'permission_key': 'fixture-equipment',
                  'change_kind': 'substitute_approved_equipment',
                  'target_ref': 'programme',
                  'athlete_agreement_required': true,
                },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
        authOptions: AuthClientOptions(autoRefreshToken: false),
      ),
    ))!;
    addTearDown(client.dispose);
    final permissionReader = ProgrammeAdaptationPermissionReader(
      client: client,
    );
    final start = _EquipmentFixtureStart(athlete, assignment.lineageCode);
    final original = package.plan;
    var kv = InMemoryKvStore();
    var records = InMemoryPerformanceRecordStore();
    late AthleteProgrammeSessionPrepareService prepare;
    late PerformanceRecordSaveCoordinator coordinator;
    late _EquipmentFixtureCompletion completion;
    Future<void> mount({required bool resumed}) async {
      final repository = AthleteLocalRepository(kv);
      AthletePersistence.bindForTests(repository);
      prepare = AthleteProgrammeSessionPrepareService(
        assignmentStore: assignments,
        slotResolver: resolver,
        sessionLoader: _FixedLoader(original),
        localRepository: repository,
      );
      completion = _EquipmentFixtureCompletion(records);
      coordinator = PerformanceRecordSaveCoordinator(
        store: records,
        programmeCompletionService: AthleteProgrammeCompletionService(
          store: completion,
          assignmentStore: assignments,
          performanceStore: records,
          localRepository: repository,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AthleteProgrammeTodaySection(
              athleteId: athlete,
              fixedAssignment: assignment,
              fixedOccurrence: occurrence(resumed: resumed),
              prepareService: prepare,
              adaptFlow: ProgrammeAdaptFlow.forPreparedSession(
                prepareService: prepare,
                loadAdaptationPermissions: permissionReader.load,
                loadProtocolDraft: (id) async {
                  expect(id, draft.protocolId);
                  return draft;
                },
                loadKnowledge: () async => knowledge,
              ),
              executionLauncher: ProgrammeSessionExecutionLauncher(
                startStore: start,
                sessionExecutionLauncher: SessionExecutionLauncher(
                  saveCoordinator: coordinator,
                  restoreEnvelopeStore: ProductionRestoreEnvelopeStore(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> tap(String text) async {
      final finder = find.text(text);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 4),
      );
    }

    Future<void> review() async {
      await tap('Adapt Session');
      await tap('Equipment');
      await tap('Kettlebell');
      await tap('Bodyweight');
      await tap('Continue');
    }

    await mount(resumed: false);
    final key = resolved.programmedSessionKey.value;
    final preparedKey = PersistenceKeys.generatedSession(athlete);
    final originalBytes = kv.debugDump[preparedKey];
    expect(originalBytes, isNotNull);

    await review();
    expect(
      find.textContaining(
        'Authored adaptation permissions do not permit equipment',
      ),
      findsOneWidget,
    );
    expect(find.text('Accept Adaptation'), findsNothing);
    await tap('Keep Original Session');
    expect(kv.debugDump[preparedKey], originalBytes);
    expect(prepare.cachedPackageForKey(key)!.acceptedAdaptation, isNull);

    permitted = true;
    await review();
    expect(
      find.textContaining('Back squat → Goblet squat'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    expect(
      find.textContaining('Reduces absolute load potential'),
      findsOneWidget,
    );
    expect(kv.debugDump[preparedKey], originalBytes);
    await tap('Keep Original Session');
    expect(kv.debugDump[preparedKey], originalBytes);
    expect(prepare.cachedPackageForKey(key)!.acceptedAdaptation, isNull);
    expect(start.calls, isEmpty);

    await review();
    await tap('Accept Adaptation');
    expect(permissionReads, List.filled(4, 'eq.${version.id}'));
    final accepted = prepare.cachedPackageForKey(key)!;
    expect(accepted.acceptedAdaptation, isNotNull);
    expect(
      accepted.plan.blocks.first.linkedExercises.single.exerciseId,
      JourneyDEquipmentAdaptationContract.replacementExerciseId,
    );
    expect(accepted.plan.blocks.last, same(original.blocks.last));
    expect(
      accepted.plan.blocks.first.linkedExercises.single.prescription!.toJson(),
      original.blocks.first.linkedExercises.single.prescription!.toJson(),
    );
    expect(
      assignment.toUpdateMap(),
      (await assignments.getById(assignment.id))!.toUpdateMap(),
    );

    await tap('Begin');
    var screen = tester.widget<ActiveSessionScreen>(
      find.byType(ActiveSessionScreen),
    );
    expect(screen.trainingSessionId, 91);
    final initialDraft = screen.performanceController.draft;
    final firstBlock = initialDraft.blockDrafts.first;
    final goblet = firstBlock.exerciseResults.single;
    final setId = goblet.sets.first.setResultId;
    expect(goblet.exerciseSnapshot.displayName, 'Goblet squat');
    screen.performanceController.updateSet(
      firstBlock.sourceBlockId,
      goblet.sourceExerciseId,
      setId,
      (set) => set.copyWith(reps: 5, load: 16, loadUnit: 'kg', completed: true),
    );
    await tap('Back to Home');

    // Relaunch with only serialized prepared state, restore envelope and actuals.
    await tester.pumpWidget(const SizedBox());
    AthleteSessionMemoryStore.instance.clearAll();
    final saved = kv.debugDump;
    kv = InMemoryKvStore();
    for (final entry in saved.entries) {
      await kv.writeString(entry.key, entry.value);
    }
    final recordTrees =
        jsonDecode(jsonEncode(records.exportCompletionTrees())) as List;
    records = InMemoryPerformanceRecordStore()
      ..seedFromCompletionTrees(recordTrees.cast<Map<String, dynamic>>());
    await mount(resumed: true);
    expect(find.text('Adapt Session'), findsNothing);
    expect(find.text('Revert to Original'), findsNothing);
    await tap('Resume');
    screen = tester.widget<ActiveSessionScreen>(
      find.byType(ActiveSessionScreen),
    );
    expect(start.calls.map((call) => call['occurrence_id']), [
      'fixture-occurrence',
      'fixture-occurrence',
    ]);
    expect(screen.trainingSessionId, 91);
    expect(screen.performanceController.draft.recordId, initialDraft.recordId);
    final restored = screen
        .performanceController
        .draft
        .blockDrafts
        .first
        .exerciseResults
        .single;
    expect(restored.sourceExerciseId, goblet.sourceExerciseId);
    expect(restored.exerciseSnapshot.displayName, 'Goblet squat');
    expect(restored.sets.first.setResultId, setId);
    expect(restored.sets.first.reps, 5);
    expect(restored.sets.first.load, 16);
    expect(restored.sets.first.completed, isTrue);

    for (final block in List.of(
      screen.performanceController.draft.blockDrafts,
    )) {
      for (final exercise in block.exerciseResults) {
        for (final set in exercise.sets.where((set) => !set.completed)) {
          screen.performanceController.updateSet(
            block.sourceBlockId,
            exercise.sourceExerciseId,
            set.setResultId,
            (value) => value.copyWith(
              reps: 5,
              load: 16,
              loadUnit: 'kg',
              completed: true,
            ),
          );
        }
      }
      screen.performanceController.markBlockComplete(block.sourceBlockId);
      screen.controller.markBlockComplete(block.sourceBlockId);
    }
    // Save and reopen the real review route so it sees the completed capture.
    await tap('Back to Home');
    await tap('Resume');
    await tap('Finish Session');
    expect(find.text('Review Session'), findsOneWidget);
    expect(find.textContaining('Back squat → Goblet squat'), findsOneWidget);
    await tap('Save and finish');
    expect(find.text('Session saved'), findsOneWidget);
    expect(find.textContaining('Back squat → Goblet squat'), findsOneWidget);
    expect(completion.calls, hasLength(1));
    expect(completion.calls.single['protocol_id'], draft.protocolId);
    expect(completion.calls.single['occurrence_id'], 'fixture-occurrence');

    final history = await coordinator.listHistory(athleteId: athlete);
    expect(history, hasLength(1));
    expect(history.single.recordId, initialDraft.recordId);
    final result = history.single.blockResults.first.exerciseResults.single;
    expect(result.sourceExerciseId, goblet.sourceExerciseId);
    expect(result.exerciseSnapshot.displayName, 'Goblet squat');
    expect(result.setResults.first.load, 16);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: TrainingHistoryDetailScreen(
          recordId: history.single.recordId,
          athleteId: athlete,
          saveCoordinator: coordinator,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Goblet squat'), findsOneWidget);
    expect(find.text('Back squat'), findsNothing);
  });

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

    test('an exact swap cannot carry over an exercise-specific load', () async {
      final block = draft.blocks.first;
      final link = block.linkedExercises.single;
      final fixedLoadDraft = draft.copyWith(
        blocks: [
          block.copyWith(
            linkedExercises: [
              link.copyWith(
                prescription: link.prescription!.copyWith(
                  load: const StrengthLoadPrescription(
                    type: StrengthLoadType.fixedKg,
                    kg: 80,
                  ),
                ),
              ),
            ],
          ),
          ...draft.blocks.skip(1),
        ],
      );
      final original = _packageFromDraft(fixedLoadDraft);
      final result = await service(draftOverride: fixedLoadDraft).propose(
        package: original,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
      );
      expect(result.isAcceptable, isFalse);
      expect(
        original
            .plan
            .blocks
            .first
            .linkedExercises
            .single
            .prescription!
            .load!
            .kg,
        80,
      );
    });

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

  group('B4d.19 freshness knowledge parity (Journey D staging defect)', () {
    late AthleteProgrammeSessionPrepareService prepareService;
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
      executionContext = ProgrammeExecutionContext(
        assignmentId: package.assignmentId!,
        programmeVersionId: package.programmeVersionId!,
        sessionSlotId: 'slot.fresh.1',
        weekNumber: 1,
        dayKey: package.dayKey!,
        sessionOrder: package.slotOrder!,
        plannedProtocolId: package.protocolId!,
        effectiveProtocolId: package.protocolId!,
        programmeName: 'Freshness Fixture',
        packageContentHash: package.packageContentHash,
        programmedSessionKey: package.programmedSessionKey.value,
      );
      await prepareService.replacePreparedPackage(
        athleteId: 'athlete.fresh.1',
        package: package,
        executionContext: executionContext,
      );
    });

    test(
      'knowledge-less accept freshness reproduces freshness_invalid',
      () async {
        final proposal = await service().propose(
          package: package,
          request: const AdaptationRequest(
            reason: AdaptationReason.equipment,
            availableEquipment:
                JourneyDEquipmentAdaptationContract.availableEquipment,
          ),
          proposedAt: DateTime.utc(2026, 8, 8, 7, 18),
        );
        expect(proposal.isAcceptable, isTrue);

        // Staging defect: accept used PlanPackageSessionAdaptationAdapter()
        // without curated knowledge after propose used knowledge.
        final broken = ProgrammeAdaptationAcceptanceService(
          prepareService: prepareService,
          loadProtocolDraft: (_) async => draft,
          loadAdaptationPermissions: (_) async => permissions,
          adapter: PlanPackageSessionAdaptationAdapter(),
        );
        final failed = await broken.accept(
          athleteId: 'athlete.fresh.1',
          currentPackage: package,
          proposal: proposal,
          executionContext: executionContext,
          acceptedAt: DateTime.utc(2026, 8, 8, 7, 18, 5),
        );
        expect(failed.success, isFalse);
        expect(failed.errorCode, 'freshness_invalid');
      },
    );

    test(
      'knowledge-backed accept freshness accepts the same recommendation',
      () async {
        final proposal = await service().propose(
          package: package,
          request: const AdaptationRequest(
            reason: AdaptationReason.equipment,
            availableEquipment:
                JourneyDEquipmentAdaptationContract.availableEquipment,
          ),
          proposedAt: DateTime.utc(2026, 8, 8, 7, 18),
        );
        expect(proposal.isAcceptable, isTrue);

        final acceptance = ProgrammeAdaptationAcceptanceService(
          prepareService: prepareService,
          loadProtocolDraft: (_) async => draft,
          loadAdaptationPermissions: (_) async => permissions,
          knowledge: knowledge,
        );
        final ok = await acceptance.accept(
          athleteId: 'athlete.fresh.1',
          currentPackage: package,
          proposal: proposal,
          executionContext: executionContext,
          acceptedAt: DateTime.utc(2026, 8, 8, 7, 18, 5),
        );
        expect(ok.success, isTrue, reason: '${ok.errorCode}');
        expect(ok.decision?.proposalId, proposal.proposalId);
      },
    );

    test('knowledge-less mismatch path still fails closed', () async {
      final proposal = await service().propose(
        package: package,
        request: const AdaptationRequest(
          reason: AdaptationReason.equipment,
          availableEquipment:
              JourneyDEquipmentAdaptationContract.availableEquipment,
        ),
      );
      expect(proposal.isAcceptable, isTrue);

      final acceptance = ProgrammeAdaptationAcceptanceService(
        prepareService: prepareService,
        loadProtocolDraft: (_) async => draft,
        loadAdaptationPermissions: (_) async => permissions,
        adapter: PlanPackageSessionAdaptationAdapter(),
      );
      final failed = await acceptance.accept(
        athleteId: 'athlete.fresh.1',
        currentPackage: package,
        proposal: proposal,
        executionContext: executionContext,
      );
      expect(failed.success, isFalse);
      expect(
        failed.errorCode,
        anyOf(
          'freshness_invalid',
          'proposal_mismatch',
          'material_change_mismatch',
        ),
      );
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

class _EquipmentFixtureStart implements ProgrammeTrainingSessionStartStore {
  _EquipmentFixtureStart(this.athlete, this.lineage);

  final String athlete;
  final String lineage;
  final calls = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> createOrResume(
    Map<String, dynamic> payload,
  ) async {
    calls.add(payload);
    return {
      'status': calls.length == 1 ? 'created' : 'resumed',
      'training_session': {
        'id': 91,
        'athlete_id': athlete,
        'protocol_id': payload['effective_protocol_id'],
        'programme_id': lineage,
        'week_number': payload['expected_week'],
        'day': payload['expected_day_key'],
        'status': 'in_progress',
      },
    };
  }
}

class _EquipmentFixtureCompletion implements AthleteProgrammeCompletionStore {
  _EquipmentFixtureCompletion(this.records);

  final InMemoryPerformanceRecordStore records;
  final calls = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> completeAndAdvance(
    Map<String, dynamic> payload,
  ) async {
    calls.add(payload);
    final record = await records.getById(payload['record_id'] as String);
    final committed = TrainingSessionRecord.fromCompletionTreeMap({
      ...record!.toCompletionTreeMap(),
      ...payload['completion_record'] as Map<String, dynamic>,
    });
    records.seedFromCompletionTrees([committed.toCompletionTreeMap()]);
    return {'status': 'committed', 'code': 'committed'};
  }
}
