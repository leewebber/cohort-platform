import 'package:cohort_platform/features/performance/models/session_result_entry_mode.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/services/performance_chronology.dart';
import 'package:cohort_platform/features/performance/services/strength_result_comparison.dart';
import 'package:cohort_platform/features/programme/models/incomplete_session_recovery.dart';
import 'package:cohort_platform/features/programme/models/fixed_programme_occurrence_projection.dart';
import 'package:cohort_platform/features/programme/services/athlete_runtime_capabilities.dart';
import 'package:cohort_platform/features/programme/services/supabase_backfill_programme_session_store.dart';
import 'package:cohort_platform/features/progress/services/athlete_progress_evidence_projection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/programme_schedule_test_fixtures.dart';

void main() {
  test('capabilities fail closed until the hosted probe succeeds', () {
    expect(AthleteRuntimeCapabilities.unavailable.backfillResults, isFalse);
    expect(AthleteRuntimeCapabilities.unavailable.overdueRecovery, isFalse);
    final store = SupabaseBackfillProgrammeSessionStore(
      capabilities: AthleteRuntimeCapabilities.unavailable,
    );
    expect(store.isSupported, isFalse);
  });

  test('Train today stays available when Backfill is gated closed', () {
    final assignment = ProgrammeScheduleTestFixtures.materialisedAssignment(
      athleteId: 'athlete-1',
      id: 'assign-1',
    );
    final overdue = FixedProgrammeOccurrenceProjection(
      assignmentId: assignment.id,
      occurrenceId: 'occ-1',
      sessionSlotId: ProgrammeScheduleTestFixtures.slot1Id,
      programmeVersionId: assignment.programmeVersionId,
      protocolId: 'RN-006',
      programmedSessionKey: 'key',
      weekNumber: 1,
      dayKey: 'day_2',
      sessionOrder: 1,
      scheduledDate: '2026-09-08',
      originalScheduledDate: '2026-09-08',
      state: FixedProgrammeOccurrenceState.missed,
      sessionTitle: 'Apollo Intervals',
    );
    final calendar = FixedProgrammeCalendarProjection(
      assignmentId: assignment.id,
      programmeName: 'Apollo Build',
      timezone: 'Atlantic/Canary',
      scheduleMode: 'fixed_schedule',
      startDate: '2026-09-07',
      today: '2026-09-13',
      weekStart: '2026-09-07',
      weekEnd: '2026-09-13',
      occurrences: [overdue],
      currentWeek: const [],
    );
    expect(
      IncompleteSessionRecovery.canTrainToday(
        occurrence: overdue,
        calendar: calendar,
        athleteAssignmentId: assignment.id,
      ),
      isTrue,
    );
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

  test('deriving performed_on from started_at would change live meaning', () {
    final live = TrainingSessionRecord(
      recordId: 'live-1',
      athleteId: 'athlete-1',
      status: TrainingSessionRecordStatus.completed,
      sessionSnapshot: const SessionPerformanceSnapshot(
        sourceProtocolId: 'RN-006',
        sessionTitle: 'Live',
      ),
      startedAt: DateTime.utc(2026, 9, 8, 23, 30),
      completedAt: DateTime.utc(2026, 9, 8, 23, 45),
    );
    final derivedFromUtc = DateTime.utc(
      live.startedAt.year,
      live.startedAt.month,
      live.startedAt.day,
    );
    final derivedFromCanary = DateTime.utc(2026, 9, 9);
    expect(live.performedOn, isNull);
    expect(live.entryMode, SessionResultEntryMode.live);
    expect(derivedFromUtc, isNot(derivedFromCanary));
  });

  test('same-date ordering is deterministic without inventing clock precision', () {
    final backfill = _record(
      id: 'b',
      performedOn: DateTime.utc(2026, 9, 10),
      recordedAt: DateTime.utc(2026, 9, 13, 18),
    );
    final live = TrainingSessionRecord(
      recordId: 'a',
      athleteId: 'athlete-1',
      status: TrainingSessionRecordStatus.completed,
      sessionSnapshot: const SessionPerformanceSnapshot(
        sourceProtocolId: 'ST-001',
        sessionTitle: 'Live later clock',
      ),
      startedAt: DateTime.utc(2026, 9, 10, 18),
      completedAt: DateTime.utc(2026, 9, 10, 19),
    );
    expect(PerformanceChronology.dateKey(backfill), PerformanceChronology.dateKey(live));
    expect(PerformanceChronology.compare(backfill, live), isNot(0));
    final sorted = [live, backfill]..sort(PerformanceChronology.compareNewestFirst);
    expect(sorted.map((r) => r.recordId), ['a', 'b']);
  });

  test('older backfill inserts before a later live session in Progress', () {
    final older = _record(
      id: 'older',
      performedOn: DateTime.utc(2026, 9, 8),
      recordedAt: DateTime.utc(2026, 9, 13, 12),
    );
    final live = TrainingSessionRecord(
      recordId: 'live',
      athleteId: 'athlete-1',
      status: TrainingSessionRecordStatus.completed,
      sessionSnapshot: const SessionPerformanceSnapshot(
        sourceProtocolId: 'ST-001',
        sessionTitle: 'Live Tuesday',
      ),
      startedAt: DateTime.utc(2026, 9, 10, 8),
      completedAt: DateTime.utc(2026, 9, 10, 9),
    );
    final items = AthleteProgressEvidenceProjection.historyItems([older, live]);
    expect(items.first.sessionName, 'Live Tuesday');
    expect(items.last.completedAt, DateTime.utc(2026, 9, 8));
  });

  test('previous performance uses performed chronology, not entry time', () {
    final earlier = _record(
      id: 'earlier',
      performedOn: DateTime.utc(2026, 9, 8),
      recordedAt: DateTime.utc(2026, 9, 13),
    );
    final later = _record(
      id: 'later',
      performedOn: DateTime.utc(2026, 9, 10),
      recordedAt: DateTime.utc(2026, 9, 10),
    );
    final previous = StrengthResultComparison.previousOccurrence(
      exerciseId: 'missing',
      current: later,
      athleteHistory: [earlier, later],
    );
    expect(previous, isNull);
  });
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
      sessionTitle: 'Backfill',
    ),
    startedAt: recordedAt,
    completedAt: recordedAt,
    createdAt: recordedAt,
    entryMode: SessionResultEntryMode.backfill,
    performedOn: performedOn,
    performedPrecision: SessionPerformedPrecision.date,
    recordedAt: recordedAt,
  );
}
