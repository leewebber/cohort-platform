/// Typed execution results captured during Workout Player (extension points).
sealed class ExerciseExecutionResult {
  const ExerciseExecutionResult({
    required this.resultId,
    required this.exerciseId,
    required this.completedAt,
    required this.completionId,
    this.sessionId,
    this.abandoned = false,
  });

  final String resultId;
  final String exerciseId;
  final DateTime completedAt;
  final String completionId;
  final String? sessionId;
  final bool abandoned;

  Map<String, dynamic> toPersistenceMap();

  static ExerciseExecutionResult fromPersistenceMap(Map<String, dynamic> map) {
    final kind = map['kind']?.toString() ?? 'strength';
    return switch (kind) {
      'runningInterval' => RunningIntervalExecutionResult.fromPersistenceMap(map),
      'timedConditioning' =>
        TimedConditioningExecutionResult.fromPersistenceMap(map),
      _ => StrengthExecutionResult.fromPersistenceMap(map),
    };
  }
}

class StrengthExecutionResult extends ExerciseExecutionResult {
  const StrengthExecutionResult({
    required super.resultId,
    required super.exerciseId,
    required super.completedAt,
    required super.completionId,
    required this.setIndex,
    super.sessionId,
    this.prescribedReps,
    this.completedReps,
    this.load,
    this.loadUnit,
    this.rpe,
    this.totalSets,
    super.abandoned = false,
  });

  final int setIndex;
  final int? prescribedReps;
  final int? completedReps;
  final double? load;
  final String? loadUnit;
  final int? rpe;
  final int? totalSets;

  @override
  Map<String, dynamic> toPersistenceMap() => {
    'kind': 'strength',
    'resultId': resultId,
    'exerciseId': exerciseId,
    'completedAt': completedAt.toIso8601String(),
    'completionId': completionId,
    'sessionId': sessionId,
    'abandoned': abandoned,
    'setIndex': setIndex,
    'prescribedReps': prescribedReps,
    'completedReps': completedReps,
    'load': load,
    'loadUnit': loadUnit,
    'rpe': rpe,
    'totalSets': totalSets,
  };

  factory StrengthExecutionResult.fromPersistenceMap(Map<String, dynamic> map) {
    return StrengthExecutionResult(
      resultId: map['resultId']?.toString() ?? '',
      exerciseId: map['exerciseId']?.toString() ?? '',
      completedAt: DateTime.parse(map['completedAt'].toString()).toUtc(),
      completionId: map['completionId']?.toString() ?? '',
      sessionId: map['sessionId']?.toString(),
      abandoned: map['abandoned'] == true,
      setIndex: (map['setIndex'] as num?)?.toInt() ?? 0,
      prescribedReps: (map['prescribedReps'] as num?)?.toInt(),
      completedReps: (map['completedReps'] as num?)?.toInt(),
      load: (map['load'] as num?)?.toDouble(),
      loadUnit: map['loadUnit']?.toString(),
      rpe: (map['rpe'] as num?)?.toInt(),
      totalSets: (map['totalSets'] as num?)?.toInt(),
    );
  }
}

class RunningIntervalExecutionResult extends ExerciseExecutionResult {
  const RunningIntervalExecutionResult({
    required super.resultId,
    required super.exerciseId,
    required super.completedAt,
    required super.completionId,
    required this.intervalIndex,
    super.sessionId,
    this.distance,
    this.distanceUnit,
    this.duration,
    this.paceSecondsPerKm,
    this.rpe,
    this.totalIntervals,
    super.abandoned = false,
  });

  final int intervalIndex;
  final double? distance;
  final String? distanceUnit;
  final Duration? duration;
  final double? paceSecondsPerKm;
  final int? rpe;
  final int? totalIntervals;

  @override
  Map<String, dynamic> toPersistenceMap() => {
    'kind': 'runningInterval',
    'resultId': resultId,
    'exerciseId': exerciseId,
    'completedAt': completedAt.toIso8601String(),
    'completionId': completionId,
    'sessionId': sessionId,
    'abandoned': abandoned,
    'intervalIndex': intervalIndex,
    'distance': distance,
    'distanceUnit': distanceUnit,
    'durationSeconds': duration?.inSeconds,
    'paceSecondsPerKm': paceSecondsPerKm,
    'rpe': rpe,
    'totalIntervals': totalIntervals,
  };

