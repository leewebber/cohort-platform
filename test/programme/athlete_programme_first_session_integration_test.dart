import 'dart:async';

import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/core/persistence/session_execution_plan_codec.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_store.dart';
import 'package:cohort_platform/features/home/controllers/home_today_session_refresh_controller.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/plans/models/programmed_session_key.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/errors/programme_schedule_exception.dart';
import 'package:cohort_platform/features/programme/models/athlete_plan_materialisation.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_prepared_session.dart';
import 'package:cohort_platform/features/programme/services/athlete_plan_materialisation_service.dart';
import 'package:cohort_platform/features/programme/services/athlete_plan_materialisation_store.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/workout_player/models/workout_session_brief.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

class _PendingAssignmentStore implements ProgrammeAssignmentStore {
  _PendingAssignmentStore(this._future);

  final Future<ProgrammeAssignment?> _future;

  @override
  Future<ProgrammeAssignment?> getActiveAssignment(String athleteId) => _future;

  @override
  Future<ProgrammeAssignment?> getById(String assignmentId) async => null;

  @override
  Future<ProgrammeAssignment> insert(ProgrammeAssignment assignment) {
    throw UnimplementedError();
  }

  @override
  Future<ProgrammeAssignment> update(ProgrammeAssignment assignment) {
    throw UnimplementedError();
  }

  @override
  Future<List<ProgrammeAssignment>> listForAthlete(String athleteId) async =>
      const [];

  @override
  Future<int> countAssignmentsForVersion(String programmeVersionId) async => 0;
}

const _hashExact =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';
const _hashOther =
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
const _protocolId = 'BW-001';

ProgrammeVersion _publishedVersion({
  String id = ProgrammeScheduleTestFixtures.versionId,
  String? hash = _hashExact,
}) {
  return ProgrammeVersion(
    id: id,
    lineageId: ProgrammeScheduleTestFixtures.lineageId,
    versionNumber: 1,
    lifecycleStatus: ProgrammeLifecycleStatus.published,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    name: 'S14B Programme',
    approvedForGlobal: true,
    packageContentHash: hash,
  );
}

ProgrammeAssignment _materialised({
  String id = ProgrammeScheduleTestFixtures.assignmentId,
  String athleteId = 'athlete-1',
  String versionId = ProgrammeScheduleTestFixtures.versionId,
  String hash = _hashExact,
  int week = 1,
  String dayKey = 'day_1',
  int slot = 1,
  ProgrammeAssignmentStatus status = ProgrammeAssignmentStatus.active,
}) {
  return ProgrammeScheduleTestFixtures.assignment(
    id: id,
    athleteId: athleteId,
    programmeVersionId: versionId,
    week: week,
    dayKey: dayKey,
    slotOrder: slot,
  ).copyWith(
    lineageCode: 'PROG-S14B',
    status: status,
    startedAt: DateTime.utc(2026, 7, 31),
    materialisedAt: DateTime.utc(2026, 7, 31, 12),
    materialisationSource: 'athlete_start_programme',
    materialisedPackageContentHash: hash,
  );
}

SessionExecutionPlan _executablePlan({String protocolId = _protocolId}) {
  return SessionExecutionPlan(
    sessionId: protocolId,
    sessionTitle: 'Authored Session',
    durationMin: 45,
    blocks: [
      SessionExecutionBlock(
        blockId: 'b1',
        title: 'Strength',
        blockType: SessionBlockType.strength,
        content: 'Work',
        workoutFormat: WorkoutFormat.none,
        position: 0,
        linkedExercises: const [
          SessionExecutionExerciseSummary(
            exerciseId: 'SQ-001',
            displayName: 'Squat',
          ),
        ],
      ),
    ],
  );
}

class _FixedLoader extends SessionExecutionLoader {
  _FixedLoader(this.plan) : super();

  final SessionExecutionPlan plan;
  int loadCalls = 0;
  String? lastProtocolId;

  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    loadCalls++;
    lastProtocolId = protocolId;
    return SessionExecutionLoadResult(plan: plan);
  }
}

