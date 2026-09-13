import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_calendar_agenda_presentation.dart';
import 'package:cohort_platform/features/programme/widgets/athlete_programme_week_agenda.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_schedule_test_fixtures.dart';

void main() {
  test('status rules keep Today separate from Planned and Incomplete', () {
    final assignment = _assignment();
    final rows = AthleteCalendarAgendaFormatter.weekRows(
      calendar: _calendar(
        assignment: assignment,
        today: '2026-09-10',
        occurrences: [
          _occurrence(
            assignment: assignment,
            date: '2026-09-08',
            state: FixedProgrammeOccurrenceState.overdue,
            title: 'Apollo Intervals',
            type: 'Run',
          ),
          _occurrence(
            assignment: assignment,
            id: 'occ-today',
            date: '2026-09-10',
            state: FixedProgrammeOccurrenceState.today,
            title: 'Apollo Strength',
            type: 'Strength · Gym',
          ),
          _occurrence(
            assignment: assignment,
            id: 'occ-fri',
            date: '2026-09-11',
            state: FixedProgrammeOccurrenceState.planned,
            title: 'Interval Run',
            type: 'Run',
          ),
        ],
      ),
      weekStart: DateTime(2026, 9, 7),
    );

    final incomplete = rows.singleWhere((row) => row.date.day == 8);
    final today = rows.singleWhere((row) => row.date.day == 10);
    final future = rows.singleWhere((row) => row.date.day == 11);
    final sunday = rows.singleWhere((row) => row.date.day == 13);

    expect(incomplete.statusLabel, 'Incomplete');
    expect(incomplete.sessionTitle, 'Apollo Intervals');
    expect(incomplete.sessionType, 'Run');
    expect(incomplete.isToday, isFalse);
    expect(today.statusLabel, 'Planned');
    expect(today.isToday, isTrue);
    expect(today.headingLabel, contains('Today'));
    expect(future.statusLabel, 'Planned');
    expect(future.isToday, isFalse);
    expect(sunday.sessionTitle, 'No session');
    expect(sunday.statusLabel, isNull);
    expect(
      AthleteCalendarStatusCopy.forOccurrence(
        _occurrence(
          assignment: assignment,
          date: '2026-09-07',
          state: FixedProgrammeOccurrenceState.completed,
          title: 'Done',
        ),
      ),
      'Complete',
    );
    expect(
      AthleteCalendarStatusCopy.forOccurrence(
        _occurrence(
          assignment: assignment,
          date: '2026-09-07',
          state: FixedProgrammeOccurrenceState.inProgress,
          title: 'Live',
        ),
      ),
      'In progress',
    );
    expect(
      AthleteCalendarStatusCopy.forOccurrence(
        _occurrence(
          assignment: assignment,
          date: '2026-09-07',
          state: FixedProgrammeOccurrenceState.skipped,
          title: 'Skipped session',
        ),
      ),
      'Skipped',
    );
  });

  test('multiple sessions on one date stay independent', () {
    final assignment = _assignment();
    final rows = AthleteCalendarAgendaFormatter.weekRows(
      calendar: _calendar(
        assignment: assignment,
        today: '2026-09-10',
        occurrences: [
          _occurrence(
            assignment: assignment,
            date: '2026-09-10',
            state: FixedProgrammeOccurrenceState.today,
            title: 'Apollo Strength',
            order: 1,
          ),
          _occurrence(
            assignment: assignment,
            id: 'occ-mob',
            date: '2026-09-10',
            state: FixedProgrammeOccurrenceState.planned,
            title: 'Mobility',
            order: 2,
          ),
        ],
      ),
      weekStart: DateTime(2026, 9, 7),
    );
    final thursday = rows.where((row) => row.date.day == 10).toList();
    expect(thursday, hasLength(2));
    expect(thursday.first.sessionTitle, 'Apollo Strength');
    expect(thursday.last.sessionTitle, 'Mobility');
    expect(thursday.first.statusLabel, 'Planned');
    expect(thursday.last.statusLabel, 'Planned');
  });

  testWidgets('agenda rows show day, name, status and expand one at a time', (
    tester,
  ) async {
    final assignment = _assignment();
    var opens = 0;
    String? expanded = 'occ-overdue';
    final rows = AthleteCalendarAgendaFormatter.weekRows(
      calendar: _calendar(
        assignment: assignment,
        today: '2026-09-10',
        occurrences: [
          _occurrence(
            assignment: assignment,
            date: '2026-09-08',
            state: FixedProgrammeOccurrenceState.overdue,
            title: 'Apollo Intervals',
            type: 'Run',
          ),
          _occurrence(
            assignment: assignment,
            id: 'occ-today',
            date: '2026-09-10',
            state: FixedProgrammeOccurrenceState.today,
            title: 'Apollo Strength',
            type: 'Strength · Gym',
          ),
          _occurrence(
            assignment: assignment,
            id: 'occ-complete',
            date: '2026-09-07',
            state: FixedProgrammeOccurrenceState.completed,
            title: 'Zone 2 Run',
            type: 'Endurance',
          ),
        ],
      ),
      weekStart: DateTime(2026, 9, 7),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: AthleteProgrammeWeekAgenda(
                  rows: rows,
                  expandedRowId: expanded,
                  onToggleRow: (row) {
                    setState(() {
                      expanded = expanded == row.rowId ? null : row.rowId;
                    });
                  },
                  onOpenSession: (_) => opens++,
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Apollo Intervals'), findsOneWidget);
    expect(find.text('Apollo Strength'), findsOneWidget);
    expect(find.text('Zone 2 Run'), findsOneWidget);
    expect(find.text('Incomplete'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Planned'), findsWidgets);
    expect(find.text('Overdue'), findsNothing);
    expect(find.text('Train today'), findsOneWidget);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(opens, 0);

    await tester.tap(find.text('Train today'));
    await tester.pump();
    expect(opens, 1);

    await tester.tap(find.text('Zone 2 Run'));
    await tester.pump();
    expect(find.text('Train today'), findsNothing);
    expect(find.text('View results'), findsOneWidget);
    expect(find.text('Scheduled 7 September'), findsOneWidget);
  });

  testWidgets('narrow width keeps long names and status readable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final assignment = _assignment();
    final rows = AthleteCalendarAgendaFormatter.weekRows(
      calendar: _calendar(
        assignment: assignment,
        today: '2026-09-10',
        occurrences: [
          _occurrence(
            assignment: assignment,
            date: '2026-09-10',
            state: FixedProgrammeOccurrenceState.today,
            title:
                'Evening Mobility Flow With Extended Recovery Notes For Athletes',
            type: 'Recovery',
          ),
        ],
      ),
      weekStart: DateTime(2026, 9, 7),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: AthleteProgrammeWeekAgenda(rows: rows),
          ),
        ),
      ),
    );
    expect(find.textContaining('Evening Mobility Flow'), findsOneWidget);
    expect(find.text('Planned'), findsOneWidget);
    expect(find.text('Recovery'), findsOneWidget);
    final size = tester.getSize(
      find.byKey(const ValueKey('programme-week-day-2026-09-10')),
    );
    expect(size.height, greaterThanOrEqualTo(48));
  });

  test('84 occurrences still slice to one visible week', () {
    final assignment = _assignment();
    final start = DateTime(2026, 9, 1);
    final occurrences = List.generate(84, (index) {
      final date = start.add(Duration(days: index));
      return _occurrence(
        assignment: assignment,
        id: 'occurrence-$index',
        date: date.toIso8601String().substring(0, 10),
        state: FixedProgrammeOccurrenceState.planned,
        title: 'Session ${index + 1}',
      );
    });
    final rows = AthleteCalendarAgendaFormatter.weekRows(
      calendar: _calendar(
        assignment: assignment,
        today: '2026-08-25',
        occurrences: occurrences,
      ),
      weekStart: DateTime(2026, 9, 1),
    );
    expect(occurrences, hasLength(84));
    expect(rows.where((row) => row.hasSession), hasLength(7));
    expect(rows.first.sessionTitle, 'Session 1');
  });
}

