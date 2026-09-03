import '../../../models/session_block_type.dart';
import '../models/performance_result_type.dart';
import '../models/performance_snapshot.dart';
import '../models/training_block_result_status.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import 'endurance_metrics_calculator.dart';
import 'performance_result_summary_formatter.dart';

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
    final exercises = block.exerciseResults
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
    required this.displayName,
    required this.sets,
    required this.comparisonLabel,
    this.bestSetLabel,
    this.volumeLabel,
  });

  final String displayName;
  final List<CompletedSetResultProjection> sets;
  final String comparisonLabel;
  final String? bestSetLabel;
  final String? volumeLabel;

  factory CompletedExerciseResultProjection.fromExercise(
    TrainingExerciseResult exercise, {
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final kind = exercise.exerciseSnapshot.loadKind;
    final sets = exercise.setResults
        .map(
          (set) => CompletedSetResultProjection.fromSet(set, loadKind: kind),
        )
        .toList(growable: false);
    final previous = StrengthResultComparison.previousExercise(
      exerciseId: exercise.sourceExerciseId,
      current: current,
      athleteHistory: athleteHistory,
    );
    return CompletedExerciseResultProjection(
      displayName: exercise.exerciseSnapshot.displayName.trim().isEmpty
          ? 'Movement'
          : exercise.exerciseSnapshot.displayName,
      sets: sets,
      comparisonLabel: StrengthResultComparison.label(
        current: exercise,
        previous: previous,
      ),
      bestSetLabel: StrengthResultComparison.bestSetLabel(exercise),
      volumeLabel: StrengthResultComparison.volumeLabel(exercise),
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

class StrengthLoadDisplay {
  const StrengthLoadDisplay._();

  static String? format({
    required double? load,
    required String? loadUnit,
    required StrengthActualLoadKind kind,
  }) {
    if (kind == StrengthActualLoadKind.bodyweight) {
      return 'Bodyweight';
    }
    if (load == null || load == 0) {
      return null;
    }
    final unit = loadUnit?.trim();
    return '${_number(load)}${unit == null || unit.isEmpty ? ' kg' : ' $unit'}';
  }

  static String _number(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}

class StrengthResultComparison {
  const StrengthResultComparison._();

  static TrainingExerciseResult? previousExercise({
    required String exerciseId,
    required TrainingSessionRecord current,
    required List<TrainingSessionRecord> athleteHistory,
  }) {
    final id = exerciseId.trim();
    if (id.isEmpty) return null;
    final currentAt = current.completedAt ?? current.startedAt;
    TrainingExerciseResult? latest;
    DateTime? latestAt;
    for (final record in athleteHistory) {
      if (record.athleteId != current.athleteId) continue;
      if (record.recordId == current.recordId) continue;
      if (record.status != TrainingSessionRecordStatus.completed) continue;
      final at = record.completedAt ?? record.startedAt;
      if (!at.isBefore(currentAt)) continue;
      for (final block in record.blockResults) {
        for (final exercise in block.exerciseResults) {
          if (exercise.sourceExerciseId != id) continue;
          if (exercise.setResults.isEmpty) continue;
          if (latestAt == null || at.isAfter(latestAt)) {
            latest = exercise;
            latestAt = at;
          }
        }
      }
    }
    return latest;
  }

  static String label({
    required TrainingExerciseResult current,
    required TrainingExerciseResult? previous,
  }) {
    if (previous == null) return 'First recorded session';
    final parts = <String>[];
    final currentBest = _bestLoad(current);
    final previousBest = _bestLoad(previous);
    if (currentBest != null && previousBest != null) {
      final delta = currentBest - previousBest;
      if (delta != 0) {
        parts.add(
          '${delta > 0 ? '+' : ''}${StrengthLoadDisplay._number(delta)} kg best load',
        );
      }
    }
    final currentReps = _totalReps(current);
    final previousReps = _totalReps(previous);
    if (currentReps != null && previousReps != null && currentReps != previousReps) {
      final delta = currentReps - previousReps;
      parts.add('${delta > 0 ? '+' : ''}$delta reps');
    }
    final currentVolume = _volume(current);
    final previousVolume = _volume(previous);
    if (currentVolume != null &&
        previousVolume != null &&
        currentVolume != previousVolume) {
      final delta = currentVolume - previousVolume;
      parts.add(
        '${delta > 0 ? '+' : ''}${StrengthLoadDisplay._number(delta)} kg volume',
      );
    }
    if (parts.isEmpty) return 'Same as last recorded session';
    return 'vs last: ${parts.join(' · ')}';
  }

  static String? bestSetLabel(TrainingExerciseResult exercise) {
    TrainingSetResult? best;
    for (final set in exercise.setResults) {
      if (set.load == null || set.load == 0) continue;
      if (best == null ||
          set.load! > best.load! ||
          (set.load == best.load && (set.reps ?? 0) > (best.reps ?? 0))) {
        best = set;
      }
    }
    if (best == null) return null;
    final load = StrengthLoadDisplay.format(
      load: best.load,
      loadUnit: best.loadUnit,
      kind: StrengthActualLoadKind.external,
    );
    final reps = best.reps == null ? null : '${best.reps} reps';
    final parts = <String>[?load, ?reps];
    if (parts.isEmpty) return null;
    return 'Best set ${best.setNumber}: ${parts.join(' · ')}';
  }

  static String? volumeLabel(TrainingExerciseResult exercise) {
    final volume = _volume(exercise);
    if (volume == null) return null;
    return 'Volume ${StrengthLoadDisplay._number(volume)} kg';
  }

  static double? _bestLoad(TrainingExerciseResult exercise) {
    double? best;
    for (final set in exercise.setResults) {
      if (set.load == null || set.load == 0) continue;
      if (best == null || set.load! > best) best = set.load;
    }
    return best;
  }

  static int? _totalReps(TrainingExerciseResult exercise) {
    var total = 0;
    var any = false;
    for (final set in exercise.setResults) {
      if (set.reps == null) continue;
      any = true;
      total += set.reps!;
    }
    return any ? total : null;
  }

  static double? _volume(TrainingExerciseResult exercise) {
    var total = 0.0;
    var any = false;
    for (final set in exercise.setResults) {
      if (set.load == null || set.load == 0 || set.reps == null) continue;
      any = true;
      total += set.load! * set.reps!;
    }
    return any ? total : null;
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
