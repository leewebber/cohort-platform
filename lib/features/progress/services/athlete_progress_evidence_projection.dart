import '../../../models/session_block_type.dart';
import '../../performance/models/training_session_record.dart';
import '../../performance/models/training_session_record_status.dart';
import '../../performance/services/performance_chronology.dart';
import '../../performance/services/strength_result_comparison.dart';
import '../models/progress_summary.dart';

/// Projects completed performance records into Progress facts.
///
/// Reuses [StrengthResultComparison]. Does not infer loads from prescriptions.
abstract final class AthleteProgressEvidenceProjection {
  static List<TrainingSessionRecord> completedRecords(
    List<TrainingSessionRecord> history,
  ) {
    return history
        .where(
          (record) => record.status == TrainingSessionRecordStatus.completed,
        )
        .toList(growable: false);
  }

  static int strengthSessionCount(List<TrainingSessionRecord> completed) {
    return completed.where(_isStrengthSession).length;
  }

  static int enduranceSessionCount(List<TrainingSessionRecord> completed) {
    return completed.where(_isEnduranceSession).length;
  }

  static List<ProgressSessionHistoryItem> historyItems(
    List<TrainingSessionRecord> completed,
  ) {
    final items = completed
        .map(
          (record) => ProgressSessionHistoryItem(
            completedAt: record.performanceChronologyAt,
            planName: record.sessionSnapshot.programmeTitle ??
                record.programmeId ??
                'Programme',
            sessionName: record.sessionSnapshot.sessionTitle,
            completionRatio: 1,
            duration: record.durationSeconds == null
                ? null
                : Duration(seconds: record.durationSeconds!),
            sessionRpe: record.overallRpe,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byDate = b.completedAt.compareTo(a.completedAt);
        if (byDate != 0) return byDate;
        return a.sessionName.compareTo(b.sessionName);
      });
    return List.unmodifiable(items);
  }

  static List<ProgressExerciseBest> exerciseBests(
    List<TrainingSessionRecord> completed,
  ) {
    final latestByExercise = <String, ({
      TrainingExerciseResult exercise,
      TrainingSessionRecord record,
    })>{};
    final sorted = [...completed]
      ..sort(PerformanceChronology.compareNewestFirst);
    for (final record in sorted) {
      for (final block in record.blockResults) {
        if (block.blockSnapshot.blockType != SessionBlockType.strength) {
          continue;
        }
        for (final exercise in StrengthResultComparison.authoredExercises(
          block,
        )) {
          final id = exercise.sourceExerciseId.trim();
          if (id.isEmpty) continue;
          if (StrengthResultComparison.bestCompletedSet(exercise) == null) {
            continue;
          }
          latestByExercise.putIfAbsent(
            id,
            () => (exercise: exercise, record: record),
          );
        }
      }
    }

    final bests = <ProgressExerciseBest>[];
    for (final entry in latestByExercise.values) {
      final previous = StrengthResultComparison.previousExercise(
        exerciseId: entry.exercise.sourceExerciseId,
        current: entry.record,
        athleteHistory: completed,
      );
      final status = StrengthResultComparison.status(
        current: entry.exercise,
        previous: previous,
      );
      final best = StrengthResultComparison.bestSetValue(entry.exercise);
      if (best == null) continue;
      bests.add(
        ProgressExerciseBest(
          exerciseId: entry.exercise.sourceExerciseId,
          displayName: entry.exercise.exerciseSnapshot.displayName,
          bestSetLabel: best,
          comparisonLabel: status.semanticLabel,
          isFirstRecorded:
              status == StrengthExerciseComparisonStatus.baseline,
          comparisonImproved:
              status == StrengthExerciseComparisonStatus.improved,
        ),
      );
    }
    return List.unmodifiable(bests);
  }

  static bool _isStrengthSession(TrainingSessionRecord record) {
    return record.blockResults.any(
      (block) => block.blockSnapshot.blockType == SessionBlockType.strength,
    );
  }

  static bool _isEnduranceSession(TrainingSessionRecord record) {
    return record.blockResults.any((block) {
      final type = block.blockSnapshot.blockType;
      return type == SessionBlockType.conditioning;
    });
  }
}
