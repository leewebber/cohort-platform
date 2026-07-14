import 'circuit_data_source.dart';

/// Performed circuit score for one training session attempt.
///
/// Circuit scoring is session-level in v0.1 — one row captures the athlete's
/// result for the programmed format. Chipper partial progress uses
/// [completedMovements]; AMRAP uses [completedRounds] + [additionalReps].
///
/// See `07 Documentation/39_Circuit_Execution_Engine.md`.
class CircuitPerformanceEntry {
  const CircuitPerformanceEntry({
    required this.localId,
    this.elapsedDuration,
    this.completedRounds,
    this.additionalReps,
    this.totalReps,
    this.completedMovements,
    this.prescribedLoad,
    this.actualLoad,
    this.rpe,
    this.completed = false,
    this.timeCapped = false,
    this.athleteNote,
    this.dataSource = CircuitDataSource.manual,
  });

  /// Client-stable identity for in-session state and future resume hydration.
  final String localId;

  /// Total elapsed working time when the format scores by duration.
  final Duration? elapsedDuration;

  /// Full rounds completed, e.g. `5` in a `5+12` AMRAP score.
  final int? completedRounds;

  /// Reps into the next incomplete round, e.g. `12` in `5+12`.
  final int? additionalReps;

  /// Aggregate rep count when the format scores total reps.
  final int? totalReps;

  /// Movements finished in chipper-style sessions.
  final int? completedMovements;

  /// Prescribed load snapshot for comparison, e.g. `43 kg`.
  final String? prescribedLoad;

  /// Actual load used when it differs from prescription or is logged explicitly.
  final String? actualLoad;

  /// Optional post-effort RPE (1–10).
  final int? rpe;

  /// True when the athlete finished or submitted a final score.
  final bool completed;

  /// True when the result was stopped by a programmed time cap.
  final bool timeCapped;

  final String? athleteNote;
  final CircuitDataSource dataSource;

  bool get hasRecordedScore {
    return elapsedDuration != null ||
        completedRounds != null ||
        additionalReps != null ||
        totalReps != null ||
        completedMovements != null ||
        rpe != null ||
        (athleteNote?.trim().isNotEmpty ?? false);
  }

  String? get displayScoreSummary {
    if (completedRounds != null || additionalReps != null) {
      final rounds = completedRounds ?? 0;
      final reps = additionalReps ?? 0;
      if (reps > 0) {
        return '$rounds+$reps';
      }

      return rounds > 0 ? '$rounds rounds' : null;
    }

    if (elapsedDuration != null) {
      final totalSeconds = elapsedDuration!.inSeconds;
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }

    if (totalReps != null) {
      return '$totalReps reps';
    }

    if (completedMovements != null) {
      return '$completedMovements movements';
    }

    return null;
  }

  CircuitPerformanceEntry copyWith({
    String? localId,
    Duration? elapsedDuration,
    int? completedRounds,
    int? additionalReps,
    int? totalReps,
    int? completedMovements,
    String? prescribedLoad,
    String? actualLoad,
    int? rpe,
    bool? completed,
    bool? timeCapped,
    String? athleteNote,
    CircuitDataSource? dataSource,
    bool clearElapsedDuration = false,
    bool clearCompletedRounds = false,
    bool clearAdditionalReps = false,
    bool clearTotalReps = false,
    bool clearCompletedMovements = false,
    bool clearPrescribedLoad = false,
    bool clearActualLoad = false,
    bool clearRpe = false,
    bool clearAthleteNote = false,
  }) {
    return CircuitPerformanceEntry(
      localId: localId ?? this.localId,
      elapsedDuration: clearElapsedDuration
          ? null
          : (elapsedDuration ?? this.elapsedDuration),
      completedRounds: clearCompletedRounds
          ? null
          : (completedRounds ?? this.completedRounds),
      additionalReps: clearAdditionalReps
          ? null
          : (additionalReps ?? this.additionalReps),
      totalReps: clearTotalReps ? null : (totalReps ?? this.totalReps),
      completedMovements: clearCompletedMovements
          ? null
          : (completedMovements ?? this.completedMovements),
      prescribedLoad:
          clearPrescribedLoad ? null : (prescribedLoad ?? this.prescribedLoad),
      actualLoad: clearActualLoad ? null : (actualLoad ?? this.actualLoad),
      rpe: clearRpe ? null : (rpe ?? this.rpe),
      completed: completed ?? this.completed,
      timeCapped: timeCapped ?? this.timeCapped,
      athleteNote: clearAthleteNote ? null : (athleteNote ?? this.athleteNote),
      dataSource: dataSource ?? this.dataSource,
    );
  }
}
