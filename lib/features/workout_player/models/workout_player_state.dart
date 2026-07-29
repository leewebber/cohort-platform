import '../../session/models/session_execution_plan.dart';
import 'workout_player_exercise_step.dart';
import 'workout_session_brief.dart';

enum WorkoutPlayerPhase { overview, active, complete }

/// In-memory workout execution state. Designed for later persistence.
class WorkoutPlayerState {
  const WorkoutPlayerState({
    required this.plan,
    required this.brief,
    required this.steps,
    required this.phase,
    required this.currentExerciseIndex,
    required this.currentSet,
    required this.completedExerciseIndexes,
    this.startedAt,
    this.completedAt,
    this.sessionRpe,
    this.notes,
    this.orchestrationId,
  });

  final SessionExecutionPlan plan;
  final WorkoutSessionBrief brief;
  final List<WorkoutPlayerExerciseStep> steps;
  final WorkoutPlayerPhase phase;
  final int currentExerciseIndex;
  final int currentSet;
  final Set<int> completedExerciseIndexes;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? sessionRpe;
  final String? notes;
  final String? orchestrationId;

  bool get isComplete => phase == WorkoutPlayerPhase.complete;

  WorkoutPlayerExerciseStep? get currentStep {
    if (steps.isEmpty) return null;
    if (currentExerciseIndex < 0 || currentExerciseIndex >= steps.length) {
      return null;
    }
    return steps[currentExerciseIndex];
  }

  int get totalExercises => steps.length;

  int get completedExerciseCount => completedExerciseIndexes.length;

  double get sessionProgress {
    if (steps.isEmpty) return 1;
    var doneSets = 0;
    var totalSets = 0;
    for (var i = 0; i < steps.length; i++) {
      final sets = steps[i].totalSets;
      totalSets += sets;
      if (completedExerciseIndexes.contains(i)) {
        doneSets += sets;
      } else if (i == currentExerciseIndex && phase == WorkoutPlayerPhase.active) {
        doneSets += (currentSet - 1).clamp(0, sets);
      }
    }
    if (totalSets == 0) return 0;
    return (doneSets / totalSets).clamp(0.0, 1.0);
  }

  double get exerciseProgress {
    final step = currentStep;
    if (step == null || step.totalSets <= 0) return 0;
    if (completedExerciseIndexes.contains(currentExerciseIndex)) return 1;
    return ((currentSet - 1) / step.totalSets).clamp(0.0, 1.0);
  }

  int get remainingSetsInExercise {
    final step = currentStep;
    if (step == null) return 0;
    if (completedExerciseIndexes.contains(currentExerciseIndex)) return 0;
    return (step.totalSets - currentSet + 1).clamp(0, step.totalSets);
  }

  Duration? get elapsed {
    final start = startedAt;
    if (start == null) return null;
    final end = completedAt ?? DateTime.now().toUtc();
    return end.difference(start);
  }

  int? get estimatedRemainingMinutes {
    final total = brief.estimatedDurationMinutes;
    if (total == null || total <= 0) return null;
    final remaining = (total * (1 - sessionProgress)).round();
    return remaining.clamp(0, total);
  }

  /// Snapshot suitable for future persistence (no Flutter types).
  Map<String, dynamic> toPersistenceMap() {
    return {
      'sessionId': plan.sessionId,
      'orchestrationId': orchestrationId,
      'phase': phase.name,
      'currentExerciseIndex': currentExerciseIndex,
      'currentSet': currentSet,
      'completedExerciseIndexes': completedExerciseIndexes.toList()..sort(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'sessionRpe': sessionRpe,
      'notes': notes,
    };
  }

  WorkoutPlayerState copyWith({
    WorkoutPlayerPhase? phase,
    int? currentExerciseIndex,
    int? currentSet,
    Set<int>? completedExerciseIndexes,
    DateTime? startedAt,
    DateTime? completedAt,
    int? sessionRpe,
    String? notes,
    bool clearCompletedAt = false,
  }) {
    return WorkoutPlayerState(
      plan: plan,
      brief: brief,
      steps: steps,
      phase: phase ?? this.phase,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      currentSet: currentSet ?? this.currentSet,
      completedExerciseIndexes:
          completedExerciseIndexes ?? this.completedExerciseIndexes,
      startedAt: startedAt ?? this.startedAt,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      sessionRpe: sessionRpe ?? this.sessionRpe,
      notes: notes ?? this.notes,
      orchestrationId: orchestrationId,
    );
  }
}
