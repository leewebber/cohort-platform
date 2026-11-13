import 'dart:async';
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
import 'package:cohort_platform/features/app_shell/athlete_app_shell.dart';
import 'package:cohort_platform/features/home/services/programme_adapt_flow.dart';
import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/performance_result_data.dart';
import 'package:cohort_platform/features/performance/models/training_block_result_status.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/performance/screens/training_history_detail_screen.dart';
import 'package:cohort_platform/features/performance/services/performance_record_save_coordinator.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_completion_store.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_store.dart';
import 'package:cohort_platform/features/session/controllers/session_execution_controller.dart';
import 'package:cohort_platform/features/session/screens/active_session_screen.dart';
import 'package:cohort_platform/features/session/services/production_restore_envelope_store.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_launcher.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/application/adaptation/approved_recovery_option.dart';
import 'package:cohort_platform/application/adaptation/approved_time_option.dart';
import 'package:cohort_platform/features/auth/models/user_profile.dart';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adaptation_planning_test_support.dart';
import '../../support/in_memory_programme_stores.dart';
import '../../support/programme_session_authoring_test_support.dart';
import '../../support/programme_schedule_test_fixtures.dart';

const _recoveryVersion = '7e1d15e7-20ee-46d4-b5e9-0d6449010330';
const _recoverySlot = '7e1d15e7-20ee-46d4-b5e9-0d6449010331';
const _recoveryOccurrence = '7e1d15e7-20ee-46d4-b5e9-0d6449010332';
const _recoverySlotKey = 'M32-W01-D01-STRENGTH';
const _recoveryPackageHash =
    'a8c76e1f4745929da17c9a929b169372c6475db21755f870dcb4100ead8d9050';

