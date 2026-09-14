import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import '../services/performance_chronology.dart';

/// Shared eligibility for observational progression.
abstract final class EligiblePerformanceEvidence {
  static const terminalStatuses = {
    TrainingSessionRecordStatus.completed,
    TrainingSessionRecordStatus.partiallyCompleted,
  };

  static bool isEligibleRecord(TrainingSessionRecord record) {
    if (!terminalStatuses.contains(record.status)) return false;
    return true;
  }

  static bool isEligiblePrior({
    required TrainingSessionRecord candidate,
    required TrainingSessionRecord current,
  }) {
    if (candidate.athleteId != current.athleteId) return false;
    if (candidate.recordId == current.recordId) return false;
    if (!isEligibleRecord(candidate)) return false;
    return candidate.performanceChronologyAt.isBefore(
      current.performanceChronologyAt,
    );
  }

  static List<TrainingSessionRecord> priorsNewestFirst({
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    return [
      for (final record in athleteHistory)
        if (isEligiblePrior(candidate: record, current: current)) record,
    ]..sort(PerformanceChronology.compareNewestFirst);
  }

  static bool setHasActuals(TrainingSetResult set) {
    if (!set.completed) return false;
    if (set.reps != null && set.reps! > 0) return true;
    if (set.load != null && set.load! > 0) return true;
    return false;
  }

  static List<TrainingSetResult> completedActualSets(
    TrainingExerciseResult exercise,
  ) {
    return [
      for (final set
          in List<TrainingSetResult>.from(exercise.setResults)..sort((a, b) {
            final byNumber = a.setNumber.compareTo(b.setNumber);
            if (byNumber != 0) return byNumber;
            return a.position.compareTo(b.position);
          }))
        if (setHasActuals(set)) set,
    ];
  }
}
