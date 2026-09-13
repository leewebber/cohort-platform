import '../models/session_result_entry_mode.dart';
import '../models/training_session_record.dart';

/// Athletic chronology. Never uses recorded/created/entry time.
abstract final class PerformanceChronology {
  static DateTime dateKey(TrainingSessionRecord record) {
    final at = record.performanceChronologyAt.toUtc();
    return DateTime.utc(at.year, at.month, at.day);
  }

  static bool usesDatePrecision(TrainingSessionRecord record) {
    return record.performedPrecision == SessionPerformedPrecision.date ||
        record.entryMode == SessionResultEntryMode.backfill;
  }

  static int compare(TrainingSessionRecord a, TrainingSessionRecord b) {
    final byDate = dateKey(a).compareTo(dateKey(b));
    if (byDate != 0) return byDate;
    if (usesDatePrecision(a) || usesDatePrecision(b)) {
      return a.recordId.compareTo(b.recordId);
    }
    return a.performanceChronologyAt.compareTo(b.performanceChronologyAt);
  }

  static int compareNewestFirst(
    TrainingSessionRecord a,
    TrainingSessionRecord b,
  ) {
    final byDate = dateKey(b).compareTo(dateKey(a));
    if (byDate != 0) return byDate;
    if (usesDatePrecision(a) || usesDatePrecision(b)) {
      return a.recordId.compareTo(b.recordId);
    }
    return b.performanceChronologyAt.compareTo(a.performanceChronologyAt);
  }
}
