import '../../../models/session_block_type.dart';
import '../models/performance_result_type.dart';
import '../models/performance_snapshot.dart';
import '../models/training_block_result_status.dart';
import '../models/training_session_record.dart';
import 'endurance_metrics_calculator.dart';
import 'performance_result_summary_formatter.dart';
import 'strength_result_comparison.dart';

export 'strength_result_comparison.dart';

class CompletedSessionResultProjection {
  const CompletedSessionResultProjection({
    required this.sessionTitle,
    required this.completedAt,
    required this.durationSeconds,
    required this.overallRpe,
    required this.completedBlockCount,
    required this.skippedBlockCount,
    required this.incompleteBlockCount,
    required this.blocks,
  });

  final String sessionTitle;
  final DateTime? completedAt;
  final int? durationSeconds;
  final int? overallRpe;
  final int completedBlockCount;
  final int skippedBlockCount;
  final int incompleteBlockCount;
  final List<CompletedBlockResultProjection> blocks;

  factory CompletedSessionResultProjection.fromRecords({
    required TrainingSessionRecord record,
    List<TrainingSessionRecord> athleteHistory = const [],
  }) {
    final blocks = record.blockResults
        .map(
          (block) => CompletedBlockResultProjection.fromBlock(
            block,
            current: record,
            athleteHistory: athleteHistory,
          ),
        )
        .toList(growable: false);
    return CompletedSessionResultProjection(
      sessionTitle: record.sessionSnapshot.sessionTitle,
      completedAt: record.completedAt,
      durationSeconds: record.durationSeconds,
      overallRpe: record.overallRpe,
      completedBlockCount: record.completedBlockCount,
      skippedBlockCount: record.blockResults
          .where((block) => block.status == TrainingBlockResultStatus.skipped)
          .length,
      incompleteBlockCount: record.blockResults
          .where(
            (block) =>
                block.status != TrainingBlockResultStatus.completed &&
                block.status != TrainingBlockResultStatus.skipped,
          )
          .length,
      blocks: blocks,
    );
  }
}

class CompletedBlockResultProjection {
  const CompletedBlockResultProjection({
    required this.title,
    required this.statusLabel,
    required this.isSimpleCompletion,
    required this.summary,
    required this.exercises,
    this.prescriptionContext,
  });

  final String title;
  final String statusLabel;
  final bool isSimpleCompletion;
  final String summary;
  final List<CompletedExerciseResultProjection> exercises;
  final String? prescriptionContext;

  factory CompletedBlockResultProjection.fromBlock(
    TrainingBlockResult block, {
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final type = block.blockSnapshot.blockType;
    final isSimple =
        type == SessionBlockType.warmUp ||
        type == SessionBlockType.coolDown ||
        (block.resultType == PerformanceResultType.completion &&
            block.exerciseResults.every(
              (exercise) => exercise.setResults.isEmpty,
            ));
    final exercises = StrengthResultComparison.authoredExercises(block)
        .map(
          (exercise) => CompletedExerciseResultProjection.fromExercise(
            exercise,
            current: current,
            athleteHistory: athleteHistory,
          ),
        )
        .toList(growable: false);
    final prescription = block.blockSnapshot.content.trim();
    return CompletedBlockResultProjection(
      title: block.blockSnapshot.title,
      statusLabel: block.status.displayLabel,
      isSimpleCompletion: isSimple,
      summary: isSimple
          ? PerformanceResultSummaryFormatter.formatBlock(block)
          : _blockHeadline(block, exercises),
      exercises: exercises,
      prescriptionContext: prescription.isEmpty ? null : prescription,
    );
  }

  static String _blockHeadline(
    TrainingBlockResult block,
    List<CompletedExerciseResultProjection> exercises,
  ) {
    if (block.resultType != PerformanceResultType.strength) {
      return PerformanceResultSummaryFormatter.formatBlock(block);
    }
    final setCount = exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    if (setCount == 0) {
      return PerformanceResultSummaryFormatter.formatBlock(block);
    }
    return '$setCount set${setCount == 1 ? '' : 's'} recorded';
  }
}

class CompletedExerciseResultProjection {
  const CompletedExerciseResultProjection({
    required this.sourceExerciseId,
    required this.displayName,
    required this.sets,
    required this.previousSets,
    required this.comparisonStatus,
    required this.comparisonLabel,
    this.bestSetLabel,
    this.estimated1RmLabel,
    this.volumeLabel,
    this.deltaLabels = const [],
  });