Future<void> _seedTree(
  InMemoryProgrammeTables tables, {
  ProgrammeVersion? version,
}) async {
  final v = version ?? _publishedVersion();
  final tree = ProgrammeScheduleTestFixtures.foundationWeekOneTree(
    programmeVersionId: v.id,
  );
  await InMemoryProgrammeVersionStore(
    tables,
  ).saveTemplateTree(version: v, tree: tree);
  // saveDraftVersion may not retain published/hash — reassert authority.
  final index = tables.versions.indexWhere((row) => row.id == v.id);
  if (index >= 0) {
    tables.versions[index] = v;
  } else {
    tables.versions.add(v);
  }
}

void main() {
  group('ProgrammedSessionKey programme shape', () {
    test('materialised assignment maps to stable programme key', () {
      final assignment = _materialised();
      final key = ProgrammedSessionKey.fromMaterialisedProgramme(
        assignment: assignment,
        protocolId: _protocolId,
        packageContentHash: _hashExact,
      );

      expect(key.isProgrammeShaped, isTrue);
      expect(key.programmeAssignmentId, assignment.id);
      expect(key.planVersion, assignment.programmeVersionId);
      expect(key.week, 1);
      expect(key.dayKey, 'day_1');
      expect(key.slotOrder, 1);
      expect(key.protocolId, _protocolId);
      expect(key.packageContentHash, _hashExact);
      expect(
        key.value,
        'prog:${assignment.id}@${assignment.programmeVersionId}:w1:day_1:s1:$_protocolId',
      );

      final again = ProgrammedSessionKey.fromMaterialisedProgramme(
        assignment: assignment,
        protocolId: _protocolId,
        packageContentHash: _hashExact,
      );
      expect(again, key);
      expect(ProgrammedSessionKey.parse(key.value), key);
    });

    test('does not use Plan Library identifier as substitute', () {
      final key = ProgrammedSessionKey.fromMaterialisedProgramme(
        assignment: _materialised(),
        protocolId: _protocolId,
        packageContentHash: _hashExact,
      );
      expect(key.value.startsWith('prog:'), isTrue);
      expect(key.value.contains('plan.'), isFalse);
    });
  });

  group('AthleteProgrammeAuthoredSlotResolver', () {
    late InMemoryProgrammeTables tables;
    late AthleteProgrammeAuthoredSlotResolver resolver;

    setUp(() async {
      tables = InMemoryProgrammeTables();
      await _seedTree(tables);
      resolver = AthleteProgrammeAuthoredSlotResolver(
        versionStore: InMemoryProgrammeVersionStore(tables),
      );
    });

    test('resolves week 1 / day_1 / slot 1 against exact version', () async {
      final resolved = await resolver.resolve(_materialised());
      expect(resolved.slot.protocolId, _protocolId);
      expect(resolved.programmedSessionKey.week, 1);
      expect(resolved.programmedSessionKey.dayKey, 'day_1');
      expect(resolved.programmedSessionKey.slotOrder, 1);
      expect(
        resolved.programmedSessionKey.planVersion,
        ProgrammeScheduleTestFixtures.versionId,
      );
      expect(resolved.assignment.materialisedPackageContentHash, _hashExact);
    });

    test('fails closed on missing exact version', () async {
      await expectLater(
        resolver.resolve(_materialised(versionId: 'missing-version')),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (e) => e.code,
            'code',
            ProgrammeScheduleErrorCode.missingProgrammeVersion,
          ),
        ),
      );
    });

    test('fails closed on package hash mismatch', () async {
      await expectLater(
        resolver.resolve(_materialised(hash: _hashOther)),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (e) => e.code,
            'code',
            ProgrammeScheduleErrorCode.packageHashMismatch,
          ),
        ),
      );
    });

    test('fails closed on invalid week/day/slot', () async {
      await expectLater(
        resolver.resolve(_materialised(week: 99)),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (e) => e.code,
            'code',
            ProgrammeScheduleErrorCode.missingCurrentWeek,
          ),
        ),
      );
      await expectLater(
        resolver.resolve(_materialised(dayKey: 'day_99')),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (e) => e.code,
            'code',
            ProgrammeScheduleErrorCode.missingCurrentDay,
          ),
        ),
      );
      await expectLater(
        resolver.resolve(_materialised(slot: 9)),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (e) => e.code,
            'code',
            ProgrammeScheduleErrorCode.missingCurrentSlot,
          ),
        ),
      );
    });

    test('does not fall back to latest version', () async {
      final latest = _publishedVersion(id: 'version-latest', hash: _hashOther);
      tables.versions.add(latest);
      await expectLater(
        resolver.resolve(
          _materialised(versionId: 'version-gone', hash: _hashExact),
        ),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (e) => e.code,
            'code',
            ProgrammeScheduleErrorCode.missingProgrammeVersion,
          ),
        ),
      );
    });

    test('inactive assignment is rejected', () async {
      await expectLater(
        resolver.resolve(
          _materialised(status: ProgrammeAssignmentStatus.paused),
        ),
        throwsA(
          isA<ProgrammeScheduleException>().having(
            (e) => e.code,
            'code',
            ProgrammeScheduleErrorCode.assignmentNotActive,
          ),
        ),
      );
    });
  });

  group('AthleteProgrammeSessionPrepareService', () {
    late InMemoryProgrammeTables tables;
    late AthleteLocalRepository localRepo;
    late _FixedLoader loader;
    late AthleteProgrammeSessionPrepareService service;
    late ProgrammeAssignment assignment;

    setUp(() async {
      tables = InMemoryProgrammeTables();
      await _seedTree(tables);
      assignment = _materialised();
      tables.assignments.add(assignment);
      localRepo = AthleteLocalRepository(InMemoryKvStore());
      loader = _FixedLoader(_executablePlan());
      service = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: loader,
        localRepository: localRepo,
      );
    });

    test('prepares deterministic package with provenance', () async {
      final result = await service.prepareForAthlete('athlete-1');
      expect(result.isReady, isTrue);
      expect(result.status, AthleteProgrammePrepareStatus.prepared);
      final package = result.package!;
      expect(package.isProgrammeBacked, isTrue);
      expect(package.assignmentId, assignment.id);
      expect(package.programmeVersionId, assignment.programmeVersionId);
      expect(package.packageContentHash, _hashExact);
      expect(package.dayKey, 'day_1');
      expect(package.slotOrder, 1);
      expect(package.protocolId, _protocolId);
      expect(package.coachBrainPlan, isNull);
      expect(loader.loadCalls, 1);
      expect(loader.lastProtocolId, _protocolId);
    });

    test('repeated prepare is idempotent (memory + local restore)', () async {
      final first = await service.prepareForAthlete('athlete-1');
      final second = await service.prepareForAthlete('athlete-1');
      expect(second.status, AthleteProgrammePrepareStatus.restored);
      expect(
        second.package!.programmedSessionKey.value,
        first.package!.programmedSessionKey.value,
      );
      expect(
        second.package!.plan.sessionTitle,
        first.package!.plan.sessionTitle,
      );
      expect(loader.loadCalls, 1);
    });

    test('restores same logical package after service restart', () async {
      final first = await service.prepareForAthlete('athlete-1');
      expect(first.isReady, isTrue);

      final restarted = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: loader,
        localRepository: localRepo,
      );
      final restored = await restarted.prepareForAthlete('athlete-1');
      expect(restored.status, AthleteProgrammePrepareStatus.restored);
      expect(
        restored.package!.programmedSessionKey,
        first.package!.programmedSessionKey,
      );
      expect(loader.loadCalls, 1);
    });

    test('reconstructs when local provenance mismatches', () async {
      await service.prepareForAthlete('athlete-1');
      final corrupt = GeneratedSessionRecord(
        athleteId: 'athlete-1',
        intendedTrainingDate: DateTime.utc(2026, 7, 31),
        generatedAt: DateTime.utc(2026, 7, 31),
        plan: _executablePlan(),
        brief: const WorkoutSessionBrief(sessionName: 'Corrupt'),
        assignmentId: 'other-assignment',
        programmeVersionId: assignment.programmeVersionId,
        packageContentHash: _hashExact,
        programmedSessionKey: 'prog:other@x:w1:day_1:s1:BW-001',
        dayKey: 'day_1',
        slotOrder: 1,
        protocolId: _protocolId,
      );
      await localRepo.saveGeneratedSession(corrupt);

      final result = await AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: loader,
        localRepository: localRepo,
      ).prepareForAthlete('athlete-1');

      expect(result.status, AthleteProgrammePrepareStatus.reconstructed);
      expect(result.package!.assignmentId, assignment.id);
      expect(loader.loadCalls, 2);
    });

    test('rejects cross-assignment restore without reconstruct', () async {
      await service.prepareForAthlete('athlete-1');
      await localRepo.saveGeneratedSession(
        GeneratedSessionRecord(
          athleteId: 'athlete-1',
          intendedTrainingDate: DateTime.utc(2026, 7, 31),
          generatedAt: DateTime.utc(2026, 7, 31),
          plan: _executablePlan(),
          brief: const WorkoutSessionBrief(sessionName: 'Other'),
          assignmentId: 'cross-assignment',
          programmeVersionId: assignment.programmeVersionId,
          packageContentHash: _hashExact,
          programmedSessionKey: 'prog:cross@x:w1:day_1:s1:BW-001',
          dayKey: 'day_1',
          slotOrder: 1,
        ),
      );

      final fresh = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: loader,
        localRepository: localRepo,
      );
      final rejected = await fresh.prepareForAthlete(
        'athlete-1',
        allowReconstruct: false,
      );
      expect(rejected.isReady, isFalse);
      expect(rejected.code, 'restore_rejected');
    });

    test('enrolled-only and inactive are not prepared', () async {
      tables.assignments
        ..clear()
        ..add(ProgrammeScheduleTestFixtures.assignment(athleteId: 'athlete-1'));
      final enrolled = await service.prepareForAthlete('athlete-1');
      expect(enrolled.status, AthleteProgrammePrepareStatus.notMaterialised);

      final inactiveAssignment = _materialised(
        status: ProgrammeAssignmentStatus.paused,
      );
      final inactive = await service.prepareForAssignment(inactiveAssignment);
      expect(inactive.status, AthleteProgrammePrepareStatus.inactive);
      expect(loader.loadCalls, 0);
    });

    test('hash mismatch fails closed without Coach Brain', () async {
      tables.assignments
        ..clear()
        ..add(_materialised(hash: _hashOther));
      final result = await service.prepareForAthlete('athlete-1');
      expect(result.status, AthleteProgrammePrepareStatus.hashMismatch);
      expect(result.package, isNull);
      expect(loader.loadCalls, 0);
    });

    test('openable plan wraps without Coach Brain generate', () async {
      final result = await service.prepareForAthlete('athlete-1');
      final openable = service.toOpenablePlan(result.package!);
      expect(openable.plan.sessionId, _protocolId);
      expect(result.package!.coachBrainPlan, isNull);
    });

    test('does not advance cursor or create completion', () async {
      await service.prepareForAthlete('athlete-1');
      await service.prepareForAthlete('athlete-1');
      final after = tables.assignments.single;
      expect(after.currentWeek, 1);
      expect(after.currentDayKey, 'day_1');
      expect(after.currentSessionOrder, 1);
      expect(after.programmeVersionId, assignment.programmeVersionId);
      expect(after.materialisedPackageContentHash, _hashExact);
      expect(after.startedAt, assignment.startedAt);
      expect(after.lastProgressedTrainingSessionId, isNull);
    });
  });

  group('Self-Test 1 local acceptance journey', () {
    test('reconcile → prepare → discard → restore same package', () async {
      final tables = InMemoryProgrammeTables();
      await _seedTree(tables);
      final assignment = _materialised();
      tables.assignments.add(assignment);
      final localRepo = AthleteLocalRepository(InMemoryKvStore());
      final loader = _FixedLoader(_executablePlan());

      // 1–2. Active materialised programme reconciled from persistence.
      final store = InMemoryProgrammeAssignmentStore(tables);
      final reconciled = await store.getActiveAssignment('athlete-1');
      expect(reconciled, isNotNull);
      expect(reconciled!.isMaterialised, isTrue);
      expect(reconciled.currentWeek, 1);
      expect(reconciled.currentDayKey, 'day_1');
      expect(reconciled.currentSessionOrder, 1);

      // 3–5. Resolve key and prepare package.
      final prepare = AthleteProgrammeSessionPrepareService(
        assignmentStore: store,
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: loader,
        localRepository: localRepo,
      );
      final prepared = await prepare.prepareForAssignment(reconciled);
      expect(prepared.isReady, isTrue);
      expect(prepared.programmedSessionKey!.week, 1);
      expect(prepared.programmedSessionKey!.dayKey, 'day_1');
      expect(prepared.programmedSessionKey!.slotOrder, 1);
      expect(prepared.package!.coachBrainPlan, isNull);

      final keyValue = prepared.programmedSessionKey!.value;
      final title = prepared.package!.plan.sessionTitle;

      // 8–10. Discard in-memory service; restore from local persistence.
      final afterRestart = AthleteProgrammeSessionPrepareService(
        assignmentStore: store,
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: loader,
        localRepository: localRepo,
      );
      final restored = await afterRestart.prepareForAthlete('athlete-1');
      expect(restored.status, AthleteProgrammePrepareStatus.restored);
      expect(restored.programmedSessionKey!.value, keyValue);
      expect(restored.package!.plan.sessionTitle, title);

      // 11–13. No completion / no cursor advance / no latest substitution.
      final still = tables.assignments.single;
      expect(still.currentWeek, 1);
      expect(still.currentDayKey, 'day_1');
      expect(still.currentSessionOrder, 1);
      expect(still.lastProgressedTrainingSessionId, isNull);
      expect(still.programmeVersionId, assignment.programmeVersionId);
      expect(loader.loadCalls, 1);
    });
  });

  group('Home/today programme integration widgets', () {
    testWidgets('home unchanged without materialised programme', (
      tester,
    ) async {
      final tables = InMemoryProgrammeTables();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Choose a programme'), findsOneWidget);
      expect(find.text('VIEW PROGRAMMES'), findsOneWidget);
      expect(find.byType(AthleteProgrammeTodaySection), findsNothing);
      expect(find.textContaining('subscription'), findsNothing);
      expect(find.textContaining('Coach Brain'), findsNothing);
    });

    testWidgets('home shows checking programme while gate loads', (
      tester,
    ) async {
      final pending = Completer<ProgrammeAssignment?>();
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: _PendingAssignmentStore(pending.future),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Checking programme…'), findsOneWidget);
      expect(find.text('Choose a programme'), findsNothing);
      expect(find.byType(AthleteProgrammeTodaySection), findsNothing);

      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Choose a programme'), findsOneWidget);
      expect(find.text('Checking programme…'), findsNothing);
    });

    testWidgets('materialised first session appears when prepared', (
      tester,
    ) async {
      final tables = InMemoryProgrammeTables();
      await _seedTree(tables);
      // HomeScreen defaults to athlete.local without a signed-in session.
      tables.assignments.add(_materialised(athleteId: 'athlete.local'));
      final loader = _FixedLoader(_executablePlan());
      final prepare = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: loader,
        localRepository: AthleteLocalRepository(InMemoryKvStore()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            prepareService: prepare,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AthleteProgrammeTodaySection), findsOneWidget);
      expect(find.text('AUTHORED SESSION'), findsOneWidget);
      expect(find.textContaining('Begin'), findsOneWidget);
      expect(find.text('Choose a programme'), findsNothing);
      expect(find.textContaining('subscription'), findsNothing);
      expect(find.textContaining('autonomous'), findsNothing);
    });

    testWidgets('retry state does not fabricate readiness', (tester) async {
      final tables = InMemoryProgrammeTables();
      await _seedTree(tables);
      tables.assignments.add(_materialised(hash: _hashOther));
      final prepare = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: _FixedLoader(_executablePlan()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeTodaySection(
            athleteId: 'athlete-1',
            prepareService: prepare,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Begin'), findsNothing);
      expect(find.textContaining('package hash'), findsOneWidget);
    });

    testWidgets('refresh after materialisation shows today section', (
      tester,
    ) async {
      final tables = InMemoryProgrammeTables();
      await _seedTree(tables);
      tables.assignments.add(
        ProgrammeScheduleTestFixtures.assignment(athleteId: 'athlete.local'),
      );
      final refresh = HomeTodaySessionRefreshController();
      final prepare = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: _FixedLoader(_executablePlan()),
        localRepository: AthleteLocalRepository(InMemoryKvStore()),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            refreshController: refresh,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            prepareService: prepare,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Choose a programme'), findsOneWidget);

      tables.assignments
        ..clear()
        ..add(_materialised(athleteId: 'athlete.local'));
      // Force a new Home state (as after leaving Programme and remounting).
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: const ValueKey('home-after-materialise'),
            embeddedInShell: true,
            refreshController: refresh,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            prepareService: prepare,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AUTHORED SESSION'), findsOneWidget);
    });
  });

  group('Controller prepare after Start Programme', () {
    test('startProgramme triggers prepare without advancing cursor', () async {
      final tables = InMemoryProgrammeTables();
      await _seedTree(tables);
      tables.assignments.add(
        ProgrammeScheduleTestFixtures.assignment(
          id: 'enrol-1',
          athleteId: 'athlete-1',
        ).copyWith(lineageCode: 'PROG-S14B'),
      );
      final loader = _FixedLoader(_executablePlan());
      final prepare = AthleteProgrammeSessionPrepareService(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        slotResolver: AthleteProgrammeAuthoredSlotResolver(
          versionStore: InMemoryProgrammeVersionStore(tables),
        ),
        sessionLoader: loader,
        localRepository: AthleteLocalRepository(InMemoryKvStore()),
      );

      final materialisationStore = _InlineMaterialisationStore((id) async {
        final index = tables.assignments.indexWhere((row) => row.id == id);
        final current = tables.assignments[index];
        final materialised = current.copyWith(
          startedAt: DateTime.utc(2026, 7, 31),
          materialisedAt: DateTime.utc(2026, 7, 31, 12),
          materialisationSource: 'athlete_start_programme',
          materialisedPackageContentHash: _hashExact,
          currentWeek: 1,
          currentDayKey: 'day_1',
          currentSessionOrder: 1,
        );
        tables.assignments[index] = materialised;
        return AthletePlanMaterialisationResult(
          status: AthletePlanMaterialisationStatus.materialised,
          enrolmentId: materialised.id,
          programmeVersionId: materialised.programmeVersionId,
          lineageCode: materialised.lineageCode,
          materialisedAt: materialised.materialisedAt,
          materialisationSource: materialised.materialisationSource,
          materialisedPackageContentHash:
              materialised.materialisedPackageContentHash,
          startedAt: materialised.startedAt,
          currentWeek: 1,
          currentDayKey: 'day_1',
          currentSlotOrder: 1,
          athleteId: materialised.athleteId,
        );
      });

      final controller = AthleteProgrammeScreenController(
        athleteId: 'athlete-1',
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
        materialisationService: AthletePlanMaterialisationService(
          materialisationStore: materialisationStore,
          assignmentStore: InMemoryProgrammeAssignmentStore(tables),
          legacyHasActivePlan: () => false,
        ),
        prepareService: prepare,
      );
      await controller.load();
      final result = await controller.startProgramme();
      expect(result?.isSuccess, isTrue);
      expect(controller.lastPrepareResult?.isReady, isTrue);
      expect(tables.assignments.single.currentWeek, 1);
      expect(tables.assignments.single.currentDayKey, 'day_1');
      expect(tables.assignments.single.currentSessionOrder, 1);
      expect(loader.loadCalls, 1);
    });
  });
}

class _InlineMaterialisationStore implements AthletePlanMaterialisationStore {
  _InlineMaterialisationStore(this._fn);

  final Future<AthletePlanMaterialisationResult> Function(String id) _fn;

  @override
  Future<AthletePlanMaterialisationResult> materialise({
    required String programmeAssignmentId,
    String? timezone,
  }) => _fn(programmeAssignmentId);
}