ProtocolDraft _recoveryTrialDraft() {
  final source = File(
    'docs/programmes/m32_time_trial/protocol-graphs.json',
  ).readAsStringSync();
  expect(
    sha256.convert(utf8.encode(source)).toString(),
    '707f67605d19a7cc92fd70dbf8dabd8dac7d16e57a98839757761c199452280b',
  );
  final graph = (jsonDecode(source) as List).single as Map<String, dynamic>;
  return ProtocolDraft(
    protocolId: graph['protocol_id'] as String,
    name: 'Private recovery strength fixture',
    steps: const [],
    durationMin: 45,
    blocks: [
      for (final row in (graph['blocks'] as List).cast<Map<String, dynamic>>())
        SessionBlock.fromRow(
          {...row, 'block_id': 'recovery-block-${row['position']}'},
          linkedExercises: [
            for (final exercise
                in (row['exercises'] as List).cast<Map<String, dynamic>>())
              SessionBlockExerciseLink.fromRow({
                ...exercise,
                'id':
                    'recovery-link-${row['position']}-${exercise['position']}',
              }),
          ],
        ),
    ],
  );
}

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

  Future<void> verifyAdaptationJourney(
    WidgetTester tester, {
    required AdaptationReason reason,
    bool finishEarly = false,
    bool keepOriginal = false,
  }) async {
    final forRecovery = reason == AdaptationReason.recovery;
    final forTime = reason == AdaptationReason.time;
    final forOmission = forTime || forRecovery;
    final journeyDraft = forRecovery
        ? _recoveryTrialDraft()
        : forTime
        ? buildApprovedTimeSession(protocolId: 'proto.time.fixture')
        : draft;
    final retainedIndex = forOmission ? 1 : 0;
    final recordedReps = forRecovery ? 8 : 5;
    final expectedExercise = forOmission
        ? 'Barbell bench press'
        : 'Goblet squat';
    tester.view.physicalSize = const Size(900, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(AthletePersistence.resetForTests);
    addTearDown(AthleteSessionMemoryStore.instance.clearAll);

    final athlete = forRecovery
        ? 'recovery-fixture-athlete'
        : forTime
        ? 'time-fixture-athlete'
        : 'equipment-fixture-athlete';
    final occurrenceId = forRecovery
        ? _recoveryOccurrence
        : 'fixture-occurrence';
    final slotId = forRecovery
        ? _recoverySlot
        : ProgrammeScheduleTestFixtures.slot1Id;
    const scheduledDay = '2026-11-09';
    if (forRecovery) {
      CurrentUserSession.bind(
        UserProfile(
          id: athlete,
          displayName: 'Recovery fixture athlete',
          isCoach: false,
          isAthlete: true,
        ),
      );
      addTearDown(CurrentUserSession.clear);
    }
    final tables = InMemoryProgrammeTables();
    final assignments = InMemoryProgrammeAssignmentStore(tables);
    final versions = InMemoryProgrammeVersionStore(tables);
    final assignment = ProgrammeScheduleTestFixtures.materialisedAssignment(
      athleteId: athlete,
      programmeVersionId: forRecovery ? _recoveryVersion : null,
      packageContentHash: forRecovery
          ? _recoveryPackageHash
          : 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    ).copyWith(scheduleMode: 'fixed_schedule');
    tables.assignments.add(assignment);
    final version = ProgrammeVersion(
      id: assignment.programmeVersionId,
      lineageId: ProgrammeScheduleTestFixtures.lineageId,
      versionNumber: 1,
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      libraryScope: forRecovery
          ? ProgrammeLibraryScope.coachPrivate
          : ProgrammeLibraryScope.cohortGlobal,
      ownerType: forRecovery
          ? ProgrammeOwnerType.coach
          : ProgrammeOwnerType.global,
      ownerId: forRecovery ? 'fixture-coach' : null,
      name: forTime ? 'Time fixture programme' : 'Equipment fixture programme',
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
              ProgrammeVersionSessionSlot(
                id: slotId,
                dayId: ProgrammeScheduleTestFixtures.day1Id,
                sessionOrder: 1,
                protocolId: journeyDraft.protocolId,
                packageSlotKey: forRecovery
                    ? _recoverySlotKey
                    : forTime
                    ? approvedTimeFixtureSlot
                    : null,
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
          occurrenceId: occurrenceId,
          sessionSlotId: resolved.slot.id,
          programmeVersionId: version.id,
          protocolId: journeyDraft.protocolId,
          programmedSessionKey: resolved.programmedSessionKey.value,
          weekNumber: 1,
          dayKey: 'day_1',
          sessionOrder: 1,
          scheduledDate: scheduledDay,
          originalScheduledDate: scheduledDay,
          state: resumed
              ? FixedProgrammeOccurrenceState.inProgress
              : FixedProgrammeOccurrenceState.today,
          sessionTitle: journeyDraft.name,
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
                  'change_kind': forTime
                      ? 'remove_optional_accessories'
                      : 'substitute_approved_equipment',
                  'target_ref': forTime ? approvedTimeFixtureSlot : 'programme',
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
    final original = forRecovery
        ? _packageFromDraft(journeyDraft).plan
        : forTime
        ? _packageFromDraft(
            journeyDraft,
            exercisesById: const {
              'BP-001': Exercise(
                exerciseId: 'BP-001',
                name: 'Barbell bench press',
                published: true,
              ),
              'ACC-001': Exercise(
                exerciseId: 'ACC-001',
                name: 'Accessory raise',
                published: true,
              ),
            },
          ).plan
        : package.plan;
    var recoveryApprovalId = 'm33-poor-sleep-omit-optional-lateral-raises';
    var approvedOccurrence = _recoveryOccurrence;
    var recoveryReadCount = 0;
    var today = scheduledDay;
    var authorityStarted = false;
    FixedProgrammeCalendarProjection calendarFor(
      FixedProgrammeOccurrenceProjection row,
    ) => FixedProgrammeCalendarProjection(
      assignmentId: assignment.id,
      programmeName: version.name,
      timezone: 'Asia/Makassar',
      scheduleMode: 'fixed_schedule',
      startDate: scheduledDay,
      today: today,
      weekStart: scheduledDay,
      weekEnd: '2026-11-15',
      occurrences: [row],
      currentWeek: [
        FixedProgrammeCalendarDayProjection(
          date: row.scheduledDate,
          state: row.state,
          occurrence: row,
        ),
      ],
    );
    Future<ApprovedRecoveryOption?> loadRecoveryApproval(
      ProgrammeExecutionContext context,
    ) async {
      recoveryReadCount++;
      expect(context.occurrenceId, _recoveryOccurrence);
      if (!permitted) return null;
      return ApprovedRecoveryOption(
        athleteId: athlete,
        assignmentId: assignment.id,
        versionId: _recoveryVersion,
        slotId: _recoverySlot,
        occurrenceId: approvedOccurrence,
        scheduledDate: scheduledDay,
        originalPlan: original,
        omission: ApprovedAccessoryOmission.fromJson({
          'permission_key': recoveryApprovalId,
          'slot_key': _recoverySlotKey,
          'protocol_id': journeyDraft.protocolId,
          'package_hash': _recoveryPackageHash,
          'full_minutes': 45,
          'short_minutes': 30,
          'omitted_block_position': 3,
          'session_intent': 'upper_body_strength',
        }),
      );
    }

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
        fixedOccurrenceStore: forRecovery
            ? _LiveProjectionStore(
                () => calendarFor(
                  occurrence(resumed: resumed || authorityStarted),
                ),
              )
            : null,
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
      final launcher = ProgrammeSessionExecutionLauncher(
        startStore: start,
        sessionExecutionLauncher: SessionExecutionLauncher(
          saveCoordinator: coordinator,
          restoreEnvelopeStore: ProductionRestoreEnvelopeStore(),
        ),
      );
      final resumedOccurrence = occurrence(resumed: true);
      await tester.pumpWidget(
        MaterialApp(
          home: resumed
              ? AthleteAppShell(
                  athleteIdOverride: athlete,
                  assignmentStore: assignments,
                  fixedOccurrenceStore: _ResumeProjectionStore(
                    FixedProgrammeCalendarProjection(
                      assignmentId: assignment.id,
                      programmeName: version.name,
                      timezone: 'Asia/Makassar',
                      scheduleMode: 'fixed_schedule',
                      startDate: '2026-11-09',
                      today: '2026-11-09',
                      weekStart: '2026-11-09',
                      weekEnd: '2026-11-15',
                      occurrences: [resumedOccurrence],
                      currentWeek: [
                        FixedProgrammeCalendarDayProjection(
                          date: resumedOccurrence.scheduledDate,
                          state: resumedOccurrence.state,
                          occurrence: resumedOccurrence,
                        ),
                      ],
                    ),
                  ),
                  prepareService: prepare,
                  executionLauncher: launcher,
                  performanceRecordStore: records,
                )
              : Scaffold(
                  body: AthleteProgrammeTodaySection(
                    athleteId: athlete,
                    fixedAssignment: assignment,
                    fixedOccurrence: occurrence(resumed: resumed),
                    prepareService: prepare,
                    adaptFlow: ProgrammeAdaptFlow.forPreparedSession(
                      prepareService: prepare,
                      loadAdaptationPermissions: permissionReader.load,
                      loadRecoveryApproval: forRecovery
                          ? loadRecoveryApproval
                          : null,
                      loadProtocolDraft: (id) async {
                        expect(id, journeyDraft.protocolId);
                        return journeyDraft;
                      },
                      loadKnowledge: () async => knowledge,
                    ),
                    executionLauncher: launcher,
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

    Future<void> review({String recoveryAnswer = 'Poor Sleep'}) async {
      await tap('Adapt Session');
      if (forRecovery) {
        await tap('Recovery');
        await tap(recoveryAnswer);
      } else if (forTime) {
        await tap('Time');
        await tap('30');
      } else {
        await tap('Equipment');
        await tap('Kettlebell');
        await tap('Bodyweight');
        await tap('Continue');
      }
    }

    await mount(resumed: false);
    final key = resolved.programmedSessionKey.value;
    final preparedKey = PersistenceKeys.generatedSession(athlete);
    final originalBytes = kv.debugDump[preparedKey];
    expect(originalBytes, isNotNull);

    await review();
    expect(
      find.textContaining(
        forRecovery
            ? 'No approved recovery adjustment for this workout.'
            : forTime
            ? 'No coach-approved shorter option'
            : 'Authored adaptation permissions do not permit equipment',
      ),
      findsOneWidget,
    );
    expect(find.text('Accept Adaptation'), findsNothing);
    await tap('Keep Original Session');
    expect(kv.debugDump[preparedKey], originalBytes);
    expect(prepare.cachedPackageForKey(key)!.acceptedAdaptation, isNull);

    permitted = true;
    if (forRecovery) {
      approvedOccurrence = 'different-occurrence';
      await review();
      expect(find.text('Accept Adaptation'), findsNothing);
      await tap('Keep Original Session');
      expect(kv.debugDump[preparedKey], originalBytes);
      approvedOccurrence = _recoveryOccurrence;
      for (final answer in ['Slightly Tired', 'Very Fatigued', 'Feeling Ill']) {
        final before = recoveryReadCount;
        await review(recoveryAnswer: answer);
        expect(find.text('Accept Adaptation'), findsNothing);
        expect(recoveryReadCount, before);
        await tap('Keep Original Session');
      }
    }
    await review();
    if (forRecovery) {
      expect(find.text('You reported poor sleep'), findsOneWidget);
      expect(
        find.textContaining('bench press 4 × 8 with 120 seconds’ rest'),
        findsOneWidget,
      );
    }
    expect(
      find.textContaining(
        forRecovery
            ? '45 → 30 min estimated'
            : forTime
            ? 'Estimated session duration 45m → 30m'
            : 'Back squat → Goblet squat',
      ),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    expect(
      find.textContaining(
        forRecovery
            ? 'Skip optional lateral raises'
            : forTime
            ? 'Omit Optional upper-body accessories. All remaining sets, reps and rests stay as prescribed.'
            : 'Reduces absolute load potential',
      ),
      findsOneWidget,
    );
    expect(kv.debugDump[preparedKey], originalBytes);
    await tap('Keep Original Session');
    expect(kv.debugDump[preparedKey], originalBytes);
    expect(prepare.cachedPackageForKey(key)!.acceptedAdaptation, isNull);
    expect(start.calls, isEmpty);

    if (forRecovery) {
      Future<void> refusesAfter(
        FutureOr<void> Function() change,
        FutureOr<void> Function() restore,
      ) async {
        await review();
        expect(find.text('Accept Adaptation'), findsOneWidget);
        await change();
        await tap('Accept Adaptation');
        expect(find.textContaining('could not revalidate'), findsOneWidget);
        expect(prepare.cachedPackageForKey(key)!.acceptedAdaptation, isNull);
        await restore();
        expect(kv.debugDump[preparedKey], originalBytes);
        await tap('OK');
      }

      await refusesAfter(
        () => recoveryApprovalId = 'different-recovery-approval',
        () =>
            recoveryApprovalId = 'm33-poor-sleep-omit-optional-lateral-raises',
      );
      await refusesAfter(
        () => today = '2026-11-10',
        () => today = scheduledDay,
      );
      await refusesAfter(
        () => authorityStarted = true,
        () => authorityStarted = false,
      );
      await refusesAfter(
        () => CurrentUserSession.bind(
          const UserProfile(
            id: 'different-athlete',
            displayName: 'Different athlete',
            isCoach: false,
            isAthlete: true,
          ),
        ),
        () => CurrentUserSession.bind(
          UserProfile(
            id: athlete,
            displayName: 'Recovery fixture athlete',
            isCoach: false,
            isAthlete: true,
          ),
        ),
      );
      await refusesAfter(() {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }, () {});
      await refusesAfter(
        () => kv.remove(preparedKey),
        () => kv.writeString(preparedKey, originalBytes!),
      );
      await review();
      await tap('Cancel');
      expect(kv.debugDump[preparedKey], originalBytes);
      expect(start.calls, isEmpty);
    }

    if (!keepOriginal) {
      await review();
      await tap('Accept Adaptation');
      expect(
        permissionReads,
        forRecovery ? isEmpty : List.filled(4, 'eq.${version.id}'),
      );
      final accepted = prepare.cachedPackageForKey(key)!;
      expect(accepted.acceptedAdaptation, isNotNull);
      final retained = accepted.plan.blocks[retainedIndex];
      if (forOmission) {
        expect(accepted.plan.durationMin, 30);
        expect(accepted.acceptedAdaptation!.reasonCode, reason.name);
        expect(accepted.plan.blocks, original.blocks.take(2).toList());
        expect(accepted.acceptedAdaptation!.exerciseChanges, isEmpty);
      } else {
        expect(
          retained.linkedExercises.single.exerciseId,
          JourneyDEquipmentAdaptationContract.replacementExerciseId,
        );
        expect(accepted.plan.blocks.last, same(original.blocks.last));
      }
      expect(
        retained.linkedExercises.single.prescription!.toJson(),
        original.blocks[retainedIndex].linkedExercises.single.prescription!
            .toJson(),
      );
    }
    expect(
      assignment.toUpdateMap(),
      (await assignments.getById(assignment.id))!.toUpdateMap(),
    );

    await tap('Begin');
    expect(
      find.byType(ActiveSessionScreen),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    var screen = tester.widget<ActiveSessionScreen>(
      find.byType(ActiveSessionScreen),
    );
    expect(screen.trainingSessionId, 91);
    expect(find.text('Finish early'), findsNothing);
    if (forOmission) {
      final blockCount = keepOriginal ? 3 : 2;
      expect(find.text('Block 1 of $blockCount'), findsOneWidget);
      expect(
        find.text('1. Walk at an easy pace for 5 minutes.'),
        findsOneWidget,
      );
      expect(
        find.text('Optional upper-body accessories'),
        keepOriginal ? findsOneWidget : findsNothing,
      );
      if (finishEarly) {
        await tap('Next >');
      } else {
        await tap('Mark block complete');
        expect(screen.controller.state.completedBlockIds, {
          screen.controller.state.plan.blocks.first.blockId,
        });
      }
      expect(find.text('Block 2 of $blockCount'), findsOneWidget);
      expect(find.text('Barbell bench press'), findsOneWidget);
      expect(find.text('4 × 8'), findsOneWidget);
      expect(find.text('Rest 2 min'), findsOneWidget);
    }
    final initialDraft = screen.performanceController.draft;
    final workingBlock = initialDraft.blockDrafts[retainedIndex];
    final workingExercise = workingBlock.exerciseResults.single;
    final setId = workingExercise.sets.first.setResultId;
    expect(workingExercise.exerciseSnapshot.displayName, expectedExercise);
    screen.performanceController.updateSet(
      workingBlock.sourceBlockId,
      workingExercise.sourceExerciseId,
      setId,
      (set) => set.copyWith(
        reps: recordedReps,
        load: 16,
        loadUnit: 'kg',
        completed: true,
      ),
    );
    final savedActiveBlock = screen.controller.state.activeBlockIndex;
    final savedCompletedBlocks = screen.controller.state.completedBlockIds;
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
    expect(start.calls, hasLength(1));
    expect(find.text('Begin'), findsNothing);
    expect(find.text('Adapt Session'), findsNothing);
    expect(find.text('Revert to Original'), findsNothing);
    await tap('Resume');
    screen = tester.widget<ActiveSessionScreen>(
      find.byType(ActiveSessionScreen),
    );
    expect(start.calls.map((call) => call['occurrence_id']), [
      occurrenceId,
      occurrenceId,
    ]);
    expect(screen.trainingSessionId, 91);
    expect(screen.programmeContext?.occurrenceId, occurrenceId);
    expect(screen.controller.state.activeBlockIndex, savedActiveBlock);
    expect(screen.controller.state.completedBlockIds, savedCompletedBlocks);
    expect(screen.performanceController.draft.recordId, initialDraft.recordId);
    expect(records.exportCompletionTrees(), hasLength(1));
    if (forRecovery) {
      expect(
        prepare.cachedPackageForKey(key)!.acceptedAdaptation!.reasonCode,
        AdaptationReason.recovery.name,
      );
    }
    final restoredDraft = screen.performanceController.draft;
    if (forOmission) {
      expect(
        restoredDraft.blockDrafts.map((b) => b.sourceBlockId),
        original.blocks.take(keepOriginal ? 3 : 2).map((b) => b.blockId),
      );
      expect(
        prepare
            .cachedPackageForKey(key)!
            .plan
            .blocks[1]
            .linkedExercises
            .single
            .prescription!
            .toJson(),
        original.blocks[1].linkedExercises.single.prescription!.toJson(),
      );
    }
    final restored =
        restoredDraft.blockDrafts[retainedIndex].exerciseResults.single;
    expect(restored.sourceExerciseId, workingExercise.sourceExerciseId);
    expect(restored.exerciseSnapshot.displayName, expectedExercise);
    expect(restored.sets.first.setResultId, setId);
    expect(restored.sets.first.reps, recordedReps);
    expect(restored.sets.first.load, 16);
    expect(restored.sets.first.loadUnit, 'kg');
    expect(restored.sets.first.completed, isTrue);

    if (finishEarly) {
      final unfinished = screen.performanceController.draft.blockDrafts
          .map((block) => block.status)
          .toList();
      await tap('Finish early');
      expect(find.text('Save and finish early'), findsOneWidget);
      await tap('Return to session');
      expect(completion.calls, isEmpty);
      expect(
        screen.performanceController.draft.blockDrafts.map(
          (block) => block.status,
        ),
        unfinished,
      );
      await tap('Finish early');
    } else {
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
                reps: recordedReps,
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
    }
    expect(find.text('Review Session'), findsOneWidget);
    if (!forOmission) {
      expect(find.textContaining('Back squat → Goblet squat'), findsOneWidget);
    }
    await tap(finishEarly ? 'Save and finish early' : 'Save and finish');
    expect(find.text('Session saved'), findsOneWidget);
    if (finishEarly) {
      expect(find.text('Session finished early'), findsOneWidget);
      expect(completion.calls.single['status'], 'partially_completed');
    }
    if (!forOmission) {
      expect(find.textContaining('Back squat → Goblet squat'), findsOneWidget);
    }
    expect(completion.calls, hasLength(1));
    expect(completion.calls.single['protocol_id'], journeyDraft.protocolId);
    expect(completion.calls.single['occurrence_id'], occurrenceId);

    final history = await coordinator.listHistory(athleteId: athlete);
    expect(history, hasLength(1));
    expect(history.single.recordId, initialDraft.recordId);
    if (finishEarly) {
      expect(
        history.single.status,
        TrainingSessionRecordStatus.partiallyCompleted,
      );
      expect(
        history.single.blockResults.every(
          (block) => block.status == TrainingBlockResultStatus.notStarted,
        ),
        isTrue,
      );
      final warmUp = history.single.blockResults.first.resultData;
      if (warmUp is CompletionResultData) expect(warmUp.completed, isFalse);
    }

    if (forOmission) {
      expect(
        history.single.blockResults.map((b) => b.sourceBlockId),
        original.blocks.take(keepOriginal ? 3 : 2).map((b) => b.blockId),
      );
    }
    final result =
        history.single.blockResults[retainedIndex].exerciseResults.single;
    expect(result.sourceExerciseId, workingExercise.sourceExerciseId);
    expect(result.exerciseSnapshot.displayName, expectedExercise);
    expect(result.setResults.first.load, 16);
    expect(result.setResults.first.reps, recordedReps);
    if (finishEarly) {
      expect(result.setResults.first.reps, 5);
      expect(result.setResults.skip(1).every((set) => !set.completed), isTrue);
    }
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
    expect(find.text(expectedExercise), findsOneWidget);
    expect(
      find.text(forOmission ? 'Optional upper-body accessories' : 'Back squat'),
      keepOriginal ? findsOneWidget : findsNothing,
    );
  }

  testWidgets(
    'equipment review, accept, cold restore and programme History',
    (tester) =>
        verifyAdaptationJourney(tester, reason: AdaptationReason.equipment),
  );
  testWidgets(
    'approved time option review, accept, cold restore and programme History',
    (tester) => verifyAdaptationJourney(tester, reason: AdaptationReason.time),
  );

  testWidgets(
    'Poor Sleep on the exact private occurrence reviews, accepts, restores and completes',
    (tester) =>
        verifyAdaptationJourney(tester, reason: AdaptationReason.recovery),
  );

  for (final keepOriginal in [true, false]) {
    testWidgets(
      'finish early preserves actuals in the ${keepOriginal ? 'ordinary' : 'adapted'} workout',
      (tester) => verifyAdaptationJourney(
        tester,
        reason: AdaptationReason.time,
        finishEarly: true,
        keepOriginal: keepOriginal,
      ),
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
    test(
      'time approval does not authorise a planner-generated set cut',
      () async {
        final option = buildApprovedTimeSession(protocolId: 'proto.time.reg');
        final generic = buildTimedPlanningSession(
          protocolId: option.protocolId,
        );
        final timed = option.copyWith(
          blocks: [
            option.blocks[0],
            option.blocks[1].copyWith(
              adaptationPolicy: generic.blocks[1].adaptationPolicy,
            ),
            option.blocks[2],
          ],
        );
        final timedPackage = _packageFromDraft(timed);
        const timeRequest = AdaptationRequest(
          reason: AdaptationReason.time,
          availableMinutes: 30,
        );
        final unguarded = PlanPackageSessionAdaptationAdapter().pipeline.run(
          plannedSession:
              PlannedSessionAdaptationInputAdapter.fromProtocolDraft(timed),
          constraints: AdaptationRequestConstraintMapper.fromRequest(
            timeRequest,
          ),
        );
        expect(
          unguarded.plan.steps.map((step) => step.actionType),
          contains(AdaptationActionType.reduceVolume),
        );
        final proposal =
            await ProgrammeAdaptationProposalService(
              knowledge: knowledge,
              loadProtocolDraft: (_) async => timed,
              loadAdaptationPermissions: (_) async => const [
                approvedTimeFixturePermission,
              ],
            ).propose(
              package: timedPackage,
              slotKey: approvedTimeFixtureSlot,
              request: timeRequest,
            );
        expect(proposal.isAcceptable, isFalse);
      },
    );

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

PreparedExecutionPackage _packageFromDraft(
  ProtocolDraft draft, {
  Map<String, Exercise> exercisesById = const {},
}) {
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
            exercisesById: exercisesById,
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

class _LiveProjectionStore implements FixedProgrammeOccurrenceProjectionStore {
  _LiveProjectionStore(this.read);

  final FixedProgrammeCalendarProjection Function() read;

  @override
  Future<FixedProgrammeCalendarProjection> resolveActive() async => read();

  @override
  Future<FixedProgrammeCalendarProjection> resolveForAssignment(
    String assignmentId,
  ) => resolveAssignmentFromActiveFallback(this, assignmentId);
}

class _ResumeProjectionStore
    implements FixedProgrammeOccurrenceProjectionStore {
  _ResumeProjectionStore(this.calendar);

  final FixedProgrammeCalendarProjection calendar;

  @override
  Future<FixedProgrammeCalendarProjection> resolveActive() async => calendar;

  @override
  Future<FixedProgrammeCalendarProjection> resolveForAssignment(
    String assignmentId,
  ) => resolveAssignmentFromActiveFallback(this, assignmentId);
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
