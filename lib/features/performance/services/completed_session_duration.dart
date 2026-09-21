import '../models/training_session_record.dart';
import 'performance_chronology.dart';

/// Session elapsed time from ordered instants. Timezone affects display only.
abstract final class CompletedSessionDuration {
  const CompletedSessionDuration._();

  static int? fromRecord(TrainingSessionRecord record) {
    if (PerformanceChronology.usesDatePrecision(record)) {
      return null;
    }
    return fromInstants(
      startedAt: record.startedAt,
      completedAt: record.completedAt,
    );
  }

  static int? fromInstants({
    required DateTime startedAt,
    DateTime? completedAt,
  }) {
    if (completedAt == null) return null;
    final elapsed = completedAt.toUtc().difference(startedAt.toUtc()).inSeconds;
    if (elapsed <= 0) return null;
    return elapsed;
  }
}
