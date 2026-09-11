import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/models/overdue_programme_recovery.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_lifecycle_presentation.dart';
import 'package:cohort_platform/features/programme/screens/scheduled_programme_session_preview_screen.dart';
import 'package:cohort_platform/features/programme/services/overdue_programme_recovery_store.dart';
import 'package:cohort_platform/features/programme/services/scheduled_programme_session_preview_service.dart';
import 'package:cohort_platform/features/programme/widgets/fixed_programme_week_view.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_schedule_test_fixtures.dart';
import 'package:cohort_platform/models/programme_assignment.dart';

void main() {
  test('derives overdue as actionable and keeps today separate', () {
    final assignment = _assignment();
    final overdue = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.overdue,
      title: 'Apollo Intervals',
    );
    final today = _occurrence(
      assignment: assignment,
      id: 'occ-today',
      slotId: ProgrammeScheduleTestFixtures.slot2Id,
      protocolId: 'BW-001',
      dayKey: 'day_2',
      date: '2026-09-10',
      state: FixedProgrammeOccurrenceState.today,
      title: 'Apollo Strength',
    );
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-09-10',
      occurrences: [overdue, today],
    );

    expect(overdue.isLateStartable, isTrue);
    expect(overdue.isExecutable, isTrue);
    expect(calendar.overdue, hasLength(1));
    expect(calendar.todayOccurrence?.sessionTitle, 'Apollo Strength');
    expect(calendar.isWithinOverdueRescheduleHorizon('2026-09-17'), isTrue);
    expect(calendar.isWithinOverdueRescheduleHorizon('2026-09-18'), isFalse);
    expect(calendar.isWithinOverdueRescheduleHorizon('2026-09-09'), isFalse);
  });

  testWidgets('overdue Calendar item is tappable and opens late actions', (
    tester,
  ) async {
    final assignment = _assignment();
    final overdue = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.overdue,
      title: 'Apollo Intervals',
    );
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-09-10',
      occurrences: [overdue],
    );
    final presentation = AthleteProgrammeLifecycleFormatter.fromFixedProjection(
      calendar,
    ).week;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FixedProgrammeWeekView(
            presentation: presentation,
            onDayTap: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Overdue'), findsWidgets);
    expect(tester.widget<InkWell>(find.byType(InkWell).first).onTap, isNotNull);
  });

  testWidgets('overdue preview shows banner, start, reschedule and skip', (
    tester,
  ) async {
    final assignment = _assignment();
    final overdue = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.overdue,
      title: 'Apollo Intervals',
    );
    final today = _occurrence(
      assignment: assignment,
      id: 'occ-today',
      slotId: ProgrammeScheduleTestFixtures.slot2Id,
      protocolId: 'BW-001',
      dayKey: 'day_2',
      date: '2026-09-10',
      state: FixedProgrammeOccurrenceState.today,
      title: 'Apollo Strength',
    );
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-09-10',
      occurrences: [overdue, today],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduledProgrammeSessionPreviewScreen(
          athleteId: assignment.athleteId,
          calendar: calendar,
          day: AthleteProgrammeWeekDayPresentation(
            date: DateTime(2026, 9, 8),
            state: FixedProgrammeOccurrenceState.overdue,
            occurrence: overdue,
          ),
          previewService: ScheduledProgrammeSessionPreviewService(
            loader: _PreviewLoader(),
          ),
          recoveryStore: _RecordingRecoveryStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Scheduled for Tuesday 8 September'),
      findsWidgets,
    );
    expect(
      find.textContaining('Training today, Thursday 10 September'),
      findsWidgets,
    );
    expect(find.text('Adapt Session'), findsNothing);
    expect(find.text('Begin'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Start this session'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Start this session'), findsOneWidget);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('Skip session'), findsOneWidget);
    await tester.tap(find.text('Start this session'));
    await tester.pumpAndSettle();
    expect(find.textContaining('session now?'), findsOneWidget);
    expect(
      find.text('Your Thursday 10 September session will remain scheduled.'),
      findsOneWidget,
    );
  });

  testWidgets('reschedule offers move to today and swap confirmation', (
    tester,
  ) async {
    final assignment = _assignment();
    final overdue = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.overdue,
      title: 'Apollo Intervals',
    );
    final friday = _occurrence(
      assignment: assignment,
      id: 'occ-fri',
      slotId: ProgrammeScheduleTestFixtures.slot4Id,
      protocolId: 'FG-009',
      dayKey: 'day_6',
      date: '2026-09-11',
      state: FixedProgrammeOccurrenceState.planned,
      title: 'Apollo Strength',
    );
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-09-10',
      occurrences: [overdue, friday],
    );
    final store = _RecordingRecoveryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduledProgrammeSessionPreviewScreen(
          athleteId: assignment.athleteId,
          calendar: calendar,
          day: AthleteProgrammeWeekDayPresentation(
            date: DateTime(2026, 9, 8),
            state: FixedProgrammeOccurrenceState.overdue,
            occurrence: overdue,
          ),
          previewService: ScheduledProgrammeSessionPreviewService(
            loader: _PreviewLoader(),
          ),
          recoveryStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Reschedule'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Reschedule'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Today ·'), findsOneWidget);

    await tester.tap(find.text('Friday 11 September'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Swap:'), findsOneWidget);
    expect(find.textContaining('Apollo Intervals'), findsWidgets);
    expect(find.textContaining('Apollo Strength'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('swap-session-confirm')));
    await tester.pumpAndSettle();
    expect(store.commands, hasLength(1));
    expect(
      store.commands.single.operation,
      OverdueProgrammeRecoveryOperation.swap,
    );
  });

  testWidgets('explicit skip requires confirmation', (tester) async {
    final assignment = _assignment();
    final overdue = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.overdue,
      title: 'Apollo Intervals',
    );
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-09-10',
      occurrences: [overdue],
    );
    final store = _RecordingRecoveryStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduledProgrammeSessionPreviewScreen(
          athleteId: assignment.athleteId,
          calendar: calendar,
          day: AthleteProgrammeWeekDayPresentation(
            date: DateTime(2026, 9, 8),
            state: FixedProgrammeOccurrenceState.overdue,
            occurrence: overdue,
          ),
          previewService: ScheduledProgrammeSessionPreviewService(
            loader: _PreviewLoader(),
          ),
          recoveryStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Skip session'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Skip session'));
    await tester.pumpAndSettle();
    expect(find.text('Skip this session?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('skip-session-confirm')));
    await tester.pumpAndSettle();
    expect(
      store.commands.single.operation,
      OverdueProgrammeRecoveryOperation.skip,
    );
  });
}

