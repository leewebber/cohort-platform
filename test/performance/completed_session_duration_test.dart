import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/session_result_entry_mode.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/services/completed_session_duration.dart';
import 'package:cohort_platform/features/performance/services/completed_session_result_projection.dart';
import 'package:cohort_platform/features/session/presentation/daily_journey_integrity_preview_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same-day duration is completed_at minus started_at', () {
    final record = _record(
      startedAt: DateTime.utc(2026, 9, 20, 10),
      completedAt: DateTime.utc(2026, 9, 20, 10, 45),
      storedDurationSeconds: 9999,
    );
    expect(CompletedSessionDuration.fromRecord(record), 45 * 60);
    expect(
      CompletedSessionResultProjection.fromRecords(record: record).durationSeconds,
      45 * 60,
    );
  });

  test('sessions crossing midnight calculate from instants', () {
    expect(
      CompletedSessionDuration.fromInstants(
        startedAt: DateTime.utc(2026, 9, 20, 22, 30),
        completedAt: DateTime.utc(2026, 9, 21, 1),
      ),
      2 * 3600 + 30 * 60,
    );
  });

  test('timezone conversion does not change elapsed duration', () {
    final startedLocal = DateTime(2026, 9, 20, 8);
    final completedLocal = DateTime(2026, 9, 20, 9, 15);
    expect(
      CompletedSessionDuration.fromInstants(
        startedAt: startedLocal,
        completedAt: completedLocal,
      ),
      CompletedSessionDuration.fromInstants(
        startedAt: startedLocal.toUtc(),
        completedAt: completedLocal.toUtc(),
      ),
    );
    expect(
      CompletedSessionDuration.fromInstants(
        startedAt: startedLocal,
        completedAt: completedLocal,
      ),
      75 * 60,
    );
  });

  test('completedHosted reconciliation uses the committed timestamps', () {
    final committed = previewCommittedStrengthRecord();
    final reconciled = previewFindCommittedCompletion(
      hostedRecords: [committed],
      athleteId: previewAthleteId,
      trainingSessionId: 4,
      idempotencyKey: previewCompletionIdempotencyKey,
    );
    expect(identical(reconciled, committed) || reconciled.recordId == committed.recordId, isTrue);
    expect(reconciled.startedAt, DateTime.utc(2026, 9, 20, 10));
    expect(reconciled.completedAt, DateTime.utc(2026, 9, 20, 10, 45));
    expect(CompletedSessionDuration.fromRecord(reconciled), 45 * 60);
    expect(reconciled.durationSeconds, 45 * 60);
  });

  test('reversed or corrupt timestamps never yield a negative duration', () {
    final reversed = _record(
      startedAt: DateTime.utc(2026, 9, 21, 4, 40),
      completedAt: DateTime.utc(2026, 9, 20, 10, 45),
      storedDurationSeconds: -1075 * 60 - 15,
    );
    expect(CompletedSessionDuration.fromRecord(reversed), isNull);
    expect(
      CompletedSessionResultProjection.fromRecords(record: reversed).durationSeconds,
      isNull,
    );
    expect(formatCompletedDuration(-1075 * 60 - 15), isEmpty);
    expect(formatCompletedDuration(-1), isEmpty);
  });

  test('missing timestamps do not fabricate duration', () {
    final missing = _record(
      startedAt: DateTime.utc(2026, 9, 20, 10),
      completedAt: null,
      storedDurationSeconds: 1800,
    );
    expect(CompletedSessionDuration.fromRecord(missing), isNull);
    expect(
      CompletedSessionResultProjection.fromRecords(record: missing).durationSeconds,
      isNull,
    );
  });

  test('Backfill date-only records do not invent live elapsed time', () {
    final backfill = _record(
      startedAt: DateTime.utc(2026, 9, 20),
      completedAt: DateTime.utc(2026, 9, 20, 10, 45),
      storedDurationSeconds: 2700,
      entryMode: SessionResultEntryMode.backfill,
      precision: SessionPerformedPrecision.date,
    );
    expect(CompletedSessionDuration.fromRecord(backfill), isNull);
    expect(
      CompletedSessionResultProjection.fromRecords(record: backfill).durationSeconds,
      isNull,
    );
  });
}

TrainingSessionRecord _record({
  required DateTime startedAt,
  required DateTime? completedAt,
  int? storedDurationSeconds,
  SessionResultEntryMode entryMode = SessionResultEntryMode.live,
  SessionPerformedPrecision precision = SessionPerformedPrecision.timestamp,
}) {
  return TrainingSessionRecord(
    recordId: 'duration-record',
    athleteId: 'athlete',
    trainingSessionId: 4,
    status: TrainingSessionRecordStatus.completed,
    sessionSnapshot: const SessionPerformanceSnapshot(
      sourceProtocolId: 'protocol',
      sessionTitle: 'Strength',
    ),
    startedAt: startedAt,
    completedAt: completedAt,
    durationSeconds: storedDurationSeconds,
    entryMode: entryMode,
    performedPrecision: precision,
    performedOn: precision == SessionPerformedPrecision.date
        ? DateTime.utc(startedAt.year, startedAt.month, startedAt.day)
        : null,
  );
}
