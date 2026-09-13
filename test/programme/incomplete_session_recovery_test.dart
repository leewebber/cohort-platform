import 'package:cohort_platform/features/performance/controllers/performance_capture_controller.dart';
import 'package:cohort_platform/features/performance/models/session_result_entry_mode.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/in_memory_performance_record_store.dart';
import 'package:cohort_platform/features/programme/models/backfill_programme_session.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/models/incomplete_session_recovery.dart';
import 'package:cohort_platform/features/programme/presentation/athlete_programme_lifecycle_presentation.dart';
import 'package:cohort_platform/features/programme/screens/athlete_calendar_screen.dart';
import 'package:cohort_platform/features/programme/screens/scheduled_programme_session_preview_screen.dart';
import 'package:cohort_platform/features/programme/services/fixed_programme_occurrence_projection_store.dart';
import 'package:cohort_platform/features/programme/services/in_memory_backfill_programme_session_store.dart';
import 'package:cohort_platform/features/programme/services/scheduled_programme_session_preview_service.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_evidence_projection.dart';
import 'package:cohort_platform/features/session/models/session_execution_plan.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/workout_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/calendar_widget_harness.dart';
import '../support/programme_schedule_test_fixtures.dart';

void main() {
  test('legacy missed is date-derived unfinished, not a skip', () {
    final assignment = _assignment();
    final missed = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.missed,
    );
    final skipped = _occurrence(
      assignment: assignment,
      id: 'occ-skip',
      date: '2026-09-09',
      state: FixedProgrammeOccurrenceState.skipped,
    );
    final calendar = _calendar(
      assignment: assignment,
      occurrences: [missed, skipped],
    );

    expect(missed.isLateStartable, isTrue);
    expect(missed.canOfferHistoricalBackfill, isTrue);
    expect(
      IncompleteSessionRecovery.canTrainToday(
        occurrence: missed,
        calendar: calendar,
        athleteAssignmentId: assignment.id,
      ),
      isTrue,
    );
    expect(
      IncompleteSessionRecovery.canBackfill(
        occurrence: missed,
        calendar: calendar,
        athleteAssignmentId: assignment.id,
        backendSupported: true,
      ),
      isTrue,
    );
    expect(
      IncompleteSessionRecovery.canTrainToday(
        occurrence: skipped,
        calendar: calendar,
        athleteAssignmentId: assignment.id,
      ),
      isFalse,
    );
  });

  test('backfill hides when backend is unsupported', () {
    final assignment = _assignment();
    final overdue = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.overdue,
    );
    final calendar = _calendar(assignment: assignment, occurrences: [overdue]);
    expect(
      IncompleteSessionRecovery.canBackfill(
        occurrence: overdue,
        calendar: calendar,
        athleteAssignmentId: assignment.id,
        backendSupported: false,
      ),
      isFalse,
    );
  });

  test('performed date policy rejects future and pre-scheduled dates', () {
    expect(
      BackfillPerformedDatePolicy.validate(
        scheduledDate: '2026-09-08',
        performedOn: '2026-09-08',
        today: '2026-09-13',
        assignmentStart: '2026-09-07',
      ).accepted,
      isTrue,
    );
    expect(
      BackfillPerformedDatePolicy.validate(
        scheduledDate: '2026-09-08',
        performedOn: '2026-09-14',
        today: '2026-09-13',
        assignmentStart: '2026-09-07',
      ).code,
      'future_date',
    );
    expect(
      BackfillPerformedDatePolicy.validate(
        scheduledDate: '2026-09-08',
        performedOn: '2026-09-07',
        today: '2026-09-13',
        assignmentStart: '2026-09-07',
      ).code,
      'before_scheduled',
    );
  });

  test('progress chronology uses performed date, not recorded time', () {
    final older = _record(
      id: 'older',
      performedOn: DateTime.utc(2026, 9, 8),
      recordedAt: DateTime.utc(2026, 9, 13, 12),
    );
    final newer = _record(
      id: 'newer',
      performedOn: DateTime.utc(2026, 9, 10),
      recordedAt: DateTime.utc(2026, 9, 10, 8),
    );
    final items = AthleteProgressEvidenceProjection.historyItems([
      older,
      newer,
    ]);
    expect(items.first.completedAt, DateTime.utc(2026, 9, 10));
    expect(items.last.completedAt, DateTime.utc(2026, 9, 8));
  });

  test('in-memory backfill is idempotent and leaves today unchanged', () async {
    final assignment = _assignment();
    final overdue = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.overdue,
    );
    final today = _occurrence(
      assignment: assignment,
      id: 'occ-today',
      slotId: ProgrammeScheduleTestFixtures.slot2Id,
      protocolId: 'BW-001',
      dayKey: 'day_4',
      date: '2026-09-13',
      state: FixedProgrammeOccurrenceState.today,
    );
    var calendar = _calendar(
      assignment: assignment,
      today: '2026-09-13',
      occurrences: [overdue, today],
    );
    final performance = InMemoryPerformanceRecordStore();
    final store = InMemoryBackfillProgrammeSessionStore(
      performance: performance,
      projectionStore: _Projection(calendar),
      readProjection: () => calendar,
      writeProjection: (next) => calendar = next,
    );
    final draft = PerformanceCaptureController.initializeFromExecutionPlan(
      plan: _plan(),
      athleteId: assignment.athleteId,
      trainingSessionId: 0,
    ).draft;
    final command = BackfillProgrammeSessionCommand(
      athleteId: assignment.athleteId,
      assignmentId: assignment.id,
      occurrenceId: overdue.occurrenceId,
      scheduledDate: overdue.scheduledDate,
      performedOn: '2026-09-10',
      timezone: 'Atlantic/Canary',
      idempotencyKey: 'backfill-key',
      draft: draft,
    );
    final first = await store.save(command);
    final retry = await store.save(command);
    expect(first.isSaved, isTrue);
    expect(retry.code, 'idempotent_replay');
    expect(performance.records, hasLength(1));
    expect(first.record!.entryMode, SessionResultEntryMode.backfill);
    expect(
      calendar.occurrenceOnDate('2026-09-08')?.state,
      FixedProgrammeOccurrenceState.completed,
    );
    expect(
      calendar.occurrenceOnDate('2026-09-13')?.state,
      FixedProgrammeOccurrenceState.today,
    );
  });

  testWidgets('preview shows Train today, Backfill, and Reschedule', (
    tester,
  ) async {
    final assignment = _assignment();
    final overdue = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.missed,
    );
    final calendar = _calendar(assignment: assignment, occurrences: [overdue]);
    await tester.pumpWidget(
      MaterialApp(
        home: ScheduledProgrammeSessionPreviewScreen(
          athleteId: assignment.athleteId,
          calendar: calendar,
          day: AthleteProgrammeWeekDayPresentation(
            date: DateTime(2026, 9, 8),
            state: FixedProgrammeOccurrenceState.missed,
            occurrence: overdue,
          ),
          previewService: ScheduledProgrammeSessionPreviewService(
            loader: _Loader(),
          ),
          backfillStore: InMemoryBackfillProgrammeSessionStore(
            performance: InMemoryPerformanceRecordStore(),
            projectionStore: _Projection(calendar),
            readProjection: () => calendar,
            writeProjection: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Train today'), findsOneWidget);
    expect(find.text('Backfill results'), findsOneWidget);
    expect(find.text('Reschedule'), findsOneWidget);
    expect(find.text('Overdue'), findsNothing);
    expect(find.text('Missed workout'), findsNothing);
    expect(find.text('Resolve'), findsNothing);
  });

  testWidgets('calendar selected detail stacks recovery actions', (
    tester,
  ) async {
    final assignment = _assignment();
    final overdue = _occurrence(
      assignment: assignment,
      date: '2026-09-08',
      state: FixedProgrammeOccurrenceState.overdue,
    );
    final today = _occurrence(
      assignment: assignment,
      id: 'occ-today',
      date: '2026-09-13',
      state: FixedProgrammeOccurrenceState.today,
    );
    final calendar = _calendar(
      assignment: assignment,
      today: '2026-09-13',
      occurrences: [overdue, today],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AthleteCalendarScreen(
          athleteId: assignment.athleteId,
          fixedOccurrenceStore: _Projection(calendar),
          backfillStore: InMemoryBackfillProgrammeSessionStore(
            performance: InMemoryPerformanceRecordStore(),
            projectionStore: _Projection(calendar),
            readProjection: () => calendar,
            writeProjection: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapCalendarFinder(
      tester,
      find.byKey(const ValueKey('calendar-month-day-2026-09-08')),
    );
    expect(find.text('Train today'), findsWidgets);
    expect(find.text('Backfill results'), findsWidgets);
    expect(find.text('Reschedule'), findsWidgets);
  });

  test('backfill history copy keeps three dates distinct', () {
    expect(
      IncompleteSessionAthleteCopy.backfillHistory(
        scheduled: DateTime(2026, 9, 8),
        performed: DateTime(2026, 9, 10),
        entered: DateTime(2026, 9, 13),
      ),
      'Scheduled 8 September · Performed 10 September · Entered 13 September',
    );
  });
}

ProgrammeAssignment _assignment() {
  return ProgrammeScheduleTestFixtures.materialisedAssignment(
    athleteId: 'athlete-1',
    id: 'assign-1',
  ).copyWith(
    startedAt: DateTime.utc(2026, 9, 7),
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
  );
}

FixedProgrammeOccurrenceProjection _occurrence({
  required ProgrammeAssignment assignment,
  required String date,
  required FixedProgrammeOccurrenceState state,
  String id = 'occ-overdue',
  String? slotId,
  String protocolId = 'RN-006',
  String dayKey = 'day_2',
}) {
  return FixedProgrammeOccurrenceProjection(
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
    sessionTitle: 'Apollo Intervals',
    sessionType: 'Run',
  );
}

FixedProgrammeCalendarProjection _calendar({
  required ProgrammeAssignment assignment,
  required List<FixedProgrammeOccurrenceProjection> occurrences,
  String today = '2026-09-13',
}) {
  return FixedProgrammeCalendarProjection(
    assignmentId: assignment.id,
    programmeName: 'Apollo Build',
    timezone: 'Atlantic/Canary',
    scheduleMode: 'fixed_schedule',
    startDate: '2026-09-07',
    today: today,
    weekStart: '2026-09-07',
    weekEnd: '2026-09-13',
    occurrences: occurrences,
    currentWeek: const [],
  );
}

TrainingSessionRecord _record({
  required String id,
  required DateTime performedOn,
  required DateTime recordedAt,
}) {
  return TrainingSessionRecord(
    recordId: id,
    athleteId: 'athlete-1',
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'RN-006',
      sessionTitle: 'Apollo Intervals',
    ),
    startedAt: recordedAt,
    completedAt: recordedAt,
    entryMode: SessionResultEntryMode.backfill,
    performedOn: performedOn,
    performedPrecision: SessionPerformedPrecision.date,
    recordedAt: recordedAt,
  );
}

SessionExecutionPlan _plan() {
  return const SessionExecutionPlan(
    sessionId: 'RN-006',
    sessionTitle: 'Apollo Intervals',
    blocks: [
      SessionExecutionBlock(
        blockId: 'block-1',
        title: 'Training',
        blockType: SessionBlockType.conditioning,
        content: 'Work',
        workoutFormat: WorkoutFormat.none,
        position: 0,
      ),
    ],
  );
}

class _Projection implements FixedProgrammeOccurrenceProjectionStore {
  const _Projection(this.projection);
  final FixedProgrammeCalendarProjection? projection;
  @override
  Future<FixedProgrammeCalendarProjection?> resolveActive() async => projection;
}

class _Loader extends SessionExecutionLoader {
  @override
  Future<SessionExecutionLoadResult> load({
    required String protocolId,
    String? displayTitle,
    String? programmeContextLabel,
    Map<String, String> prescriptionLoadOverrides = const {},
  }) async {
    return SessionExecutionLoadResult(plan: _plan());
  }
}