ProgrammeAssignment _assignment() =>
    ProgrammeScheduleTestFixtures.materialisedAssignment(
      athleteId: 'athlete-1',
      packageContentHash:
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    ).copyWith(
      lineageCode: 'APOLLO-BUILD-12-WEEK',
      startedAt: DateTime.utc(2026, 9, 1),
      timezone: 'Atlantic/Canary',
      scheduleMode: 'fixed_schedule',
      currentWeek: 1,
      currentDayKey: 'day_1',
      currentSessionOrder: 1,
    );

FixedProgrammeOccurrenceProjection _occurrence({
  required ProgrammeAssignment assignment,
  required String date,
  required FixedProgrammeOccurrenceState state,
  required String title,
  String id = 'occ-overdue',
  String? type,
  int order = 1,
}) => FixedProgrammeOccurrenceProjection(
  assignmentId: assignment.id,
  occurrenceId: id,
  sessionSlotId: ProgrammeScheduleTestFixtures.slot1Id,
  programmeVersionId: assignment.programmeVersionId,
  protocolId: 'APOLLO',
  programmedSessionKey: 'prog:$id',
  weekNumber: 1,
  dayKey: 'day_$order',
  sessionOrder: order,
  scheduledDate: date,
  originalScheduledDate: date,
  state: state,
  sessionTitle: title,
  sessionType: type,
);

FixedProgrammeCalendarProjection _calendar({
  required ProgrammeAssignment assignment,
  required String today,
  required List<FixedProgrammeOccurrenceProjection> occurrences,
}) {
  return FixedProgrammeCalendarProjection(
    assignmentId: assignment.id,
    programmeName: 'Apollo Build — 12-Week Initial Block',
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    startDate: '2026-09-01',
    today: today,
    weekStart: '2026-09-07',
    weekEnd: '2026-09-13',
    occurrences: List.unmodifiable(occurrences),
    currentWeek: const [],
  );
}
