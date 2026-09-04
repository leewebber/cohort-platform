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
    this.lastCorrectedAt,
    required this.completedBlockCount,
    required this.skippedBlockCount,
    required this.incompleteBlockCount,
    required this.blocks,
  });

  final String sessionTitle;
  final DateTime? completedAt;
  final int? durationSeconds;
  final int? overallRpe;
  final DateTime? lastCorrectedAt;
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
      lastCorrectedAt: record.lastCorrectedAt,
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
    final summary = isSimple
        ? PerformanceResultSummaryFormatter.formatBlock(block)
        : _blockHeadline(block, exercises);
    return CompletedBlockResultProjection(
      title: block.blockSnapshot.title,
      statusLabel: block.status.displayLabel,
      isSimpleCompletion: isSimple,
      summary: summary,
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
    this.previousCompletedAt,
    this.bestSetLabel,
    this.estimated1RmLabel,
    this.volumeLabel,
    this.deltaLabels = const [],
    this.metrics = const [],
  });

  final String sourceExerciseId;
  final String displayName;
  final List<CompletedSetResultProjection> sets;
  final List<CompletedSetResultProjection> previousSets;
  final DateTime? previousCompletedAt;
  final StrengthExerciseComparisonStatus comparisonStatus;
  final String comparisonLabel;
  final String? bestSetLabel;
  final String? estimated1RmLabel;
  final String? volumeLabel;
  final List<String> deltaLabels;
  final List<CompletedPerformanceMetric> metrics;

  factory CompletedExerciseResultProjection.fromExercise(
    TrainingExerciseResult exercise, {
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final kind = exercise.exerciseSnapshot.loadKind;
    final previousOccurrence = StrengthResultComparison.previousOccurrence(
      exerciseId: exercise.sourceExerciseId,
      current: current,
      athleteHistory: athleteHistory,
    );
    final previous = previousOccurrence?.exercise;
    final bestSet = StrengthResultComparison.bestCompletedSet(exercise);
    final sets = StrengthResultComparison.authoredSets(exercise)
        .map(
          (set) => CompletedSetResultProjection.fromSet(
            set,
            loadKind: kind,
            isBestSet: bestSet != null && set.setNumber == bestSet.setNumber,
          ),
        )
        .toList(growable: false);
    final previousKind = previous?.exerciseSnapshot.loadKind ?? kind;
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
      previousCompletedAt: previousOccurrence?.completedAt,
      comparisonStatus: status,
      comparisonLabel: status.label,
      bestSetLabel: StrengthResultComparison.bestSetLabel(exercise),
      estimated1RmLabel: StrengthResultComparison.estimated1RmLabel(exercise),
      volumeLabel: StrengthResultComparison.volumeLabel(exercise),
      deltaLabels: StrengthResultComparison.secondaryDeltas(
        current: exercise,
        previous: previous,
      ),
      metrics: _metrics(current: exercise, previous: previous),
    );
  }

  static List<CompletedPerformanceMetric> _metrics({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    final metrics = <CompletedPerformanceMetric>[];
    final bestValue = StrengthResultComparison.bestSetValue(current);
    if (bestValue != null) {
      metrics.add(
        CompletedPerformanceMetric(
          key: 'best-set',
          title: 'Best Set',
          value: bestValue,
          deltaLabel: _bestSetDelta(current: current, previous: previous),
          tone: _loadTone(current: current, previous: previous),
        ),
      );
    }
    final current1Rm = StrengthResultComparison.estimated1RmMetric(current);
    if (current1Rm != null) {
      final previous1Rm = previous == null
          ? null
          : StrengthResultComparison.estimated1RmMetric(previous);
      final comparable =
          previous1Rm != null &&
          previous1Rm.unit.toLowerCase() == current1Rm.unit.toLowerCase();
      metrics.add(
        CompletedPerformanceMetric(
          key: 'estimated-1rm',
          title: 'Estimated 1RM',
          value:
              '${StrengthLoadDisplay.formatQuantity(current1Rm.value)} ${current1Rm.unit}',
          deltaLabel: comparable
              ? _signedDelta(
                  current1Rm.value - previous1Rm.value,
                  current1Rm.unit,
                )
              : null,
          tone: comparable
              ? _numericTone(current1Rm.value - previous1Rm.value)
              : StrengthMetricTone.none,
        ),
      );
    }
    final currentVolume = StrengthResultComparison.volumeMetric(current);
    if (currentVolume != null) {
      final previousVolume = previous == null
          ? null
          : StrengthResultComparison.volumeMetric(previous);
      final comparable =
          previousVolume != null &&
          previousVolume.unit.toLowerCase() == currentVolume.unit.toLowerCase();
      metrics.add(
        CompletedPerformanceMetric(
          key: 'working-volume',
          title: 'Working Volume',
          value:
              '${StrengthLoadDisplay.formatQuantity(currentVolume.value)} ${currentVolume.unit}',
          deltaLabel: comparable
              ? _signedDelta(
                  currentVolume.value - previousVolume.value,
                  currentVolume.unit,
                )
              : null,
          tone: comparable
              ? _numericTone(currentVolume.value - previousVolume.value)
              : StrengthMetricTone.none,
        ),
      );
    }
    return metrics;
  }

  static String? _bestSetDelta({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    if (previous == null) return null;
    final currentBest = StrengthResultComparison.bestCompletedSet(current);
    final previousBest = StrengthResultComparison.bestCompletedSet(previous);
    if (currentBest?.load == null ||
        currentBest!.load == 0 ||
        previousBest?.load == null ||
        previousBest!.load == 0) {
      return null;
    }
    final currentUnit = currentBest.loadUnit?.trim().isNotEmpty == true
        ? currentBest.loadUnit!.trim()
        : 'kg';
    final previousUnit = previousBest.loadUnit?.trim().isNotEmpty == true
        ? previousBest.loadUnit!.trim()
        : 'kg';
    if (currentUnit.toLowerCase() != previousUnit.toLowerCase()) return null;
    return _signedDelta(currentBest.load! - previousBest.load!, currentUnit);
  }

  static StrengthMetricTone _loadTone({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    if (previous == null) return StrengthMetricTone.none;
    final currentBest = StrengthResultComparison.bestCompletedSet(current);
    final previousBest = StrengthResultComparison.bestCompletedSet(previous);
    if (currentBest?.load == null || previousBest?.load == null) {
      return StrengthMetricTone.none;
    }
    return _numericTone(currentBest!.load! - previousBest!.load!);
  }

  static String? _signedDelta(double delta, String unit) {
    if (delta == 0) return null;
    final formatted = StrengthLoadDisplay.formatQuantity(delta.abs());
    return '${delta > 0 ? '+' : '-'}$formatted $unit';
  }

  static StrengthMetricTone _numericTone(double delta) {
    if (delta > 0) return StrengthMetricTone.positive;
    if (delta < 0) return StrengthMetricTone.negative;
    return StrengthMetricTone.neutral;
  }
}

enum StrengthMetricTone { positive, neutral, negative, none }

class CompletedPerformanceMetric {
  const CompletedPerformanceMetric({
    required this.key,
    required this.title,
    required this.value,
    this.deltaLabel,
    this.tone = StrengthMetricTone.none,
  });

  final String key;
  final String title;
  final String value;
  final String? deltaLabel;
  final StrengthMetricTone tone;
}

class CompletedSetResultProjection {
  const CompletedSetResultProjection({
    required this.setNumber,
    required this.completed,
    required this.stateLabel,
    this.reps,
    this.repsLabel,
    this.loadLabel,
    this.isBestSet = false,
  });

  final int setNumber;
  final bool completed;
  final String stateLabel;
  final int? reps;
  final String? repsLabel;
  final String? loadLabel;
  final bool isBestSet;

  factory CompletedSetResultProjection.fromSet(
    TrainingSetResult set, {
    required StrengthActualLoadKind loadKind,
    bool isBestSet = false,
  }) {
    return CompletedSetResultProjection(
      setNumber: set.setNumber,
      completed: set.completed,
      stateLabel: set.completed ? 'Completed' : 'Not completed',
      reps: set.reps,
      repsLabel: set.reps == null ? null : '${set.reps} reps',
      loadLabel: StrengthLoadDisplay.format(
        load: set.load,
        loadUnit: set.loadUnit,
        kind: loadKind,
      ),
      isBestSet: isBestSet,
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

String formatCompletedDate(DateTime value) {
  final local = value.toLocal();
  const months = [
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
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String formatCompletedDuration(int seconds) {
  return EnduranceMetricsCalculator.formatDuration(seconds).isEmpty
      ? '${seconds ~/ 60}m ${seconds % 60}s'
      : EnduranceMetricsCalculator.formatDuration(seconds);
}
