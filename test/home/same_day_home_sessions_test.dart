import 'package:cohort_platform/features/home/controllers/home_today_session_refresh_controller.dart';
import 'package:cohort_platform/features/home/presentation/athlete_home_today_presentation.dart';
import 'package:cohort_platform/features/home/widgets/athlete_home_same_day_sessions_section.dart';
import 'package:cohort_platform/features/home/widgets/athlete_programme_today_section.dart';
import 'package:cohort_platform/features/programme/models/athlete_programme_prepared_session.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FixedProgrammeOccurrenceProjection occ({
    required String id,
    required FixedProgrammeOccurrenceState state,
    required int sessionOrder,
    required ProgrammeSessionTimeOfDay timeOfDay,
    required String title,
    String date = '2026-09-27',
  }) {
    return FixedProgrammeOccurrenceProjection(
      assignmentId: 'assign-1',
      occurrenceId: id,
      sessionSlotId: 'slot-$id',
      programmeVersionId: 'version-1',
      protocolId: 'PROT-$id',
      programmedSessionKey:
          'prog:assign-1@version-1:w1:day_2:s$sessionOrder:PROT-$id',
      weekNumber: 1,
      dayKey: 'day_2',
      sessionOrder: sessionOrder,
      scheduledDate: date,
      originalScheduledDate: date,
      state: state,
      sessionTitle: title,
      timeOfDay: timeOfDay,
    );
  }

  FixedProgrammeCalendarProjection sunday({
    required FixedProgrammeOccurrenceState am,
    required FixedProgrammeOccurrenceState pm,
    String today = '2026-09-27',
  }) {
    return FixedProgrammeCalendarProjection(
      assignmentId: 'assign-1',
      programmeName: 'Lee Bali Hybrid Base',
      timezone: 'Asia/Makassar',
      scheduleMode: 'fixed_schedule',
      startDate: '2026-09-26',
      today: today,
      weekStart: '2026-09-21',
      weekEnd: '2026-09-27',
      occurrences: [
        occ(
          id: 'am',
          state: am,
          sessionOrder: 1,
          timeOfDay: ProgrammeSessionTimeOfDay.morning,
          title: 'Long Aerobic — BikeErg',
        ),
        occ(
          id: 'pm',
          state: pm,
          sessionOrder: 2,
          timeOfDay: ProgrammeSessionTimeOfDay.afternoon,
          title: 'Strength B — Upper Strength',
        ),
      ],
      currentWeek: const [],
    );
  }

  test('Sunday is one same-day group with AM before PM', () {
    final calendar = sunday(
      am: FixedProgrammeOccurrenceState.today,
      pm: FixedProgrammeOccurrenceState.planned,
    );
    final cards = AthleteHomeTodayFormatter.authoredTodaySessions(calendar);
    expect(cards, hasLength(2));
    expect(cards.map((e) => e.occurrenceId), ['am', 'pm']);
    expect(cards[0].scheduledDate, cards[1].scheduledDate);
    expect(cards[0].timeOfDay, ProgrammeSessionTimeOfDay.morning);
    expect(cards[1].timeOfDay, ProgrammeSessionTimeOfDay.afternoon);
    expect(
      AthleteHomeTodayFormatter.timeOfDayLabel(
        cards[0].timeOfDay,
        sameDayGroup: true,
      ),
      'AM',
    );
    expect(
      AthleteHomeTodayFormatter.timeOfDayLabel(
        cards[1].timeOfDay,
        sameDayGroup: true,
      ),
      'PM',
    );
    expect(AthleteHomeTodayFormatter.sessionCountCopy(2), '2 sessions scheduled');
    expect(calendar.today, isNot(contains('28')));
  });

  test('AM in progress does not hide or reorder PM', () {
    final cards = AthleteHomeTodayFormatter.authoredTodaySessions(
      sunday(
        am: FixedProgrammeOccurrenceState.inProgress,
        pm: FixedProgrammeOccurrenceState.planned,
      ),
    );
    expect(cards.map((e) => e.occurrenceId), ['am', 'pm']);
    expect(cards.first.isResumable, isTrue);
    expect(cards.last.isResumable, isFalse);
  });

  test(
    'hosted Bali shape: Saturday complete does not hide Sunday AM/PM grouping',
    () {
      final saturday = occ(
        id: 'sat',
        state: FixedProgrammeOccurrenceState.completed,
        sessionOrder: 1,
        timeOfDay: ProgrammeSessionTimeOfDay.morning,
        title: 'Strength A',
        date: '2026-09-26',
      );
      final calendar = FixedProgrammeCalendarProjection(
        assignmentId: 'assign-1',
        programmeName: 'Lee Bali Hybrid Base',
        timezone: 'Asia/Makassar',
        scheduleMode: 'fixed_schedule',
        startDate: '2026-09-26',
        today: '2026-09-27',
        weekStart: '2026-09-21',
        weekEnd: '2026-09-27',
        occurrences: [
          saturday,
          ...sunday(
            am: FixedProgrammeOccurrenceState.today,
            pm: FixedProgrammeOccurrenceState.planned,
          ).occurrences,
        ],
        currentWeek: const [],
      );
      expect(calendar.scheduleMode, 'fixed_schedule');
      expect(
        calendar.occurrences
            .where((e) => e.scheduledDate == '2026-09-26')
            .single
            .state,
        FixedProgrammeOccurrenceState.completed,
      );
      final cards = AthleteHomeTodayFormatter.authoredTodaySessions(calendar);
      expect(cards.map((e) => e.occurrenceId), ['am', 'pm']);
      expect(cards.every((e) => e.scheduledDate == '2026-09-27'), isTrue);
      expect(
        cards.every(
          (e) => e.state != FixedProgrammeOccurrenceState.completed,
        ),
        isTrue,
      );
      expect(calendar.todayOccurrence?.occurrenceId, 'am');
    },
  );

  test('completing AM leaves PM incomplete on Sunday', () {
    final calendar = sunday(
      am: FixedProgrammeOccurrenceState.completed,
      pm: FixedProgrammeOccurrenceState.planned,
    );
    expect(calendar.todayOccurrence?.occurrenceId, 'pm');
    expect(
      calendar.todaySessions.map((e) => e.occurrenceId),
      ['am', 'pm'],
    );
    expect(calendar.today, '2026-09-27');
  });

  test('PM completed first leaves AM actionable', () {
    final calendar = sunday(
      am: FixedProgrammeOccurrenceState.today,
      pm: FixedProgrammeOccurrenceState.completed,
    );
    expect(calendar.todayOccurrence?.occurrenceId, 'am');
    expect(
      calendar.todaySessions
          .firstWhere((e) => e.occurrenceId == 'pm')
          .state,
      FixedProgrammeOccurrenceState.completed,
    );
  });

  test('both complete stay on Sunday and do not become Monday', () {
    final calendar = sunday(
      am: FixedProgrammeOccurrenceState.completed,
      pm: FixedProgrammeOccurrenceState.completed,
    );
    expect(calendar.todaySessions, hasLength(2));
    expect(
      calendar.todaySessions.every(
        (e) => e.state == FixedProgrammeOccurrenceState.completed,
      ),
      isTrue,
    );
    expect(calendar.today, '2026-09-27');
  });

  test('Monday double session uses the same authored grouping', () {
    final calendar = FixedProgrammeCalendarProjection(
      assignmentId: 'assign-1',
      programmeName: 'Lee Bali Hybrid Base',
      timezone: 'Asia/Makassar',
      scheduleMode: 'fixed_schedule',
      startDate: '2026-09-26',
      today: '2026-09-28',
      weekStart: '2026-09-28',
      weekEnd: '2026-10-04',
      occurrences: [
        occ(
          id: 'mon-am',
          state: FixedProgrammeOccurrenceState.today,
          sessionOrder: 1,
          timeOfDay: ProgrammeSessionTimeOfDay.morning,
          title: 'Threshold A — BikeErg',
          date: '2026-09-28',
        ),
        occ(
          id: 'mon-pm',
          state: FixedProgrammeOccurrenceState.planned,
          sessionOrder: 2,
          timeOfDay: ProgrammeSessionTimeOfDay.afternoon,
          title: 'Muscular Endurance',
          date: '2026-09-28',
        ),
      ],
      currentWeek: const [],
    );
    final cards = AthleteHomeTodayFormatter.authoredTodaySessions(calendar);
    expect(cards.map((e) => e.occurrenceId), ['mon-am', 'mon-pm']);
    expect(cards.every((e) => e.scheduledDate == '2026-09-28'), isTrue);
  });

  test('ordinary one-session day has no AM/PM label', () {
    final calendar = FixedProgrammeCalendarProjection(
      assignmentId: 'assign-1',
      programmeName: 'Lee Bali Hybrid Base',
      timezone: 'Asia/Makassar',
      scheduleMode: 'fixed_schedule',
      startDate: '2026-09-26',
      today: '2026-09-26',
      weekStart: '2026-09-21',
      weekEnd: '2026-09-27',
      occurrences: [
        occ(
          id: 'sat',
          state: FixedProgrammeOccurrenceState.completed,
          sessionOrder: 1,
          timeOfDay: ProgrammeSessionTimeOfDay.any,
          title: 'Strength A — Heavy Lower + Pull',
          date: '2026-09-26',
        ),
      ],
      currentWeek: const [],
    );
    final cards = AthleteHomeTodayFormatter.authoredTodaySessions(calendar);
    expect(cards, hasLength(1));
    expect(
      AthleteHomeTodayFormatter.timeOfDayLabel(
        cards.single.timeOfDay,
        sameDayGroup: false,
      ),
      isNull,
    );
  });

  testWidgets('same-day section exposes accessible count and date', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AthleteHomeSameDaySessionsSection(
            dateLabel: 'Sunday 27 September',
            sessionCount: 2,
            children: [Text('AM card'), Text('PM card')],
          ),
        ),
      ),
    );
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Sunday 27 September'), findsOneWidget);
    expect(find.text('2 sessions scheduled'), findsOneWidget);
    expect(find.text('AM card'), findsOneWidget);
    expect(find.text('PM card'), findsOneWidget);
    expect(find.textContaining('Tomorrow'), findsNothing);
    expect(
      tester.getSemantics(find.text('2 sessions scheduled')),
      isNotNull,
    );
  });

  testWidgets('narrow and large text keep both cards', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AthleteHomeSameDaySessionsSection(
                dateLabel: 'Sunday 27 September',
                sessionCount: 2,
                children: [Text('AM card'), Text('PM card')],
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('AM card'), findsOneWidget);
    expect(find.text('PM card'), findsOneWidget);
  });

  test('generic Train today is ambiguous when both Sunday sessions are open', () {
    final calendar = sunday(
      am: FixedProgrammeOccurrenceState.today,
      pm: FixedProgrammeOccurrenceState.planned,
    );
    expect(calendar.incompleteTodaySessions, hasLength(2));
  });

  test('completing both keeps Sunday cards and names the next date', () {
    final calendar = FixedProgrammeCalendarProjection(
      assignmentId: 'assign-1',
      programmeName: 'Lee Bali Hybrid Base',
      timezone: 'Asia/Makassar',
      scheduleMode: 'fixed_schedule',
      startDate: '2026-09-26',
      today: '2026-09-27',
      weekStart: '2026-09-21',
      weekEnd: '2026-09-27',
      occurrences: [
        occ(
          id: 'am',
          state: FixedProgrammeOccurrenceState.completed,
          sessionOrder: 1,
          timeOfDay: ProgrammeSessionTimeOfDay.morning,
          title: 'Long Aerobic — BikeErg',
        ),
        occ(
          id: 'pm',
          state: FixedProgrammeOccurrenceState.completed,
          sessionOrder: 2,
          timeOfDay: ProgrammeSessionTimeOfDay.afternoon,
          title: 'Strength B — Upper Strength',
        ),
        occ(
          id: 'mon-am',
          state: FixedProgrammeOccurrenceState.planned,
          sessionOrder: 1,
          timeOfDay: ProgrammeSessionTimeOfDay.morning,
          title: 'Threshold A — BikeErg',
          date: '2026-09-28',
        ),
      ],
      currentWeek: const [],
    );
    final home = calendar.forHomeToday();
    expect(home.todaySessions.map((e) => e.occurrenceId), ['am', 'pm']);
    expect(home.today, '2026-09-27');
    expect(
      AthleteHomeTodayFormatter.nextSessionHint(home),
      'Next: Threshold A — BikeErg · Tomorrow',
    );
  });

  testWidgets('one card failure leaves the other occurrence visible', (
    tester,
  ) async {
    var amLoads = 0;
    var pmLoads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AthleteHomeSameDaySessionsSection(
            dateLabel: 'Sunday 27 September',
            sessionCount: 2,
            children: [
              AthleteProgrammeTodaySection(
                athleteId: 'athlete.local',
                grouped: true,
                dateLabel: 'Sunday 27 September',
                fixedOccurrence: occ(
                  id: 'am',
                  state: FixedProgrammeOccurrenceState.today,
                  sessionOrder: 1,
                  timeOfDay: ProgrammeSessionTimeOfDay.morning,
                  title: 'Long Aerobic — BikeErg',
                ),
                prepareOverride: (_) async {
                  amLoads += 1;
                  return const AthleteProgrammePrepareResult(
                    status: AthleteProgrammePrepareStatus.failure,
                    code: 'am_failed',
                    message: 'Long Aerobic — BikeErg could not be prepared.',
                  );
                },
              ),
              AthleteProgrammeTodaySection(
                athleteId: 'athlete.local',
                grouped: true,
                dateLabel: 'Sunday 27 September',
                fixedOccurrence: occ(
                  id: 'pm',
                  state: FixedProgrammeOccurrenceState.planned,
                  sessionOrder: 2,
                  timeOfDay: ProgrammeSessionTimeOfDay.afternoon,
                  title: 'Strength B — Upper Strength',
                ),
                prepareOverride: (_) async {
                  pmLoads += 1;
                  return const AthleteProgrammePrepareResult(
                    status: AthleteProgrammePrepareStatus.failure,
                    code: 'pm_ok_placeholder',
                    message: 'Strength B — Upper Strength could not be prepared.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Long Aerobic — BikeErg'), findsWidgets);
    expect(find.text('Strength B — Upper Strength'), findsWidgets);
    expect(
      find.byKey(const ValueKey('home-today-failure-am')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-today-failure-pm')),
      findsOneWidget,
    );
    expect(amLoads, 1);
    expect(pmLoads, 1);
  });

  testWidgets('refresh reloads both same-day cards independently', (
    tester,
  ) async {
    final controller = HomeTodaySessionRefreshController();
    var amLoads = 0;
    var pmLoads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AthleteHomeSameDaySessionsSection(
            dateLabel: 'Sunday 27 September',
            sessionCount: 2,
            children: [
              AthleteProgrammeTodaySection(
                athleteId: 'athlete.local',
                grouped: true,
                refreshController: controller,
                fixedOccurrence: occ(
                  id: 'am',
                  state: FixedProgrammeOccurrenceState.today,
                  sessionOrder: 1,
                  timeOfDay: ProgrammeSessionTimeOfDay.morning,
                  title: 'Long Aerobic — BikeErg',
                ),
                prepareOverride: (_) async {
                  amLoads += 1;
                  return const AthleteProgrammePrepareResult(
                    status: AthleteProgrammePrepareStatus.failure,
                    message: 'Long Aerobic — BikeErg could not be prepared.',
                  );
                },
              ),
              AthleteProgrammeTodaySection(
                athleteId: 'athlete.local',
                grouped: true,
                refreshController: controller,
                fixedOccurrence: occ(
                  id: 'pm',
                  state: FixedProgrammeOccurrenceState.planned,
                  sessionOrder: 2,
                  timeOfDay: ProgrammeSessionTimeOfDay.afternoon,
                  title: 'Strength B — Upper Strength',
                ),
                prepareOverride: (_) async {
                  pmLoads += 1;
                  return const AthleteProgrammePrepareResult(
                    status: AthleteProgrammePrepareStatus.failure,
                    message: 'Strength B — Upper Strength could not be prepared.',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(amLoads, 1);
    expect(pmLoads, 1);
    controller.requestRefresh(source: 'restart');
    await tester.pumpAndSettle();
    expect(amLoads, 2);
    expect(pmLoads, 2);
  });

  testWidgets('AM and PM view-session actions keep distinct occurrence IDs', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AthleteHomeSameDaySessionsSection(
            dateLabel: 'Sunday 27 September',
            sessionCount: 2,
            children: [
              TextButton(
                key: const ValueKey('open-am'),
                onPressed: () => opened.add('am'),
                child: const Text('Open AM'),
              ),
              TextButton(
                key: const ValueKey('open-pm'),
                onPressed: () => opened.add('pm'),
                child: const Text('Open PM'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-am')));
    await tester.tap(find.byKey(const ValueKey('open-pm')));
    expect(opened, ['am', 'pm']);
    expect(find.text('Train today'), findsNothing);
  });
}
