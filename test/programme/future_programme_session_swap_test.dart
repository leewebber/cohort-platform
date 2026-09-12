import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/features/home/controllers/home_today_session_refresh_controller.dart';
import 'package:cohort_platform/features/home/home_screen.dart';
import 'package:cohort_platform/features/programme/controllers/athlete_programme_controllers.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/models/future_programme_session_swap.dart';
import 'package:cohort_platform/features/programme/models/programme_execution_context.dart';
import 'package:cohort_platform/features/programme/models/programme_progress_summary.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_lifecycle_presentation.dart';
import 'package:cohort_platform/features/programme/screens/athlete_calendar_screen.dart';
import 'package:cohort_platform/features/programme/screens/athlete_programme_screen.dart';
import 'package:cohort_platform/features/programme/screens/scheduled_programme_session_preview_screen.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_store.dart';
import 'package:cohort_platform/features/programme/services/future_programme_session_swap_service.dart';
import 'package:cohort_platform/features/programme/services/future_programme_session_swap_store.dart';
import 'package:cohort_platform/features/programme/services/scheduled_programme_session_preview_service.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/programme_session_execution_launcher.dart';
import 'package:cohort_platform/features/session/services/programme_training_session_start_store.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/features/session/services/session_execution_launcher.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/programme_schedule_test_fixtures.dart';

const _hash =
    'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

