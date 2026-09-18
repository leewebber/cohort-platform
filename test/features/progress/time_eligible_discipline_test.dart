import 'package:cohort_platform/features/app_shell/presentation/athlete_time_aware_greeting.dart';
import 'package:cohort_platform/features/home/controllers/home_today_session_refresh_controller.dart';
import 'package:cohort_platform/features/progress/models/progress_summary.dart';
import 'package:cohort_platform/features/progress/screens/progress_screen.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_summary_builder.dart';
import 'package:cohort_platform/features/progress/services/capability_radar_projection_service.dart';
import 'package:cohort_platform/features/progress/services/time_eligible_discipline.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/models/programme_progress_summary.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_store.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/in_memory_programme_stores.dart';
import '../../support/programme_schedule_test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TimeEligibleDiscipline formula', () {
    test('84 total, 7 due, 6 complete → 86% and 77 future excluded', () {
      final score = TimeEligibleDiscipline.score(
        occurrences: _programme84(
          today: '2026-09-14',
          completeDue: 6,
          incompleteDue: 1,
        ),
        athleteLocalToday: '2026-09-14',
        programmeStartDate: '2026-09-07',
      );
      expect(score.completedEligible, 6);
      expect(score.eligibleDue, 7);
      expect(score.percentage, 86);
      expect(score.futureExcluded, 77);
      expect(score.incompleteCount, 1);
      expect(score.totalRequired, 84);
      expect(
        score.toCompliance().athleteHeadline,
        '6 of 7 sessions completed · 86%',
      );
    });

    test('today Planned is excluded', () {
      final score = _score([
        _occ('past', '2026-09-13', FixedProgrammeOccurrenceState.completed),
        _occ('today', '2026-09-14', FixedProgrammeOccurrenceState.today),
      ]);
      expect(score.completedEligible, 1);
      expect(score.eligibleDue, 1);
      expect(score.percentage, 100);
    });

    test('today In progress is excluded until terminal', () {
      final pending = _score([
        _occ('past', '2026-09-13', FixedProgrammeOccurrenceState.completed),
        _occ('now', '2026-09-14', FixedProgrammeOccurrenceState.inProgress),
      ]);
      expect(pending.eligibleDue, 1);
      expect(pending.percentage, 100);

      final done = _score([
        _occ('past', '2026-09-13', FixedProgrammeOccurrenceState.completed),
        _occ('now', '2026-09-14', FixedProgrammeOccurrenceState.completed),
      ]);
      expect(done.eligibleDue, 2);
      expect(done.completedEligible, 2);
    });

    test('today Complete is included', () {
      final score = _score([
        _occ('today', '2026-09-14', FixedProgrammeOccurrenceState.completed),
      ]);
      expect(score.completedEligible, 1);
      expect(score.eligibleDue, 1);
    });

    test('yesterday unfinished is Incomplete', () {
      final score = _score([
        _occ('y', '2026-09-13', FixedProgrammeOccurrenceState.overdue),
      ]);
      expect(score.completedEligible, 0);
      expect(score.eligibleDue, 1);
      expect(score.incompleteCount, 1);
      expect(score.percentage, 0);
    });

    test('tomorrow Planned is excluded', () {
      final score = _score([
        _occ('t', '2026-09-15', FixedProgrammeOccurrenceState.planned),
      ]);
      expect(score.hasScore, isFalse);
      expect(score.futureExcluded, 1);
    });

    test('authored Rest is excluded', () {
      final score = _score([
        _occ('r', '2026-09-13', FixedProgrammeOccurrenceState.rest),
        _occ('c', '2026-09-13', FixedProgrammeOccurrenceState.completed),
      ]);
      expect(score.eligibleDue, 1);
      expect(score.totalRequired, 1);
    });

    test('explicit Skip is denominator only', () {
      final score = _score([
        _occ('s', '2026-09-13', FixedProgrammeOccurrenceState.skipped),
        _occ('c', '2026-09-12', FixedProgrammeOccurrenceState.completed),
      ]);
      expect(score.completedEligible, 1);
      expect(score.eligibleDue, 2);
      expect(score.skippedCount, 1);
      expect(score.percentage, 50);
    });

    test('Backfill changes numerator without changing denominator', () {
      final incomplete = _score([
        _occ('b', '2026-09-10', FixedProgrammeOccurrenceState.overdue),
      ]);
      expect(incomplete.completedEligible, 0);
      expect(incomplete.eligibleDue, 1);
      final backfilled = _score([
        _occ('b', '2026-09-10', FixedProgrammeOccurrenceState.completed),
      ]);
      expect(backfilled.completedEligible, 1);
      expect(backfilled.eligibleDue, 1);
    });

    test('Train today completion changes numerator only', () {
      final before = _score([
        _occ('late', '2026-09-10', FixedProgrammeOccurrenceState.overdue),
      ]);
      final after = _score([
        _occ('late', '2026-09-10', FixedProgrammeOccurrenceState.completed),
      ]);
      expect(before.eligibleDue, after.eligibleDue);
      expect(before.completedEligible, 0);
      expect(after.completedEligible, 1);
    });

    test('rescheduled source/destination counted once on effective date', () {
      final beforeDue = _score([
        _occ(
          'move',
          '2026-09-20',
          FixedProgrammeOccurrenceState.planned,
          original: '2026-09-10',
        ),
      ]);
      expect(beforeDue.hasScore, isFalse);
      expect(beforeDue.futureExcluded, 1);

      final unfinished = _score([
        _occ(
          'move',
          '2026-09-13',
          FixedProgrammeOccurrenceState.overdue,
          original: '2026-09-10',
        ),
      ], today: '2026-09-14');
      expect(unfinished.eligibleDue, 1);
      expect(unfinished.completedEligible, 0);

      final done = _score([
        _occ(
          'move',
          '2026-09-14',
          FixedProgrammeOccurrenceState.completed,
          original: '2026-09-10',
        ),
      ]);
      expect(done.eligibleDue, 1);
      expect(done.completedEligible, 1);
    });

    test('swap preserves two independent occurrences', () {
      final score = _score([
        _occ(
          'a',
          '2026-09-14',
          FixedProgrammeOccurrenceState.completed,
          original: '2026-09-20',
        ),
        _occ(
          'b',
          '2026-09-20',
          FixedProgrammeOccurrenceState.planned,
          original: '2026-09-14',
        ),
      ]);
      expect(score.eligibleDue, 1);
      expect(score.completedEligible, 1);
      expect(score.futureExcluded, 1);
      expect(score.totalRequired, 2);
    });

    test('duplicate occurrence ids count once', () {
      final row = _occ(
        'once',
        '2026-09-13',
        FixedProgrammeOccurrenceState.completed,
      );
      final score = _score([row, row]);
      expect(score.eligibleDue, 1);
    });

    test('multiple sessions on one date count independently', () {
      final score = _score([
        _occ(
          'strength',
          '2026-09-13',
          FixedProgrammeOccurrenceState.completed,
          slot: 'strength',
        ),
        _occ(
          'run',
          '2026-09-13',
          FixedProgrammeOccurrenceState.overdue,
          slot: 'run',
        ),
      ]);
      expect(score.completedEligible, 1);
      expect(score.eligibleDue, 2);
      expect(score.percentage, 50);
    });

    test('programme not started is no-score', () {
      final score = TimeEligibleDiscipline.score(
        occurrences: [
          _occ('first', '2026-09-20', FixedProgrammeOccurrenceState.planned),
        ],
        athleteLocalToday: '2026-09-14',
        programmeStartDate: '2026-09-20',
      );
      expect(score.availability, DisciplineAvailability.preStart);
      expect(score.hasScore, isFalse);
      expect(score.toCompliance().athleteHeadline, 'No sessions due yet');
    });

    test('first day before training is no sessions due yet', () {
      final score = _score([
        _occ('today', '2026-09-14', FixedProgrammeOccurrenceState.today),
      ]);
      expect(score.availability, DisciplineAvailability.noneDue);
      expect(score.toCompliance().athleteHeadline, 'No sessions due yet');
    });

    test('programme complete uses full required denominator', () {
      final score = TimeEligibleDiscipline.score(
        occurrences: [
          for (var i = 0; i < 84; i++)
            _occ(
              's$i',
              '2026-08-01',
              FixedProgrammeOccurrenceState.completed,
              slot: 'slot-$i',
            ),
        ],
        athleteLocalToday: '2026-09-14',
        programmeStartDate: '2026-07-01',
      );
      expect(score.eligibleDue, 84);
      expect(score.completedEligible, 84);
      expect(score.percentage, 100);
      expect(score.futureExcluded, 0);
    });

    test('partial completion counts as complete without a fraction', () {
      final score = TimeEligibleDiscipline.score(
        occurrences: [
          _occ('p', '2026-09-13', FixedProgrammeOccurrenceState.completed),
        ],
        athleteLocalToday: '2026-09-14',
        slotOutcomes: {'slot-p': ProgrammeSlotOutcomeStatus.completedPartial},
      );
      expect(score.completedEligible, 1);
      expect(score.eligibleDue, 1);
      expect(score.partialCompletedCount, 1);
      expect(score.percentage, 100);
    });

    test('replaced/cancelled occurrence is excluded', () {
      final score = TimeEligibleDiscipline.score(
        occurrences: [
          _occ('keep', '2026-09-13', FixedProgrammeOccurrenceState.completed),
          _occ('gone', '2026-09-13', FixedProgrammeOccurrenceState.planned),
        ],
        athleteLocalToday: '2026-09-14',
        slotOutcomes: {'slot-gone': ProgrammeSlotOutcomeStatus.replaced},
      );
      expect(score.eligibleDue, 1);
      expect(score.totalRequired, 1);
    });
  });

  group('timezone and date boundaries', () {
    test('athlete-local timezone either side of UTC midnight', () {
      final utc = DateTime.utc(2026, 9, 14, 0, 30);
      expect(AthleteIanaClock.dateOnly('UTC', utcNow: utc), '2026-09-14');
      expect(
        AthleteIanaClock.dateOnly('America/New_York', utcNow: utc),
        '2026-09-13',
      );
      final occ = [
        _occ('boundary', '2026-09-13', FixedProgrammeOccurrenceState.planned),
      ];
      final ny = TimeEligibleDiscipline.score(
        occurrences: occ,
        athleteLocalToday: AthleteIanaClock.dateOnly(
          'America/New_York',
          utcNow: utc,
        ),
      );
      expect(ny.hasScore, isFalse);

      final utcScore = TimeEligibleDiscipline.score(
        occurrences: occ,
        athleteLocalToday: AthleteIanaClock.dateOnly('UTC', utcNow: utc),
      );
      expect(utcScore.eligibleDue, 1);
      expect(utcScore.incompleteCount, 1);
    });

    test('DST boundary rolls yesterday unfinished into the denominator', () {
      final before = DateTime.utc(2026, 3, 29, 0, 30);
      final after = DateTime.utc(2026, 3, 29, 1, 30);
      expect(
        AthleteIanaClock.dateOnly('Europe/London', utcNow: before),
        '2026-03-29',
      );
      expect(
        AthleteIanaClock.dateOnly('Europe/London', utcNow: after),
        '2026-03-29',
      );
      final saturday = DateTime.utc(2026, 3, 28, 23, 30);
      expect(
        AthleteIanaClock.dateOnly('Europe/London', utcNow: saturday),
        '2026-03-28',
      );
      final session = [
        _occ('dst', '2026-03-28', FixedProgrammeOccurrenceState.today),
      ];
      final stillToday = TimeEligibleDiscipline.score(
        occurrences: session,
        athleteLocalToday: AthleteIanaClock.dateOnly(
          'Europe/London',
          utcNow: saturday,
        ),
      );
      expect(stillToday.hasScore, isFalse);
      final nextDay = TimeEligibleDiscipline.score(
        occurrences: [
          _occ('dst', '2026-03-28', FixedProgrammeOccurrenceState.overdue),
        ],
        athleteLocalToday: AthleteIanaClock.dateOnly(
          'Europe/London',
          utcNow: after,
        ),
      );
      expect(nextDay.eligibleDue, 1);
      expect(nextDay.incompleteCount, 1);
    });

    test('assignment timezone change recomputes eligibility', () {
      final utc = DateTime.utc(2026, 9, 14, 0, 30);
      final occurrences = [
        _occ('x', '2026-09-13', FixedProgrammeOccurrenceState.planned),
      ];
      final london = TimeEligibleDiscipline.score(
        occurrences: occurrences,
        athleteLocalToday: AthleteIanaClock.dateOnly(
          'Europe/London',
          utcNow: utc,
        ),
      );
      final newYork = TimeEligibleDiscipline.score(
        occurrences: occurrences,
        athleteLocalToday: AthleteIanaClock.dateOnly(
          'America/New_York',
          utcNow: utc,
        ),
      );
      expect(london.eligibleDue, 1);
      expect(newYork.hasScore, isFalse);
    });
  });

  group('builder and radar', () {
    test('builder scores from calendar not programme length', () async {
      final tables = InMemoryProgrammeTables();
      final assignment = ProgrammeScheduleTestFixtures.materialisedAssignment(
        athleteId: 'lee',
      ).copyWith(lineageCode: 'PROG-TEST', timezone: 'Europe/London');
      tables.assignments.add(assignment);
      final versionStore = InMemoryProgrammeVersionStore(tables);
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );

      final calendar = _calendar(
        assignment: assignment,
        today: '2026-09-14',
        occurrences: _programme84(
          today: '2026-09-14',
          completeDue: 6,
          incompleteDue: 1,
        ),
      );
      final builder = AthleteProgressSummaryBuilder(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: versionStore,
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
        occurrenceStore: _StaticOccurrenceStore(calendar),
      );
      final summary = await builder.build(athleteId: 'lee');
      expect(summary.compliance.planned, 7);
      expect(summary.compliance.completed, 6);
      expect(summary.compliance.percentage, 86);
      expect(summary.compliance.futureExcluded, 77);
      expect(
        summary.compliance.athleteHeadline,
        '6 of 7 sessions completed · 86%',
      );
    });

    test('Discipline radar uses time-eligible percentage', () {
      const service = CapabilityRadarProjectionService();
      final radar = service.project(
        timeline: const [],
        compliance: ProgressCompliance(
          completed: 6,
          planned: 7,
          percentage: 86,
          currentStreak: 0,
          longestStreak: 0,
          availability: DisciplineAvailability.scored,
          futureExcluded: 77,
        ),
        strengthSessionCount: 6,
        enduranceSessionCount: 0,
      );
      final discipline = radar.axes.firstWhere(
        (axis) => axis.dimension == CapabilityRadarDimension.discipline,
      );
      expect(discipline.available, isTrue);
      expect(discipline.normalisedValue, closeTo(0.86, 0.001));
      for (final dimension in [
        CapabilityRadarDimension.strength,
        CapabilityRadarDimension.endurance,
        CapabilityRadarDimension.threshold,
        CapabilityRadarDimension.power,
        CapabilityRadarDimension.durability,
        CapabilityRadarDimension.mobility,
      ]) {
        final axis = radar.axes.firstWhere(
          (item) => item.dimension == dimension,
        );
        expect(axis.available, isFalse, reason: dimension.name);
      }
    });

    test('no due sessions leave Discipline unavailable', () {
      const service = CapabilityRadarProjectionService();
      final radar = service.project(
        timeline: const [],
        compliance: const ProgressCompliance(
          completed: 0,
          planned: 0,
          percentage: 0,
          currentStreak: 0,
          longestStreak: 0,
          availability: DisciplineAvailability.noneDue,
        ),
      );
      final discipline = radar.axes.firstWhere(
        (axis) => axis.dimension == CapabilityRadarDimension.discipline,
      );
      expect(discipline.available, isFalse);
    });
  });

  group('Progress copy and refresh', () {
    testWidgets('shows time-bounded copy not full programme length', (
      tester,
    ) async {
      final summary = ProgressSummary(
        hasActivePlan: true,
        planName: 'Apollo',
        weekLabel: 'Week 2',
        sessionsCompleted: 6,
        compliance: ProgressCompliance(
          completed: 6,
          planned: 7,
          percentage: 86,
          currentStreak: 0,
          longestStreak: 0,
          availability: DisciplineAvailability.scored,
          futureExcluded: 77,
          incompleteCount: 1,
          totalRequired: 84,
        ),
        recentImprovements: const [],
        timeline: const [],
        history: const [],
        upcoming: null,
      );
      await tester.pumpWidget(
        MaterialApp(home: ProgressScreen(summary: summary)),
      );
      await tester.pump();
      expect(find.text('6 of 7 sessions completed · 86%'), findsOneWidget);
      expect(find.text('Sessions due so far'), findsWidgets);
      expect(find.text('6 sessions completed'), findsOneWidget);
      expect(find.textContaining('of 84'), findsNothing);
      expect(find.textContaining('planned sessions'), findsNothing);
      expect(
        find.bySemanticsLabel(
          '6 of 7 sessions completed · 86%. Sessions due so far',
        ),
        findsWidgets,
      );
    });

    testWidgets('no due sessions copy', (tester) async {
      final summary = ProgressSummary(
        hasActivePlan: true,
        planName: 'Apollo',
        weekLabel: 'Week 1',
        sessionsCompleted: 0,
        compliance: const ProgressCompliance(
          completed: 0,
          planned: 0,
          percentage: 0,
          currentStreak: 0,
          longestStreak: 0,
          availability: DisciplineAvailability.noneDue,
          totalRequired: 84,
        ),
        recentImprovements: const [],
        timeline: const [],
        history: const [],
        upcoming: null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(320, 568)),
            child: ProgressScreen(summary: summary),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('No sessions due yet'), findsWidgets);
      expect(find.textContaining('0 of 84'), findsNothing);
      expect(find.textContaining('0%'), findsNothing);
    });

    testWidgets('authoritative refresh invalidates a cached score', (
      tester,
    ) async {
      final store = _MutatingOccurrenceStore();
      final tables = InMemoryProgrammeTables();
      final assignment = ProgrammeScheduleTestFixtures.materialisedAssignment(
        athleteId: 'lee',
      ).copyWith(timezone: 'Europe/London');
      tables.assignments.add(assignment);
      final versionStore = InMemoryProgrammeVersionStore(tables);
      await versionStore.saveTemplateTree(
        version: ProgrammeScheduleTestFixtures.version(),
        tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
      );
      final builder = AthleteProgressSummaryBuilder(
        assignmentStore: InMemoryProgrammeAssignmentStore(tables),
        versionStore: versionStore,
        slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
        occurrenceStore: store,
      );
      final refresh = HomeTodaySessionRefreshController();
      await tester.pumpWidget(
        AthleteProgrammeSurfaceRefreshScope(
          controller: refresh,
          child: MaterialApp(
            home: ProgressScreen(
              athleteIdOverride: 'lee',
              progressBuilder: builder,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No sessions due yet'), findsWidgets);

      store.calendar = _calendar(
        assignment: assignment,
        today: '2026-09-14',
        occurrences: [
          _occ('done', '2026-09-13', FixedProgrammeOccurrenceState.completed),
        ],
      );
      await refresh.reloadAuthoritativeSurfaces(source: 'test');
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 sessions completed · 100%'), findsOneWidget);
    });

    testWidgets(
      'assignment-local day rollover refreshes once then settles',
      (tester) async {
        var utcNow = DateTime.utc(2026, 9, 18, 12);
        final store = _MutatingOccurrenceStore();
        final tables = InMemoryProgrammeTables();
        final assignment = ProgrammeScheduleTestFixtures.materialisedAssignment(
          athleteId: 'lee',
        ).copyWith(timezone: 'Europe/London');
        tables.assignments.add(assignment);
        final versionStore = InMemoryProgrammeVersionStore(tables);
        await versionStore.saveTemplateTree(
          version: ProgrammeScheduleTestFixtures.version(),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        );
        store.calendar = _calendar(
          assignment: assignment,
          today: '2026-09-18',
          occurrences: [
            _occ(
              'done',
              '2026-09-17',
              FixedProgrammeOccurrenceState.completed,
            ),
          ],
        );
        final builder = AthleteProgressSummaryBuilder(
          assignmentStore: InMemoryProgrammeAssignmentStore(tables),
          versionStore: versionStore,
          slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
          occurrenceStore: store,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: ProgressScreen(
              athleteIdOverride: 'lee',
              progressBuilder: builder,
              utcNow: () => utcNow,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('1 of 1 sessions completed · 100%'), findsOneWidget);

        utcNow = DateTime.utc(2026, 9, 19, 0, 30);
        store.calendar = _calendar(
          assignment: assignment,
          today: '2026-09-19',
          occurrences: [
            _occ(
              'done',
              '2026-09-17',
              FixedProgrammeOccurrenceState.completed,
            ),
            _occ(
              'overdue',
              '2026-09-18',
              FixedProgrammeOccurrenceState.overdue,
            ),
          ],
        );
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.textContaining('sessions completed'), findsWidgets);
      },
    );

    testWidgets(
      'removing Progress detaches surface reload and pending date callbacks',
      (tester) async {
        final refresh = HomeTodaySessionRefreshController();
        final tables = InMemoryProgrammeTables();
        tables.assignments.add(
          ProgrammeScheduleTestFixtures.materialisedAssignment(
            athleteId: 'lee',
          ).copyWith(timezone: 'Europe/London'),
        );
        final versionStore = InMemoryProgrammeVersionStore(tables);
        await versionStore.saveTemplateTree(
          version: ProgrammeScheduleTestFixtures.version(),
          tree: ProgrammeScheduleTestFixtures.foundationWeekOneTree(),
        );
        await tester.pumpWidget(
          AthleteProgrammeSurfaceRefreshScope(
            controller: refresh,
            child: MaterialApp(
              home: ProgressScreen(
                athleteIdOverride: 'lee',
                progressBuilder: AthleteProgressSummaryBuilder(
                  assignmentStore: InMemoryProgrammeAssignmentStore(tables),
                  versionStore: versionStore,
                  slotOutcomeStore: InMemoryProgrammeSlotOutcomeStore(tables),
                  occurrenceStore: const _StaticOccurrenceStore(
                    FixedProgrammeCalendarProjection(
                      assignmentId: 'asg',
                      programmeName: 'Apollo',
                      timezone: 'Europe/London',
                      scheduleMode: 'fixed_schedule',
                      startDate: '2026-09-07',
                      today: '2026-09-14',
                      weekStart: '2026-09-07',
                      weekEnd: '2026-09-13',
                      occurrences: [],
                      currentWeek: [],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(refresh.hasSurfaceListeners, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(refresh.hasSurfaceListeners, isFalse);
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  });

  test('fromProgrammeSummary keeps factual sessionsCompleted separate', () {
    final assignment = ProgrammeScheduleTestFixtures.materialisedAssignment();
    final summary = AthleteProgressSummaryBuilder.fromProgrammeSummary(
      assignment: assignment,
      programme: const ProgrammeProgressSummary(
        currentWeek: 2,
        totalWeeks: 12,
        completedSessions: 6,
        totalSessions: 84,
      ),
      calendar: _calendar(
        assignment: assignment,
        today: '2026-09-14',
        occurrences: _programme84(
          today: '2026-09-14',
          completeDue: 6,
          incompleteDue: 1,
        ),
      ),
    );
    expect(summary.sessionsCompleted, 6);
    expect(summary.compliance.planned, 7);
    expect(summary.compliance.percentage, 86);
  });
}

TimeEligibleDisciplineScore _score(
  List<FixedProgrammeOccurrenceProjection> occurrences, {
  String today = '2026-09-14',
}) {
  return TimeEligibleDiscipline.score(
    occurrences: occurrences,
    athleteLocalToday: today,
    programmeStartDate: '2026-09-01',
  );
}

List<FixedProgrammeOccurrenceProjection> _programme84({
  required String today,
  required int completeDue,
  required int incompleteDue,
}) {
  final due = completeDue + incompleteDue;
  return [
    for (var i = 0; i < completeDue; i++)
      _occ(
        'c$i',
        '2026-09-${(7 + i).toString().padLeft(2, '0')}',
        FixedProgrammeOccurrenceState.completed,
        slot: 'c$i',
      ),
    for (var i = 0; i < incompleteDue; i++)
      _occ(
        'i$i',
        '2026-09-13',
        FixedProgrammeOccurrenceState.overdue,
        slot: 'i$i',
      ),
    for (var i = 0; i < 84 - due; i++)
      _occ(
        'f$i',
        '2026-10-${((i % 28) + 1).toString().padLeft(2, '0')}',
        FixedProgrammeOccurrenceState.planned,
        slot: 'f$i',
      ),
  ];
}

FixedProgrammeOccurrenceProjection _occ(
  String id,
  String date,
  FixedProgrammeOccurrenceState state, {
  String? original,
  String? slot,
}) {
  return FixedProgrammeOccurrenceProjection(
    assignmentId: 'asg',
    occurrenceId: id,
    sessionSlotId: slot ?? 'slot-$id',
    programmeVersionId: 'ver',
    protocolId: 'p',
    programmedSessionKey: 'key-$id',
    weekNumber: 1,
    dayKey: 'day_1',
    sessionOrder: 1,
    scheduledDate: date,
    originalScheduledDate: original ?? date,
    state: state,
    sessionTitle: id,
  );
}

FixedProgrammeCalendarProjection _calendar({
  required ProgrammeAssignment assignment,
  required String today,
  required List<FixedProgrammeOccurrenceProjection> occurrences,
}) {
  return FixedProgrammeCalendarProjection(
    assignmentId: assignment.id,
    programmeName: 'Apollo',
    timezone: assignment.timezone ?? 'Europe/London',
    scheduleMode: 'fixed_schedule',
    startDate: '2026-09-07',
    today: today,
    weekStart: '2026-09-07',
    weekEnd: '2026-09-13',
    occurrences: List.unmodifiable(occurrences),
    currentWeek: const [],
  );
}

class _StaticOccurrenceStore
    implements FixedProgrammeOccurrenceProjectionStore {
  const _StaticOccurrenceStore(this.calendar);

  final FixedProgrammeCalendarProjection calendar;

  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async => calendar;
}

class _MutatingOccurrenceStore
    implements FixedProgrammeOccurrenceProjectionStore {
  FixedProgrammeCalendarProjection? calendar;

  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async => calendar;
}
