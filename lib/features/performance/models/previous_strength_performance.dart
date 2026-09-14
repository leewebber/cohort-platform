import 'performance_snapshot.dart';
import '../services/strength_result_comparison.dart';

/// One completed prior strength set. Descriptive only — never copied into today.
class PreviousStrengthSetEvidence {
  const PreviousStrengthSetEvidence({
    required this.setNumber,
    this.reps,
    this.load,
    this.loadUnit,
    this.rpe,
  });

  final int setNumber;
  final int? reps;
  final double? load;
  final String? loadUnit;
  final int? rpe;

  bool get hasActuals => reps != null || load != null;

  String get ghostLine {
    final loadText = StrengthLoadDisplay.format(
      load: load,
      loadUnit: loadUnit,
      kind: load == null || load == 0
          ? StrengthActualLoadKind.bodyweight
          : StrengthActualLoadKind.external,
    );
    if (loadText != null && reps != null) {
      return 'Last: $loadText × $reps';
    }
    if (loadText != null) return 'Last: $loadText';
    if (reps != null) return 'Last: $reps reps';
    return 'Last: —';
  }
}

/// Latest valid prior strength result for one canonical exercise.
class PreviousStrengthExerciseEvidence {
  const PreviousStrengthExerciseEvidence({
    required this.exerciseId,
    required this.recordId,
    required this.performedAt,
    required this.sets,
  });

  final String exerciseId;
  final String recordId;
  final DateTime performedAt;
  final List<PreviousStrengthSetEvidence> sets;

  int get completedSetCount => sets.length;

  PreviousStrengthSetEvidence? setForNumber(int setNumber) {
    for (final set in sets) {
      if (set.setNumber == setNumber) return set;
    }
    return null;
  }

  PreviousStrengthSetEvidence? get topSet {
    PreviousStrengthSetEvidence? best;
    for (final set in sets) {
      if (!set.hasActuals) continue;
      if (best == null) {
        best = set;
        continue;
      }
      final bestLoad = best.load ?? 0;
      final candidateLoad = set.load ?? 0;
      if (candidateLoad > bestLoad) {
        best = set;
        continue;
      }
      if (candidateLoad == bestLoad &&
          (set.reps ?? 0) > (best.reps ?? 0)) {
        best = set;
      }
    }
    return best;
  }

  String get summaryLine {
    final parts = <String>['$completedSetCount sets'];
    final top = topSet;
    if (top != null) {
      final loadText = StrengthLoadDisplay.format(
        load: top.load,
        loadUnit: top.loadUnit,
        kind: top.load == null || top.load == 0
            ? StrengthActualLoadKind.bodyweight
            : StrengthActualLoadKind.external,
      );
      if (loadText != null && top.reps != null) {
        parts.add('top $loadText × ${top.reps}');
      } else if (loadText != null) {
        parts.add('top $loadText');
      } else if (top.reps != null) {
        parts.add('top ${top.reps} reps');
      }
    }
    return parts.join(' · ');
  }
}

enum PreviousStrengthHistoryStatus { idle, loading, ready, failed }

class PreviousStrengthHistoryState {
  const PreviousStrengthHistoryState._({
    required this.status,
    this.byExerciseId = const {},
  });

  const PreviousStrengthHistoryState.idle()
    : this._(status: PreviousStrengthHistoryStatus.idle);

  const PreviousStrengthHistoryState.loading()
    : this._(status: PreviousStrengthHistoryStatus.loading);

  const PreviousStrengthHistoryState.ready(
    Map<String, PreviousStrengthExerciseEvidence> byExerciseId,
  ) : this._(
        status: PreviousStrengthHistoryStatus.ready,
        byExerciseId: byExerciseId,
      );

  const PreviousStrengthHistoryState.failed()
    : this._(status: PreviousStrengthHistoryStatus.failed);

  final PreviousStrengthHistoryStatus status;
  final Map<String, PreviousStrengthExerciseEvidence> byExerciseId;

  bool get isLoading => status == PreviousStrengthHistoryStatus.loading;
  bool get isFailed => status == PreviousStrengthHistoryStatus.failed;
  bool get isReady => status == PreviousStrengthHistoryStatus.ready;
}