void main() {
  test('offers Train today only for a clean one-for-one swap', () {
    final assignment = _assignment();
    final day1 = _occurrence(
      assignment: assignment,
      id: 'occ-1',
      slotId: ProgrammeScheduleTestFixtures.slot1Id,
      protocolId: 'BW-001',
      dayKey: 'day_1',
      date: '2026-09-05',
      state: FixedProgrammeOccurrenceState.today,
      sessionTitle: 'Apollo Strength',
    );
    final day2 = _occurrence(
      assignment: assignment,
      id: 'occ-2',
      slotId: ProgrammeScheduleTestFixtures.slot2Id,
      protocolId: 'RN-006',
      dayKey: 'day_2',
      date: '2026-09-06',
      state: FixedProgrammeOccurrenceState.planned,
      sessionTitle: 'Apollo Engine',
    );
    final day6 = _occurrence(
      assignment: assignment,
      id: 'occ-6',
      slotId: ProgrammeScheduleTestFixtures.slot4Id,
      protocolId: 'FG-009',
      dayKey: 'day_6',
      date: '2026-09-10',
      state: FixedProgrammeOccurrenceState.planned,
      sessionTitle: 'Apollo Athletic',
    );
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-09-05',
      occurrences: [day1, day2, day6],
    );

    expect(calendar.canOfferFutureTrainTodaySwap(day6), isTrue);
    expect(calendar.canOfferFutureTrainTodaySwap(day1), isFalse);
    expect(calendar.calendarDaysUntil(day2), 1);
    expect(calendar.canOfferFutureTrainTodaySwap(day2), isTrue);

    final leftoverOverdue = _occurrence(
      assignment: assignment,
      id: 'occ-overdue',
      slotId: '00000000-0000-4000-8000-000000000099',
      protocolId: 'EX-099',
      dayKey: 'day_1',
      date: '2026-09-03',
      state: FixedProgrammeOccurrenceState.overdue,
      sessionTitle: 'Apollo Intervals',
    );
    final overdueCalendar = _calendar(
      assignment: assignment,
      today: '2026-09-05',
      occurrences: [leftoverOverdue, day1, day2, day6],
    );
    expect(overdueCalendar.overdue, hasLength(1));
    expect(overdueCalendar.canOfferFutureTrainTodaySwap(day6), isTrue);

    final dayExactly7 = _occurrence(
      assignment: assignment,
      id: 'occ-7',
      slotId: ProgrammeScheduleTestFixtures.slot3Id,
      protocolId: 'EX-007',
      dayKey: 'day_7',
      date: '2026-09-12',
      state: FixedProgrammeOccurrenceState.planned,
      sessionTitle: 'Apollo Long',
    );
    final dayPlus8 = _occurrence(
      assignment: assignment,
      id: 'occ-8',
      slotId: '00000000-0000-4000-8000-000000000008',
      protocolId: 'EX-008',
      dayKey: 'day_1',
      date: '2026-09-13',
      state: FixedProgrammeOccurrenceState.planned,
      sessionTitle: 'Week 2 Strength',
    );
    final horizonCalendar = _calendar(
      assignment: assignment,
      today: '2026-09-05',
      occurrences: [day1, day2, day6, dayExactly7, dayPlus8],
    );
    expect(horizonCalendar.calendarDaysUntil(dayExactly7), 7);
    expect(horizonCalendar.canOfferFutureTrainTodaySwap(dayExactly7), isTrue);
    expect(horizonCalendar.calendarDaysUntil(dayPlus8), 8);
    expect(horizonCalendar.canOfferFutureTrainTodaySwap(dayPlus8), isFalse);

    final dstCalendar = _calendar(
      assignment: assignment,
      today: '2026-03-08',
      occurrences: [
        _occurrence(
          assignment: assignment,
          id: 'occ-dst-today',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'BW-001',
          dayKey: 'day_1',
          date: '2026-03-08',
          state: FixedProgrammeOccurrenceState.today,
          sessionTitle: 'Apollo Strength',
        ),
        _occurrence(
          assignment: assignment,
          id: 'occ-dst-7',
          slotId: ProgrammeScheduleTestFixtures.slot4Id,
          protocolId: 'FG-009',
          dayKey: 'day_6',
          date: '2026-03-15',
          state: FixedProgrammeOccurrenceState.planned,
          sessionTitle: 'Apollo Athletic',
        ),
      ],
    );
    expect(dstCalendar.calendarDaysUntil(dstCalendar.occurrences.last), 7);
    expect(
      dstCalendar.canOfferFutureTrainTodaySwap(dstCalendar.occurrences.last),
      isTrue,
    );

    final completedToday = _calendar(
      assignment: assignment,
      today: '2026-09-05',
      occurrences: [
        _occurrence(
          assignment: assignment,
          id: 'occ-1',
          slotId: ProgrammeScheduleTestFixtures.slot1Id,
          protocolId: 'BW-001',
          dayKey: 'day_1',
          date: '2026-09-05',
          state: FixedProgrammeOccurrenceState.completed,
          sessionTitle: 'Apollo Strength',
        ),
        day6,
      ],
    );
    expect(completedToday.canOfferFutureTrainTodaySwap(day6), isFalse);

    final noToday = _calendar(
      assignment: assignment,
      today: '2026-08-24',
      occurrences: [day6],
    );
    expect(noToday.canOfferFutureTrainTodaySwap(day6), isFalse);
  });

  test(
    'swap service does not write when a clean swap is unavailable',
    () async {
      final assignment = _assignment();
      final future = _occurrence(
        assignment: assignment,
        id: 'occ-6',
        slotId: ProgrammeScheduleTestFixtures.slot4Id,
        protocolId: 'FG-009',
        dayKey: 'day_6',
        date: '2026-09-10',
        state: FixedProgrammeOccurrenceState.planned,
        sessionTitle: 'Apollo Athletic',
      );
      final calendar = _calendar(
        assignment: assignment,
        today: '2026-08-24',
        occurrences: [future],
      );
      final store = _RecordingSwapStore();
      final result = await FutureProgrammeSessionSwapService(
        store: store,
      ).swapAndBegin(calendar: calendar, selected: future);
      expect(result.isSuccess, isFalse);
      expect(result.code, 'swap_not_offered');
      expect(
        result.athleteVisibleMessage,
        'A clean one-for-one swap is not available.',
      );
      expect(store.calls, isEmpty);
    },
  );

  test('maps overdue and in-progress swap codes to athlete-visible reasons', () {
    expect(
      FutureProgrammeSessionSwapResult.athleteVisibleMessageForCode(
        'overdue_occurrence',
      ),
      'You can still train today. An earlier session remains incomplete.',
    );
    expect(
      FutureProgrammeSessionSwapResult.athleteVisibleMessageForCode(
        'in_progress_session_exists',
      ),
      'Finish your current session before swapping another session into today.',
    );
    expect(
      FutureProgrammeSessionSwapResult.fromRpcMap({
        'status': 'ineligible',
        'code': 'overdue_occurrence',
        'assignment_id': 'should-not-appear',
      }).athleteVisibleMessage,
      'You can still train today. An earlier session remains incomplete.',
    );
  });

  test('swap service does not write when the session is 8 days away', () async {
    final assignment = _assignment();
    final today = _occurrence(
      assignment: assignment,
      id: 'occ-1',
      slotId: ProgrammeScheduleTestFixtures.slot1Id,
      protocolId: 'BW-001',
      dayKey: 'day_1',
      date: '2026-09-05',
      state: FixedProgrammeOccurrenceState.today,
      sessionTitle: 'Apollo Strength',
    );
    final plus8 = _occurrence(
      assignment: assignment,
      id: 'occ-8',
      slotId: ProgrammeScheduleTestFixtures.slot4Id,
      protocolId: 'FG-009',
      dayKey: 'day_6',
      date: '2026-09-13',
      state: FixedProgrammeOccurrenceState.planned,
      sessionTitle: 'Apollo Athletic',
    );
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-09-05',
      occurrences: [today, plus8],
    );
    final store = _RecordingSwapStore();
    final result = await FutureProgrammeSessionSwapService(
      store: store,
    ).swapAndBegin(calendar: calendar, selected: plus8);
    expect(result.isSuccess, isFalse);
    expect(result.code, 'swap_not_offered');
    expect(store.calls, isEmpty);
  });

  testWidgets('Cancel leaves the schedule unchanged', (tester) async {
    final harness = await _Harness.create();
    await tester.pumpWidget(harness.previewApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Train today'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Train today'));
    await tester.pumpAndSettle();
    expect(find.text('Train this session today?'), findsOneWidget);
    expect(find.textContaining('Apollo Athletic moves from'), findsOneWidget);
    expect(find.textContaining('Apollo Strength moves from'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('swap-and-begin-cancel')));
    await tester.pumpAndSettle();
    expect(harness.swapStore.calls, isEmpty);
    expect(harness.startStore.calls, isEmpty);
    expect(harness.launcher.calls, 0);
  });

  testWidgets('Swap and begin opens the moved future session', (tester) async {
    final harness = await _Harness.create();
    await tester.pumpWidget(harness.previewApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Train today'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Available 6 September'), findsOneWidget);
    expect(find.text('Train today'), findsOneWidget);
    expect(find.text('Begin'), findsNothing);
    await tester.tap(find.text('Train today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('swap-and-begin')));
    await tester.pumpAndSettle();

    expect(harness.swapStore.calls, hasLength(1));
    expect(
      harness.swapStore.calls.single.todayOccurrenceId,
      harness.day1.occurrenceId,
    );
    expect(
      harness.swapStore.calls.single.selectedOccurrenceId,
      harness.day6.occurrenceId,
    );
    expect(harness.startStore.calls, hasLength(1));
    expect(
      harness.startStore.calls.single['occurrence_id'],
      harness.day6.occurrenceId,
    );
    expect(harness.startStore.calls.single['expected_day_key'], 'day_6');
    expect(harness.startStore.calls.single['effective_protocol_id'], 'FG-009');
    expect(harness.launcher.calls, 1);
    expect(harness.launcher.lastOccurrenceId, harness.day6.occurrenceId);
    expect(harness.launcher.lastProtocolId, 'FG-009');
  });

  testWidgets('rejected swap shows the unresolved earlier session reason', (
    tester,
  ) async {
    final harness = await _Harness.create();
    harness.swapStore.result = const FutureProgrammeSessionSwapResult(
      status: FutureProgrammeSessionSwapStatus.rejected,
      code: 'overdue_occurrence',
    );
    await tester.pumpWidget(harness.previewApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Train today'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Train today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('swap-and-begin')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'You can still train today. An earlier session remains incomplete.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'This session could not be swapped and started. Refresh your calendar and try again.',
      ),
      findsNothing,
    );
    expect(harness.startStore.calls, isEmpty);
  });

  testWidgets(
    'sessions more than 7 days away keep preview and hide Train today',
    (tester) async {
      final harness = await _Harness.createBeyondHorizon();
      await tester.pumpWidget(harness.previewApp());
      await tester.pumpAndSettle();
      expect(find.text('Session unavailable'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Available 9 September'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Available 9 September'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Train today is available for sessions in the next 7 days.'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Train today'), findsNothing);
      expect(find.text('Begin'), findsNothing);
      expect(find.text('Apollo Athletic'), findsWidgets);
    },
  );

  testWidgets('double Swap and begin is a single write', (tester) async {
    final harness = await _Harness.create();
    await tester.pumpWidget(harness.previewApp());
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Train today'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Train today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('swap-and-begin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('swap-and-begin')), findsNothing);
    expect(harness.swapStore.calls, hasLength(1));
    expect(harness.startStore.calls, hasLength(1));
  });

  testWidgets(
    'Home, Calendar, Resume, and Current Programme reload after swap',
    (tester) async {
      final harness = await _Harness.create();
      harness.projectionStore.value = harness.swapped;
      expect(harness.swapped.todayOccurrence?.sessionTitle, 'Apollo Athletic');
      expect(
        harness.swapped.todayOccurrence?.state,
        FixedProgrammeOccurrenceState.inProgress,
      );
      expect(
        harness.swapped.occurrences
            .where((item) => item.scheduledDate == '2026-09-06')
            .single
            .sessionTitle,
        'Apollo Strength',
      );
      expect(
        harness.swapped.occurrences
            .where((item) => item.scheduledDate == '2026-09-02')
            .single
            .sessionTitle,
        'Apollo Engine',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            embeddedInShell: true,
            athleteIdOverride: 'athlete-1',
            assignmentStore: InMemoryProgrammeAssignmentStore(harness.tables),
            fixedOccurrenceStore: harness.projectionStore,
            previewService: ScheduledProgrammeSessionPreviewService(
              loader: _TitleLoader(),
            ),
            prepareService: harness.prepare,
            executionLauncher: harness.execution,
            swapStore: harness.swapStore,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resume'), findsWidgets);

      await tester.pumpWidget(
        MaterialApp(
          home: AthleteCalendarScreen(
            athleteId: 'athlete-1',
            fixedOccurrenceStore: harness.projectionStore,
            previewService: ScheduledProgrammeSessionPreviewService(
              loader: _TitleLoader(),
            ),
            assignmentStore: InMemoryProgrammeAssignmentStore(harness.tables),
            prepareService: harness.prepare,
            executionLauncher: harness.execution,
            swapStore: harness.swapStore,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('In progress'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('programme-week-day-2026-09-06')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('programme-week-day-2026-09-06')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apollo Strength'), findsWidgets);
      expect(find.text('Week 1 · Day 1 · Sunday, 6 September'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      final programmeController = AthleteProgrammeScreenController(
        athleteId: 'athlete-1',
        assignmentStore: InMemoryProgrammeAssignmentStore(harness.tables),
        versionStore: InMemoryProgrammeVersionStore(harness.tables),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: AthleteProgrammeScreen(
            athleteId: 'athlete-1',
            controller: programmeController,
            fixedOccurrenceStore: harness.projectionStore,
            previewService: ScheduledProgrammeSessionPreviewService(
              loader: _TitleLoader(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Week 1 · Day 6'), findsWidgets);
    },
  );

  testWidgets('Calendar swap updates already-mounted Home before any actuals', (
    tester,
  ) async {
    final harness = await _Harness.create();
    final refresh = HomeTodaySessionRefreshController();
    await tester.pumpWidget(
      AthleteProgrammeSurfaceRefreshScope(
        controller: refresh,
        child: MaterialApp(
          home: _SiblingHomeCalendarShell(harness: harness, refresh: refresh),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('programme-week-day-2026-09-06')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('programme-week-day-2026-09-06')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Train today'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Train today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('swap-and-begin')));
    await tester.pumpAndSettle();

    expect(harness.swapStore.calls, hasLength(1));
    await tester.tap(find.byKey(const ValueKey('show-mounted-home')));
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsWidgets);
    expect(find.text('Begin'), findsNothing);
    expect(
      harness.projectionStore.value.todayOccurrence?.sessionTitle,
      'Apollo Athletic',
    );
    expect(
      harness.projectionStore.value.todayOccurrence?.state,
      FixedProgrammeOccurrenceState.inProgress,
    );
  });
}

class _SiblingHomeCalendarShell extends StatefulWidget {
  const _SiblingHomeCalendarShell({
    required this.harness,
    required this.refresh,
  });

  final _Harness harness;
  final HomeTodaySessionRefreshController refresh;

  @override
  State<_SiblingHomeCalendarShell> createState() =>
      _SiblingHomeCalendarShellState();
}

class _SiblingHomeCalendarShellState extends State<_SiblingHomeCalendarShell> {
  int _index = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(
            embeddedInShell: true,
            athleteIdOverride: 'athlete-1',
            refreshController: widget.refresh,
            assignmentStore: InMemoryProgrammeAssignmentStore(
              widget.harness.tables,
            ),
            fixedOccurrenceStore: widget.harness.projectionStore,
            previewService: ScheduledProgrammeSessionPreviewService(
              loader: _TitleLoader(),
            ),
            prepareService: widget.harness.prepare,
            executionLauncher: widget.harness.execution,
            swapStore: widget.harness.swapStore,
          ),
          AthleteCalendarScreen(
            athleteId: 'athlete-1',
            refreshController: widget.refresh,
            fixedOccurrenceStore: widget.harness.projectionStore,
            previewService: ScheduledProgrammeSessionPreviewService(
              loader: _TitleLoader(),
            ),
            assignmentStore: InMemoryProgrammeAssignmentStore(
              widget.harness.tables,
            ),
            prepareService: widget.harness.prepare,
            executionLauncher: widget.harness.execution,
            swapStore: widget.harness.swapStore,
          ),
        ],
      ),
      floatingActionButton: TextButton(
        key: const ValueKey('show-mounted-home'),
        onPressed: () => setState(() => _index = 0),
        child: const Text('Show Home'),
      ),
    );
  }
}

class _Harness {
  _Harness({
    required this.assignment,
    required this.day1,
    required this.day2,
    required this.day6,
    required this.original,
    required this.swapped,
    required this.tables,
    required this.projectionStore,
    required this.swapStore,
    required this.startStore,
    required this.launcher,
    required this.prepare,
    required this.execution,
  });

  final ProgrammeAssignment assignment;
  final FixedProgrammeOccurrenceProjection day1;
  final FixedProgrammeOccurrenceProjection day2;
  final FixedProgrammeOccurrenceProjection day6;
  final FixedProgrammeCalendarProjection original;
  final FixedProgrammeCalendarProjection swapped;
  final InMemoryProgrammeTables tables;
  final _MutableProjectionStore projectionStore;
  final _RecordingSwapStore swapStore;
  final _StartStore startStore;
  final _NoopLauncher launcher;
  final AthleteProgrammeSessionPrepareService prepare;
  final ProgrammeSessionExecutionLauncher execution;

  static Future<_Harness> create() async {
    final assignment = _assignment();
    final day1 = _occurrence(
      assignment: assignment,
      id: '00000000-0000-4000-8000-000000000201',
      slotId: ProgrammeScheduleTestFixtures.slot1Id,
      protocolId: 'BW-001',
      dayKey: 'day_1',
      date: '2026-09-01',
      state: FixedProgrammeOccurrenceState.today,
      sessionTitle: 'Apollo Strength',
    );
    final day2 = _occurrence(
      assignment: assignment,
      id: '00000000-0000-4000-8000-000000000202',
      slotId: ProgrammeScheduleTestFixtures.slot2Id,
      protocolId: 'RN-006',
      dayKey: 'day_2',
      date: '2026-09-02',
      state: FixedProgrammeOccurrenceState.planned,
      sessionTitle: 'Apollo Engine',
    );
    final day6 = _occurrence(
      assignment: assignment,
      id: '00000000-0000-4000-8000-000000000206',
      slotId: '00000000-0000-4000-8000-000000000006',
      protocolId: 'FG-009',
      dayKey: 'day_6',
      date: '2026-09-06',
      state: FixedProgrammeOccurrenceState.planned,
      sessionTitle: 'Apollo Athletic',
    );
    final original = _calendar(
      assignment: assignment,
      today: '2026-09-01',
      occurrences: [day1, day2, day6],
    );
    final swappedDay6 = _occurrence(
      assignment: assignment,
      id: day6.occurrenceId,
      slotId: day6.sessionSlotId,
      protocolId: day6.protocolId,
      dayKey: day6.dayKey,
      date: '2026-09-01',
      state: FixedProgrammeOccurrenceState.inProgress,
      sessionTitle: day6.sessionTitle,
      trainingSessionId: 91,
    );
    final swappedDay1 = _occurrence(
      assignment: assignment,
      id: day1.occurrenceId,
      slotId: day1.sessionSlotId,
      protocolId: day1.protocolId,
      dayKey: day1.dayKey,
      date: '2026-09-06',
      state: FixedProgrammeOccurrenceState.planned,
      sessionTitle: day1.sessionTitle,
    );
    final swapped = _calendar(
      assignment: assignment,
      today: '2026-09-01',
      occurrences: [swappedDay1, day2, swappedDay6],
    );
    final tables = await _tablesWith(assignment);
    final projectionStore = _MutableProjectionStore(original);
    final swapStore = _RecordingSwapStore(
      onSwap: () => projectionStore.value = swapped,
    );
    final startStore = _StartStore();
    final launcher = _NoopLauncher();
    final prepare = AthleteProgrammeSessionPrepareService(
      assignmentStore: InMemoryProgrammeAssignmentStore(tables),
      slotResolver: AthleteProgrammeAuthoredSlotResolver(
        versionStore: InMemoryProgrammeVersionStore(tables),
      ),
      sessionLoader: _TitleLoader(),
      localRepository: AthleteLocalRepository(InMemoryKvStore()),
      fixedOccurrenceStore: projectionStore,
    );
    return _Harness(
      assignment: assignment,
      day1: day1,
      day2: day2,
      day6: day6,
      original: original,
      swapped: swapped,
      tables: tables,
      projectionStore: projectionStore,
      swapStore: swapStore,
      startStore: startStore,
      launcher: launcher,
      prepare: prepare,
      execution: ProgrammeSessionExecutionLauncher(
        startStore: startStore,
        sessionExecutionLauncher: launcher,
      ),
    );
  }

  static Future<_Harness> createBeyondHorizon() async {
    final base = await create();
    final far = _occurrence(
      assignment: base.assignment,
      id: base.day6.occurrenceId,
      slotId: base.day6.sessionSlotId,
      protocolId: base.day6.protocolId,
      dayKey: base.day6.dayKey,
      date: '2026-09-09',
      state: FixedProgrammeOccurrenceState.planned,
      sessionTitle: base.day6.sessionTitle,
    );
    final calendar = _calendar(
      assignment: base.assignment,
      today: '2026-09-01',
      occurrences: [base.day1, far],
    );
    return _Harness(
      assignment: base.assignment,
      day1: base.day1,
      day2: base.day2,
      day6: far,
      original: calendar,
      swapped: base.swapped,
      tables: base.tables,
      projectionStore: _MutableProjectionStore(calendar),
      swapStore: base.swapStore,
      startStore: base.startStore,
      launcher: base.launcher,
      prepare: base.prepare,
      execution: base.execution,
    );
  }

  Widget previewApp() {
    final day = AthleteProgrammeWeekDayPresentation(
      date: DateTime.parse('${day6.scheduledDate}T12:00:00'),
      state: day6.state,
      occurrence: day6,
    );
    return MaterialApp(
      home: ScheduledProgrammeSessionPreviewScreen(
        athleteId: 'athlete-1',
        calendar: original,
        day: day,
        previewService: ScheduledProgrammeSessionPreviewService(
          loader: _TitleLoader(),
        ),
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        prepareService: prepare,
        executionLauncher: execution,
        swapStore: swapStore,
        fixedOccurrenceStore: projectionStore,
      ),
    );
  }
}

class _MutableProjectionStore
    implements FixedProgrammeOccurrenceProjectionStore {
  _MutableProjectionStore(this.value);

  FixedProgrammeCalendarProjection value;

  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async => value;
}

class _RecordingSwapStore implements FutureProgrammeSessionSwapStore {
  _RecordingSwapStore({this.onSwap});

  final VoidCallback? onSwap;
  final calls = <FutureProgrammeSessionSwapCommand>[];
  FutureProgrammeSessionSwapResult? result;

  @override
  Future<FutureProgrammeSessionSwapResult> swapAndBegin(
    FutureProgrammeSessionSwapCommand command,
  ) async {
    calls.add(command);
    onSwap?.call();
    return result ??
        FutureProgrammeSessionSwapResult(
          status: FutureProgrammeSessionSwapStatus.created,
          code: 'swapped_and_begun',
          selectedOccurrenceId: command.selectedOccurrenceId,
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
      'status': 'resumed',
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

class _NoopLauncher extends SessionExecutionLauncher {
  int calls = 0;
  String? lastOccurrenceId;
  String? lastProtocolId;

  @override
  Future<void> launchActiveSessionWithPlan({
    required BuildContext context,
    required SessionExecutionPlan plan,
    required String protocolId,
    required int trainingSessionId,
    required String athleteId,
    ProgrammeExecutionContext? programmeContext,
    ProgrammeProgressSummary? programmeProgress,
  }) async {
    calls++;
    lastOccurrenceId = programmeContext?.occurrenceId;
    lastProtocolId = protocolId;
  }
}

class _TitleLoader extends SessionExecutionLoader {
  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    return SessionExecutionLoadResult(
      plan: SessionExecutionPlan(
        sessionId: protocolId,
        sessionTitle:
            displayTitle ??
            switch (protocolId) {
              'BW-001' => 'Apollo Strength',
              'FG-009' => 'Apollo Athletic',
              'RN-006' => 'Apollo Engine',
              _ => 'Session $protocolId',
            },
        durationMin: 45,
        blocks: const [
          SessionExecutionBlock(
            blockId: 'block-1',
            title: 'Training',
            blockType: SessionBlockType.strength,
            content: 'Work',
            workoutFormat: WorkoutFormat.none,
            position: 0,
          ),
        ],
      ),
    );
  }
}

FixedProgrammeOccurrenceProjection _occurrence({
  required ProgrammeAssignment assignment,
  required String id,
  required String slotId,
  required String protocolId,
  required String dayKey,
  required String date,
  required FixedProgrammeOccurrenceState state,
  required String sessionTitle,
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
  sessionTitle: sessionTitle,
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

ProgrammeAssignment _assignment() =>
    ProgrammeScheduleTestFixtures.materialisedAssignment(
      athleteId: 'athlete-1',
      packageContentHash: _hash,
    ).copyWith(
      lineageCode: 'PROG-FIXED',
      startedAt: DateTime.utc(2026, 9, 1),
      timezone: 'Atlantic/Canary',
      scheduleMode: 'fixed_schedule',
      currentWeek: 1,
      currentDayKey: 'day_1',
      currentSessionOrder: 1,
    );

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
  tables.days.add(
    const ProgrammeVersionDay(
      id: '00000000-0000-4000-8000-000000000116',
      weekId: ProgrammeScheduleTestFixtures.week1Id,
      dayKey: 'day_6',
      dayOrder: 6,
      dayType: ProgrammeDayType.training,
    ),
  );
  tables.slots.add(
    const ProgrammeVersionSessionSlot(
      id: '00000000-0000-4000-8000-000000000006',
      dayId: '00000000-0000-4000-8000-000000000116',
      sessionOrder: 1,
      protocolId: 'FG-009',
    ),
  );
  return tables;
}
