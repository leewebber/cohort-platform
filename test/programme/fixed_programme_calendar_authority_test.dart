import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_lifecycle_presentation.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_schedule_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_store.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

const _hash =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

class _ProjectionStore implements FixedProgrammeOccurrenceProjectionStore {
  _ProjectionStore(this.projection);

  final FixedProgrammeCalendarProjection? projection;
  int calls = 0;

  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async {
    calls++;
    return projection;
  }
}

class _ThrowingProjectionStore
    implements FixedProgrammeOccurrenceProjectionStore {
  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() {
    throw StateError('legacy path must not resolve fixed projection');
  }
}

class _EchoLoader extends SessionExecutionLoader {
  int calls = 0;
  String? lastProtocolId;

  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    calls++;
    lastProtocolId = protocolId;
    return SessionExecutionLoadResult(
      plan: SessionExecutionPlan(
        sessionId: protocolId,
        sessionTitle: 'Session $protocolId',
        durationMin: 45,
        blocks: const [
          SessionExecutionBlock(
            blockId: 'block-1',
            title: 'Training',
            blockType: SessionBlockType.strength,
            content: 'Work',
            workoutFormat: WorkoutFormat.none,
            position: 0,
            linkedExercises: [
              SessionExecutionExerciseSummary(
                exerciseId: 'EX-001',
                displayName: 'Exercise',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StartStore implements ProgrammeTrainingSessionStartStore {
  final calls = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> createOrResume(
    Map<String, dynamic> payload,
  ) async {
    calls.add(Map<String, dynamic>.from(payload));
    return {
      'status': calls.length == 1 ? 'created' : 'resumed',
      'training_session': {
        'id': 91,
        'athlete_id': 'athlete-1',
        'protocol_id': payload['effective_protocol_id'],
        'programme_id': 'PROG-FIXED',
        'week_number': payload['expected_week'],
        'day': payload['expected_day_key'],
        'status': 'in_progress',
      },
    };
  }
}

ProgrammeVersion _version() => ProgrammeVersion(
  id: ProgrammeScheduleTestFixtures.versionId,
  lineageId: ProgrammeScheduleTestFixtures.lineageId,
  versionNumber: 1,
  lifecycleStatus: ProgrammeLifecycleStatus.published,
  libraryScope: ProgrammeLibraryScope.cohortGlobal,
  ownerType: ProgrammeOwnerType.global,
  name: 'Apollo Build — 12-Week Initial Block',
  durationWeeks: 12,
  sessionsPerWeek: 7,
  approvedForGlobal: true,
  packageContentHash: _hash,
);

ProgrammeAssignment _assignment({
  String athleteId = 'athlete-1',
  bool fixed = true,
}) =>
    ProgrammeScheduleTestFixtures.materialisedAssignment(
      athleteId: athleteId,
      packageContentHash: _hash,
    ).copyWith(
      lineageCode: 'PROG-FIXED',
      startedAt: DateTime.utc(2026, 9, 1),
      timezone: 'Atlantic/Canary',
      scheduleMode: fixed ? 'fixed_schedule' : 'legacy_cursor',
      currentWeek: 1,
      currentDayKey: 'day_1',
      currentSessionOrder: 1,
    );

FixedProgrammeOccurrenceProjection _occurrence({
  required ProgrammeAssignment assignment,
  required String id,
  required String slotId,
  required String protocolId,
  required String dayKey,
  required String date,
  required FixedProgrammeOccurrenceState state,
  int? trainingSessionId,
}) => FixedProgrammeOccurrenceProjection(
  assignmentId: assignment.id,
  occurrenceId: id,
  sessionSlotId: slotId,
  programmeVersionId: assignment.programmeVersionId,
  protocolId: protocolId,
  programmedSessionKey:
      'prog:${assignment.id}@${assignment.programmeVersionId}:w1:$dayKey:s1:$protocolId',
  weekNumber: 1,
  dayKey: dayKey,
  sessionOrder: 1,
  scheduledDate: date,
  originalScheduledDate: date,
  state: state,
  sessionTitle: dayKey == 'day_1' ? 'Apollo Monday' : 'Apollo Tuesday',
  sessionLineageId: '00000000-0000-4000-8000-000000000099',
  sessionRevisionNumber: 1,
  trainingSessionId: trainingSessionId,
);

FixedProgrammeCalendarProjection _calendar({
  required ProgrammeAssignment assignment,
  required String today,
  required List<FixedProgrammeOccurrenceProjection> occurrences,
}) {
  final todayDate = DateTime.parse(today);
  final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));
  final week = <FixedProgrammeCalendarDayProjection>[];
  for (var index = 0; index < 7; index++) {
    final date = monday.add(Duration(days: index));
    final iso = date.toIso8601String().substring(0, 10);
    FixedProgrammeOccurrenceProjection? occurrence;
    for (final candidate in occurrences) {
      if (candidate.scheduledDate == iso) occurrence = candidate;
    }
    week.add(
      FixedProgrammeCalendarDayProjection(
        date: iso,
        state: occurrence?.state ?? FixedProgrammeOccurrenceState.rest,
        occurrence: occurrence,
      ),
    );
  }
  return FixedProgrammeCalendarProjection(
    assignmentId: assignment.id,
    programmeName: 'Apollo Build — 12-Week Initial Block',
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    startDate: '2026-09-01',
    today: today,
    weekStart: week.first.date,
    weekEnd: week.last.date,
    occurrences: List.unmodifiable(occurrences),
    currentWeek: List.unmodifiable(week),
  );
}

List<FixedProgrammeOccurrenceProjection> _firstWeekOccurrences({
  required ProgrammeAssignment assignment,
  FixedProgrammeOccurrenceState firstState =
      FixedProgrammeOccurrenceState.planned,
}) {
  return List.generate(7, (index) {
    final date = DateTime.utc(2026, 9, 1).add(Duration(days: index));
    final iso = date.toIso8601String().substring(0, 10);
    return _occurrence(
      assignment: assignment,
      id: '00000000-0000-4000-8000-${(201 + index).toString().padLeft(12, '0')}',
      slotId: index.isEven
          ? ProgrammeScheduleTestFixtures.slot1Id
          : ProgrammeScheduleTestFixtures.slot2Id,
      protocolId: index.isEven ? 'BW-001' : 'RN-006',
      dayKey: 'day_${index + 1}',
      date: iso,
      state: index == 0 ? firstState : FixedProgrammeOccurrenceState.planned,
    );
  }, growable: false);
}

Future<InMemoryProgrammeTables> _tablesWith(
  ProgrammeAssignment assignment,
) async {
  final tables = InMemoryProgrammeTables();
  final version = _version();
  await InMemoryProgrammeVersionStore(tables).saveTemplateTree(
    version: version,
    tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(
      programmeVersionId: version.id,
    ),
  );
  final versionIndex = tables.versions.indexWhere(
    (row) => row.id == version.id,
  );
  if (versionIndex >= 0) {
    tables.versions[versionIndex] = version;
  } else {
    tables.versions.add(version);
  }
  tables.assignments.add(assignment);
  return tables;
}

AthleteProgrammeSessionPrepareService _prepareService({
  required InMemoryProgrammeTables tables,
  required _EchoLoader loader,
  required FixedProgrammeOccurrenceProjectionStore projectionStore,
}) => AthleteProgrammeSessionPrepareService(
  assignmentStore: InMemoryProgrammeAssignmentStore(tables),
  slotResolver: AthleteProgrammeAuthoredSlotResolver(
    versionStore: InMemoryProgrammeVersionStore(tables),
  ),
  sessionLoader: loader,
  localRepository: AthleteLocalRepository(InMemoryKvStore()),
  fixedOccurrenceStore: projectionStore,
);

void main() {
  group('fixed occurrence preparation authority', () {
    test(
      'Sep 2 prepares Day 2 while compatibility cursor remains Day 1',
      () async {
        final assignment = _assignment();
        final day1 = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000201',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'BW-001',
          dayKey: 'day_1',
          date: '2026-09-01',
          state: FixedProgrammeOccurrenceState.missed,
        );
        final day2 = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000202',
          slotId: ProgrammeScheduleTestFixtures.slot2Id,
          protocolId: 'RN-006',
          dayKey: 'day_2',
          date: '2026-09-02',
          state: FixedProgrammeOccurrenceState.today,
        );
        final projection = _calendar(
          assignment: assignment,
          today: '2026-09-02',
          occurrences: [day1, day2],
        );
        final tables = await _tablesWith(assignment);
        final loader = _EchoLoader();
        final projectionStore = _ProjectionStore(projection);
        final result = await _prepareService(
          tables: tables,
          loader: loader,
          projectionStore: projectionStore,
        ).prepareForAssignment(assignment);

        expect(result.isReady, isTrue);
        expect(result.executionContext?.occurrenceId, day2.occurrenceId);
        expect(result.executionContext?.dayKey, 'day_2');
        expect(result.executionContext?.effectiveProtocolId, 'RN-006');
        expect(result.package?.dayKey, 'day_2');
        expect(assignment.currentDayKey, 'day_1');
        expect(loader.lastProtocolId, 'RN-006');
        expect(projectionStore.calls, 1);
      },
    );

    test(
      'overdue occurrence prepares for resume and preserves identity',
      () async {
        final assignment = _assignment();
        final overdue = _occurrence(
          assignment: assignment,
          id: '00000000-0000-4000-8000-000000000201',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'BW-001',
          dayKey: 'day_1',
          date: '2026-09-01',
          state: FixedProgrammeOccurrenceState.inProgressOverdue,
          trainingSessionId: 44,
        );
        final tables = await _tablesWith(assignment);
        final result = await _prepareService(
          tables: tables,
          loader: _EchoLoader(),
          projectionStore: _ProjectionStore(null),
        ).prepareFixedOccurrence(assignment, overdue);

        expect(result.isReady, isTrue);
        expect(result.executionContext?.occurrenceId, overdue.occurrenceId);
        expect(overdue.trainingSessionId, 44);
        expect(result.programmedSessionKey?.scheduleDate, DateTime(2026, 9, 1));
      },
    );

    test('future occurrence cannot be prepared', () async {
      final assignment = _assignment();
      final future = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000203',
        slotId: ProgrammeScheduleTestFixtures.slot2Id,
        protocolId: 'RN-006',
        dayKey: 'day_2',
        date: '2026-09-03',
        state: FixedProgrammeOccurrenceState.planned,
      );
      final tables = await _tablesWith(assignment);
      final loader = _EchoLoader();
      final result = await _prepareService(
        tables: tables,
        loader: loader,
        projectionStore: _ProjectionStore(null),
      ).prepareFixedOccurrence(assignment, future);

      expect(result.isReady, isFalse);
      expect(result.code, 'fixed_occurrence_not_executable');
      expect(loader.calls, 0);
    });

    test(
      'missing fixed projection fails closed without cursor fallback',
      () async {
        final assignment = _assignment();
        final tables = await _tablesWith(assignment);
        final loader = _EchoLoader();
        final result = await _prepareService(
          tables: tables,
          loader: loader,
          projectionStore: _ProjectionStore(null),
        ).prepareForAssignment(assignment);

        expect(result.isReady, isFalse);
        expect(result.code, 'prepare_failed');
        expect(result.message, contains('projection is missing'));
        expect(loader.calls, 0);
      },
    );

    test('legacy assignment retains cursor compatibility path', () async {
      final assignment = _assignment(fixed: false);
      final tables = await _tablesWith(assignment);
      final loader = _EchoLoader();
      final result = await _prepareService(
        tables: tables,
        loader: loader,
        projectionStore: _ThrowingProjectionStore(),
      ).prepareForAssignment(assignment);

      expect(result.isReady, isTrue);
      expect(result.executionContext?.occurrenceId, isNull);
      expect(result.executionContext?.dayKey, 'day_1');
      expect(loader.lastProtocolId, 'BW-001');
    });

    test('Begin forwards the authoritative occurrence identity', () async {
      final assignment = _assignment();
      final today = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000201',
        slotId: ProgrammeScheduleTestFixtures.slot1Id,
        protocolId: 'BW-001',
        dayKey: 'day_1',
        date: '2026-09-01',
        state: FixedProgrammeOccurrenceState.today,
      );
      final tables = await _tablesWith(assignment);
      final prepared = await _prepareService(
        tables: tables,
        loader: _EchoLoader(),
        projectionStore: _ProjectionStore(null),
      ).prepareFixedOccurrence(assignment, today);
      final startStore = _StartStore();
      final launcher = ProgrammeSessionExecutionLauncher(
        startStore: startStore,
      );

      final first = await launcher.createOrResumeTrainingSession(
        athleteId: 'athlete-1',
        programmeContext: prepared.executionContext!,
        package: prepared.package!,
      );
      final retry = await launcher.createOrResumeTrainingSession(
        athleteId: 'athlete-1',
        programmeContext: prepared.executionContext!,
        package: prepared.package!,
      );

      expect(first.id, 91);
      expect(retry.id, first.id);
      expect(startStore.calls, hasLength(2));
      expect(startStore.calls.first['occurrence_id'], today.occurrenceId);
      expect(startStore.calls.last['occurrence_id'], today.occurrenceId);
    });
  });

  group('fixed Home and Plans projection parity', () {
    testWidgets('Home and Plans render the same seven authoritative states', (
      tester,
    ) async {
      final assignment = _assignment(athleteId: 'athlete.local');
      final day1 = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000201',
        slotId: ProgrammeScheduleTestFixtures.slot1Id,
        protocolId: 'BW-001',
        dayKey: 'day_1',
        date: '2026-09-01',
        state: FixedProgrammeOccurrenceState.missed,
      );
      final day2 = _occurrence(
        assignment: assignment,
        id: '00000000-0000-4000-8000-000000000202',
        slotId: ProgrammeScheduleTestFixtures.slot2Id,
        protocolId: 'RN-006',
        dayKey: 'day_2',
        date: '2026-09-02',
        state: FixedProgrammeOccurrenceState.today,
      );
      final projection = _calendar(
        assignment: assignment,
        today: '2026-09-02',
        occurrences: [day1, day2],
      );
      final store = _ProjectionStore(projection);
      final tables = await _tablesWith(assignment);
      final prepare = _prepareService(
        tables: tables,
        loader: _EchoLoader(),
        projectionStore: store,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            prepareService: prepare,
            fixedOccurrenceStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AthleteProgrammeTodaySection), findsOneWidget);
      expect(find.text("TODAY'S TRAINING"), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('CURRENT PROGRAMME'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Not active'), findsOneWidget);
      expect(find.text('Rest'), findsNWidgets(4));
      expect(find.text('Programme'), findsNothing);
      expect(find.text('Build physical capability.'), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScheduleScreen(
            athleteId: 'athlete.local',
            assignmentId: assignment.id,
            fixedOccurrenceStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('THIS WEEK'), findsOneWidget);
      expect(find.text('Missed'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Not active'), findsOneWidget);
      expect(find.text('Rest'), findsNWidgets(4));
    });

    testWidgets('Aug 24 future start is human upcoming and has no false Rest', (
      tester,
    ) async {
      final assignment = _assignment(athleteId: 'athlete.local');
      final firstWeek = _firstWeekOccurrences(assignment: assignment);
      final projection = _calendar(
        assignment: assignment,
        today: '2026-08-24',
        occurrences: firstWeek,
      );
      final store = _ProjectionStore(projection);
      final tables = await _tablesWith(assignment);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UPCOMING PROGRAMME'), findsOneWidget);
      expect(find.text('Apollo Build — 12-Week Initial Block'), findsOneWidget);
      expect(find.text('Starts Tuesday, 1 September'), findsOneWidget);
      expect(
        find.text('Your first session unlocks in 8 days.'),
        findsOneWidget,
      );
      expect(find.text('FIRST WEEK'), findsOneWidget);
      expect(find.text('1–7 September'), findsOneWidget);
      expect(find.text('Planned'), findsNWidgets(7));
      expect(find.text("TODAY'S TRAINING"), findsNothing);
      expect(find.text('Begin'), findsNothing);
      expect(find.text('Rest'), findsNothing);
      expect(find.textContaining('2026-09-01'), findsNothing);
      expect(find.textContaining('Atlantic/Canary'), findsNothing);
      expect(find.textContaining('day_1'), findsNothing);
      expect(find.byType(AthleteProgrammeTodaySection), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScheduleScreen(
            athleteId: 'athlete.local',
            assignmentId: assignment.id,
            fixedOccurrenceStore: store,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Starts Tuesday, 1 September'), findsOneWidget);
      expect(find.text('FIRST WEEK'), findsOneWidget);
      expect(find.text('Planned'), findsNWidgets(7));
      expect(find.textContaining('2026-09-01'), findsNothing);
      expect(find.textContaining('Atlantic/Canary'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('programme-week-day-2026-09-01')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apollo Monday'), findsOneWidget);
      expect(
        find.text('Tuesday, 1 September · Planned\nWeek 1'),
        findsOneWidget,
      );
      expect(find.textContaining('2026-09-01'), findsNothing);
      expect(find.text('Begin'), findsNothing);
    });

    testWidgets(
      'Plans shares upcoming lifecycle labels without false position',
      (tester) async {
        final assignment = _assignment(athleteId: 'athlete.local');
        final projection = _calendar(
          assignment: assignment,
          today: '2026-08-24',
          occurrences: _firstWeekOccurrences(assignment: assignment),
        );
        final store = _ProjectionStore(projection);
        final tables = await _tablesWith(assignment);
        final controller = AthleteProgrammeScreenController(
          athleteId: 'athlete.local',
          assignmentStore: InMemoryProgrammeAssignmentStore(tables),
          versionStore: InMemoryProgrammeVersionStore(tables),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: AthleteProgrammeScreen(
              athleteId: 'athlete.local',
              controller: controller,
              fixedOccurrenceStore: store,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Starts 1 September'), findsOneWidget);
        expect(
          find.text('Your first session unlocks in 8 days.'),
          findsOneWidget,
        );
        expect(find.text('12 weeks'), findsOneWidget);
        expect(find.text('7 sessions per week'), findsOneWidget);
        expect(find.text('View Programme Calendar'), findsOneWidget);
        expect(find.text('Preview Week 1'), findsOneWidget);
        expect(find.text('Browse programmes'), findsOneWidget);
        expect(find.text('View programmes'), findsNothing);
        expect(find.textContaining('Started'), findsNothing);
        expect(find.textContaining('Week 1 · Day 1'), findsNothing);
        expect(find.textContaining('session appears on Home'), findsNothing);
        expect(find.textContaining('2026-09-01'), findsNothing);
        expect(find.textContaining('Atlantic/Canary'), findsNothing);
      },
    );

    testWidgets('active Sep 1 and authored Rest use lifecycle-safe headings', (
      tester,
    ) async {
      final assignment = _assignment(athleteId: 'athlete.local');
      final firstWeek = _firstWeekOccurrences(
        assignment: assignment,
        firstState: FixedProgrammeOccurrenceState.today,
      );
      final activeProjection = _calendar(
        assignment: assignment,
        today: '2026-09-01',
        occurrences: firstWeek,
      );
      final activeStore = _ProjectionStore(activeProjection);
      final tables = await _tablesWith(assignment);
      final prepare = _prepareService(
        tables: tables,
        loader: _EchoLoader(),
        projectionStore: activeStore,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            key: UniqueKey(),
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            prepareService: prepare,
            fixedOccurrenceStore: activeStore,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("TODAY'S TRAINING"), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('THIS WEEK'), findsOneWidget);

      final plansController = AthleteProgrammeScreenController(
        athleteId: 'athlete.local',
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: InMemoryProgrammeVersionStore(tables),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScreen(
            athleteId: 'athlete.local',
            controller: plansController,
            fixedOccurrenceStore: activeStore,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Week 1 · Day 1'), findsOneWidget);
      expect(
        find.text("Today's authored session is available on Home."),
        findsOneWidget,
      );

      final restOccurrences = firstWeek
          .where((occurrence) => occurrence.scheduledDate != '2026-09-06')
          .toList(growable: false);
      final restProjection = _calendar(
        assignment: assignment,
        today: '2026-09-06',
        occurrences: restOccurrences,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: _ProjectionStore(restProjection),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Rest day'), findsOneWidget);
      expect(find.text("TODAY'S TRAINING"), findsNothing);
      expect(find.text('Rest'), findsOneWidget);
    });

    testWidgets('compact week is accessible at 320 logical pixels', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final assignment = _assignment(athleteId: 'athlete.local');
      final projection = _calendar(
        assignment: assignment,
        today: '2026-08-24',
        occurrences: _firstWeekOccurrences(assignment: assignment),
      );
      final tables = await _tablesWith(assignment);

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            assignmentStore: InMemoryProgrammeAssignmentStore(tables),
            fixedOccurrenceStore: _ProjectionStore(projection),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final firstDay = find.byKey(
        const ValueKey('programme-week-day-2026-09-01'),
      );
      expect(firstDay, findsOneWidget);
      final tapSize = tester.getSize(firstDay);
      expect(tapSize.width, greaterThanOrEqualTo(48));
      expect(tapSize.height, greaterThanOrEqualTo(48));
      expect(find.text('Planned'), findsNWidgets(7));
    });
  });

  test('shared lifecycle formatter omits fixed cursor before start', () {
    final assignment = _assignment();
    final upcoming = _calendar(
      assignment: assignment,
      today: '2026-08-24',
      occurrences: _firstWeekOccurrences(assignment: assignment),
    );
    final upcomingLabels =
        AthleteProgrammeLifecycleFormatter.fromFixedProjection(upcoming);

    expect(upcomingLabels.lifecycle, AthleteProgrammeLifecycle.upcoming);
    expect(upcomingLabels.statusLabel, 'Starts 1 September');
    expect(upcomingLabels.daysUntilStart, 8);
    expect(upcomingLabels.currentWeekNumber, isNull);
    expect(upcomingLabels.currentDayLabel, isNull);
    expect(upcomingLabels.week.days, hasLength(7));

    final active = _calendar(
      assignment: assignment,
      today: '2026-09-01',
      occurrences: _firstWeekOccurrences(
        assignment: assignment,
        firstState: FixedProgrammeOccurrenceState.today,
      ),
    );
    final activeLabels = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
      active,
    );
    expect(activeLabels.lifecycle, AthleteProgrammeLifecycle.active);
    expect(activeLabels.statusLabel, 'Week 1 · Day 1');
  });

  test('typed projection rejects malformed or non-seven-day payloads', () {
    expect(
      () => FixedProgrammeCalendarProjection.fromMap({
        'assignment_id': 'assignment',
        'programme_name': 'Apollo',
        'programme_timezone': 'Atlantic/Canary',
        'scheduling_mode': 'fixed_schedule',
        'start_date': '2026-09-01',
        'today': '2026-09-01',
        'week_start': '2026-08-31',
        'week_end': '2026-09-06',
        'occurrences': <Object>[],
        'current_week': <Object>[],
      }),
      throwsFormatException,
    );
  });
}