class _RecordingRecoveryStore implements OverdueProgrammeRecoveryStore {
  final commands = <OverdueProgrammeRecoveryCommand>[];

  @override
  Future<OverdueProgrammeRecoveryResult> recover(
    OverdueProgrammeRecoveryCommand command,
  ) async {
    commands.add(command);
    return const OverdueProgrammeRecoveryResult(
      status: OverdueProgrammeRecoveryStatus.applied,
      code: 'moved',
    );
  }
}

class _PreviewLoader extends SessionExecutionLoader {
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
        sessionTitle: displayTitle ?? 'Apollo Intervals',
        durationMin: 45,
        blocks: const [
          SessionExecutionBlock(
            blockId: 'block-1',
            title: 'Training',
            blockType: SessionBlockType.strength,
            content: 'Work',
            workoutFormat: WorkoutFormat.steadyState,
            position: 0,
          ),
        ],
      ),
    );
  }
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
  String? slotId,
  String protocolId = 'APOLLO-W1-TUE-R1',
  String dayKey = 'day_1',
}) => FixedProgrammeOccurrenceProjection(
  assignmentId: assignment.id,
  occurrenceId: id,
  sessionSlotId: slotId ?? ProgrammeScheduleTestFixtures.slot1Id,
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
  sessionTitle: title,
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