  final String sourceExerciseId;
  final String displayName;
  final List<CompletedSetResultProjection> sets;
  final List<CompletedSetResultProjection> previousSets;
  final StrengthExerciseComparisonStatus comparisonStatus;
  final String comparisonLabel;
  final String? bestSetLabel;
  final String? estimated1RmLabel;
  final String? volumeLabel;
  final List<String> deltaLabels;

  factory CompletedExerciseResultProjection.fromExercise(
    TrainingExerciseResult exercise, {
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final kind = exercise.exerciseSnapshot.loadKind;
    final sets = StrengthResultComparison.authoredSets(exercise)
        .map(
          (set) => CompletedSetResultProjection.fromSet(set, loadKind: kind),
        )
        .toList(growable: false);
    final previous = StrengthResultComparison.previousExercise(
      exerciseId: exercise.sourceExerciseId,
      current: current,
      athleteHistory: athleteHistory,
    );
    final previousKind =
        previous?.exerciseSnapshot.loadKind ?? kind;
    final previousSets = previous == null
        ? const <CompletedSetResultProjection>[]
        : StrengthResultComparison.authoredSets(previous)
              .map(
                (set) => CompletedSetResultProjection.fromSet(
                  set,
                  loadKind: previousKind,
                ),
              )
              .toList(growable: false);
    final status = StrengthResultComparison.status(
      current: exercise,
      previous: previous,
    );
    return CompletedExerciseResultProjection(
      sourceExerciseId: exercise.sourceExerciseId,
      displayName: exercise.exerciseSnapshot.displayName.trim().isEmpty
          ? 'Movement'
          : exercise.exerciseSnapshot.displayName,
      sets: sets,
      previousSets: previousSets,
      comparisonStatus: status,
      comparisonLabel: status.label,
      bestSetLabel: StrengthResultComparison.bestSetLabel(exercise),
      estimated1RmLabel: StrengthResultComparison.estimated1RmLabel(exercise),
      volumeLabel: StrengthResultComparison.volumeLabel(exercise),
      deltaLabels: StrengthResultComparison.secondaryDeltas(
        current: exercise,
        previous: previous,
      ),
    );
  }
}

class CompletedSetResultProjection {
  const CompletedSetResultProjection({
    required this.setNumber,
    required this.stateLabel,
    this.repsLabel,
    this.loadLabel,
  });

  final int setNumber;
  final String stateLabel;
  final String? repsLabel;
  final String? loadLabel;

  factory CompletedSetResultProjection.fromSet(
    TrainingSetResult set, {
    required StrengthActualLoadKind loadKind,
  }) {
    return CompletedSetResultProjection(
      setNumber: set.setNumber,
      stateLabel: set.completed ? 'Completed' : 'Not completed',
      repsLabel: set.reps == null ? null : '${set.reps} reps',
      loadLabel: StrengthLoadDisplay.format(
        load: set.load,
        loadUnit: set.loadUnit,
        kind: loadKind,
      ),
    );
  }
}

String formatCompletedClock(DateTime value) {
  final local = value.toLocal();
  final months = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final time =
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return '${local.day} ${months[local.month - 1]} $time';
}

String formatCompletedDuration(int seconds) {
  return EnduranceMetricsCalculator.formatDuration(seconds).isEmpty
      ? '${seconds ~/ 60}m ${seconds % 60}s'
      : EnduranceMetricsCalculator.formatDuration(seconds);
}