  factory RunningIntervalExecutionResult.fromPersistenceMap(
    Map<String, dynamic> map,
  ) {
    final seconds = (map['durationSeconds'] as num?)?.toInt();
    return RunningIntervalExecutionResult(
      resultId: map['resultId']?.toString() ?? '',
      exerciseId: map['exerciseId']?.toString() ?? '',
      completedAt: DateTime.parse(map['completedAt'].toString()).toUtc(),
      completionId: map['completionId']?.toString() ?? '',
      sessionId: map['sessionId']?.toString(),
      abandoned: map['abandoned'] == true,
      intervalIndex: (map['intervalIndex'] as num?)?.toInt() ?? 0,
      distance: (map['distance'] as num?)?.toDouble(),
      distanceUnit: map['distanceUnit']?.toString(),
      duration: seconds == null ? null : Duration(seconds: seconds),
      paceSecondsPerKm: (map['paceSecondsPerKm'] as num?)?.toDouble(),
      rpe: (map['rpe'] as num?)?.toInt(),
      totalIntervals: (map['totalIntervals'] as num?)?.toInt(),
    );
  }
}

class TimedConditioningExecutionResult extends ExerciseExecutionResult {
  const TimedConditioningExecutionResult({
    required super.resultId,
    required super.exerciseId,
    required super.completedAt,
    required super.completionId,
    super.sessionId,
    this.duration,
    this.distance,
    this.rounds,
    this.reps,
    this.load,
    this.rpe,
    super.abandoned = false,
  });

  final Duration? duration;
  final double? distance;
  final int? rounds;
  final int? reps;
  final double? load;
  final int? rpe;

  @override
  Map<String, dynamic> toPersistenceMap() => {
    'kind': 'timedConditioning',
    'resultId': resultId,
    'exerciseId': exerciseId,
    'completedAt': completedAt.toIso8601String(),
    'completionId': completionId,
    'sessionId': sessionId,
    'abandoned': abandoned,
    'durationSeconds': duration?.inSeconds,
    'distance': distance,
    'rounds': rounds,
    'reps': reps,
    'load': load,
    'rpe': rpe,
  };

  factory TimedConditioningExecutionResult.fromPersistenceMap(
    Map<String, dynamic> map,
  ) {
    final seconds = (map['durationSeconds'] as num?)?.toInt();
    return TimedConditioningExecutionResult(
      resultId: map['resultId']?.toString() ?? '',
      exerciseId: map['exerciseId']?.toString() ?? '',
      completedAt: DateTime.parse(map['completedAt'].toString()).toUtc(),
      completionId: map['completionId']?.toString() ?? '',
      sessionId: map['sessionId']?.toString(),
      abandoned: map['abandoned'] == true,
      duration: seconds == null ? null : Duration(seconds: seconds),
      distance: (map['distance'] as num?)?.toDouble(),
      rounds: (map['rounds'] as num?)?.toInt(),
      reps: (map['reps'] as num?)?.toInt(),
      load: (map['load'] as num?)?.toDouble(),
      rpe: (map['rpe'] as num?)?.toInt(),
    );
  }
}

/// Lightweight in-progress workout snapshot.
class WorkoutProgressSnapshot {
  const WorkoutProgressSnapshot({
    required this.sessionId,
    required this.athleteId,
    required this.currentExerciseIndex,
    required this.currentSet,
    required this.completedExerciseIndexes,
    required this.startedAt,
    required this.lastUpdatedAt,
    this.assignmentId,
    this.phase = 'active',
    this.enteredResults = const [],
  });

  final String sessionId;
  final String athleteId;
  final String? assignmentId;
  final int currentExerciseIndex;
  final int currentSet;
  final List<int> completedExerciseIndexes;
  final DateTime startedAt;
  final DateTime lastUpdatedAt;
  final String phase;
  final List<Map<String, dynamic>> enteredResults;

  Map<String, dynamic> toPersistenceMap() => {
    'sessionId': sessionId,
    'athleteId': athleteId,
    'assignmentId': assignmentId,
    'currentExerciseIndex': currentExerciseIndex,
    'currentSet': currentSet,
    'completedExerciseIndexes': completedExerciseIndexes,
    'startedAt': startedAt.toIso8601String(),
    'lastUpdatedAt': lastUpdatedAt.toIso8601String(),
    'phase': phase,
    'enteredResults': enteredResults,
  };

  factory WorkoutProgressSnapshot.fromPersistenceMap(Map<String, dynamic> map) {
    return WorkoutProgressSnapshot(
      sessionId: map['sessionId']?.toString() ?? '',
      athleteId: map['athleteId']?.toString() ?? '',
      assignmentId: map['assignmentId']?.toString(),
      currentExerciseIndex:
          (map['currentExerciseIndex'] as num?)?.toInt() ?? 0,
      currentSet: (map['currentSet'] as num?)?.toInt() ?? 1,
      completedExerciseIndexes: (map['completedExerciseIndexes'] as List? ??
              const [])
          .map((e) => (e as num).toInt())
          .toList(),
      startedAt: DateTime.parse(map['startedAt'].toString()).toUtc(),
      lastUpdatedAt: DateTime.parse(map['lastUpdatedAt'].toString()).toUtc(),
      phase: map['phase']?.toString() ?? 'active',
      enteredResults: (map['enteredResults'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(),
    );
  }
}
