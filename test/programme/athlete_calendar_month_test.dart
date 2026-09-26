import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_calendar_month_presentation.dart';
import 'package:cohort_platform/features/programme/screens/athlete_calendar_screen.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_store.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_calendar_month_grid.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_programme_week_agenda.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/calendar_widget_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  FixedProgrammeCalendarProjection calendar() {
    FixedProgrammeOccurrenceProjection occ({
      required String id,
      required String date,
      required FixedProgrammeOccurrenceState state,
      required String title,
      String dayKey = 'day_1',
      int sessionOrder = 1,
    }) {
      return FixedProgrammeOccurrenceProjection(
        assignmentId: 'assignment-1',
        occurrenceId: id,
        sessionSlotId: 'slot-$id',
        programmeVersionId: 'version-1',
        protocolId: 'BW-001',
        programmedSessionKey: 'prog:assignment-1@version-1:w1:$dayKey:s$sessionOrder:BW-001',
        weekNumber: 1,
        dayKey: dayKey,
        sessionOrder: sessionOrder,
        scheduledDate: date,
        originalScheduledDate: date,
        state: state,
        sessionTitle: title,
        sessionType: 'Strength',
      );
    }

    return FixedProgrammeCalendarProjection(
      assignmentId: 'assignment-1',
      programmeName: 'Apollo Build — 12-Week Initial Block',
      timezone: 'Atlantic/Canary',
      scheduleMode: 'fixed_schedule',
      startDate: '2026-09-01',
      today: '2026-09-10',
      weekStart: '2026-09-07',
      weekEnd: '2026-09-13',
      occurrences: [
        occ(
          id: 'complete',
          date: '2026-09-07',
          state: FixedProgrammeOccurrenceState.completed,
          title: 'Apollo Strength',
        ),
        occ(
          id: 'incomplete',
          date: '2026-09-08',
          state: FixedProgrammeOccurrenceState.overdue,
          title: 'Intervals',
        ),
        occ(
          id: 'today-a',
          date: '2026-09-10',
          state: FixedProgrammeOccurrenceState.today,
          title: 'Apollo Strength',
        ),
        occ(
          id: 'today-b',
          date: '2026-09-10',
          state: FixedProgrammeOccurrenceState.planned,
          title: 'Accessory Circuit',
          dayKey: 'day_2',
          sessionOrder: 2,
        ),
        occ(
          id: 'long',
          date: '2026-09-11',
          state: FixedProgrammeOccurrenceState.planned,
          title: 'Very Long Authored Session Title That Must Truncate',
        ),
        occ(
          id: 'rest',
          date: '2026-09-13',
          state: FixedProgrammeOccurrenceState.rest,
          title: 'Rest',
        ),
        occ(
          id: 'progress',
          date: '2026-09-14',
          state: FixedProgrammeOccurrenceState.inProgress,
          title: 'Intervals',
          dayKey: 'day_3',
        ),
        occ(
          id: 'skipped',
          date: '2026-09-15',
          state: FixedProgrammeOccurrenceState.skipped,
          title: 'Apollo Strength',
          dayKey: 'day_4',
        ),
      ],
      currentWeek: const [],
    );
  }

  test('month cells include date, compact title and status', () {
    final cells = AthleteCalendarMonthFormatter.monthCells(
      calendar: calendar(),
      month: DateTime(2026, 9),
      selectedDate: DateTime(2026, 9, 10),
    );
    expect(cells, hasLength(42));
    final seventh = cells.firstWhere((cell) => cell.isoDate == '2026-09-07');
    expect(seventh.compactTitle, 'Apollo Strength');
    expect(seventh.statusLabel, 'Complete');
    expect(seventh.isToday, isFalse);

    final today = cells.firstWhere((cell) => cell.isoDate == '2026-09-10');
    expect(today.isToday, isTrue);
    expect(today.isSelected, isTrue);
    expect(today.statusLabel, contains('2 sessions'));
    expect(today.compactTitle, contains('Apollo Strength'));
    expect(today.compactTitle, contains('+1 session'));
    expect(today.semanticsLabel, contains('Apollo Strength'));
    expect(today.semanticsLabel, contains('Accessory Circuit'));
    expect(today.semanticsLabel, contains('Today'));

    final long = cells.firstWhere((cell) => cell.isoDate == '2026-09-11');
    expect(long.compactTitle, contains('…'));
    expect(
      long.semanticsLabel,
      contains('Very Long Authored Session Title That Must Truncate'),
    );

    expect(
      cells.firstWhere((cell) => cell.isoDate == '2026-09-14').statusLabel,
      'In progress',
    );
    expect(
      cells.firstWhere((cell) => cell.isoDate == '2026-09-15').statusLabel,
      'Skipped',
    );
  });

  testWidgets('Calendar default is a month grid, not a weekly list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AthleteCalendarScreen(
          athleteId: 'athlete.local',
          fixedOccurrenceStore: _Store(calendar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(AthleteCalendarMonthGrid, skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byType(AthleteProgrammeWeekAgenda), findsNothing);
    expect(find.text('THIS WEEK'), findsNothing);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('Apollo Strength'), findsWidgets);
    expect(find.text('Intervals', skipOffstage: false), findsWidgets);
    expect(find.text('Complete', skipOffstage: false), findsWidgets);
    expect(find.text('Incomplete', skipOffstage: false), findsWidgets);
    expect(find.text('Today', skipOffstage: false), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('calendar-month-next')));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-month-current')));
    await tester.pumpAndSettle();
    expect(find.text('September 2026'), findsOneWidget);

    await _tapMonthDay(tester, '2026-09-08');
    expect(find.text('View session', skipOffstage: false), findsWidgets);
    expect(find.text('Intervals'), findsWidgets);
  });

  testWidgets('selecting a date does not write programme data', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _Store(calendar());
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteCalendarScreen(
          athleteId: 'athlete.local',
          fixedOccurrenceStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(store.resolveCount, 1);

    await _tapMonthDay(tester, '2026-09-08');
    expect(store.resolveCount, 1);
    expect(
      find.byKey(const ValueKey('calendar-selected-view-session-incomplete')),
      findsOneWidget,
    );
  });

  testWidgets('accessibility announces full date, title and status', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AthleteCalendarScreen(
          athleteId: 'athlete.local',
          fixedOccurrenceStore: _Store(calendar()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await revealCalendarFinder(
      tester,
      find.byKey(
        const ValueKey('calendar-month-day-2026-09-11'),
        skipOffstage: false,
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('calendar-month-day-2026-09-11')),
      ).label,
      contains('Very Long Authored Session Title That Must Truncate'),
    );
    await revealCalendarFinder(
      tester,
      find.byKey(
        const ValueKey('calendar-month-day-2026-09-10'),
        skipOffstage: false,
      ),
    );
    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('calendar-month-day-2026-09-10')),
      ).label,
      allOf(
        contains('Today'),
        contains('Accessory Circuit'),
        contains('sessions'),
      ),
    );
  });
}

Future<void> _tapMonthDay(WidgetTester tester, String isoDate) async {
  await tapCalendarFinder(
    tester,
    find.byKey(ValueKey('calendar-month-day-$isoDate'), skipOffstage: false),
  );
}

class _Store implements FixedProgrammeOccurrenceProjectionStore {
  _Store(this.projection);
  final FixedProgrammeCalendarProjection projection;
  int resolveCount = 0;

  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async {
    resolveCount += 1;
    return projection;
  }

  @override
  Future<FixedProgrammeCalendarProjection> resolveForAssignment(
    String assignmentId,
  ) {
    return resolveAssignmentFromActiveFallback(this, assignmentId);
  }
}
