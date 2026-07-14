import '../../../data/repositories/training_session_circuit_repository.dart';
import '../../../models/circuit_performance.dart';
import '../../../models/circuit_score_type.dart';
import '../../../models/previous_circuit_performance.dart';
import '../../../models/training_session.dart';

/// Builds athlete-facing summaries from prior completed circuit sessions.
class PreviousCircuitPerformanceService {
  const PreviousCircuitPerformanceService({
    this.circuitRepository = const TrainingSessionCircuitRepository(),
  });

  final TrainingSessionCircuitRepository circuitRepository;

  Future<PreviousCircuitPerformance?> load({
    required String athleteId,
    required String protocolId,
    int? excludeTrainingSessionId,
    int? prescribedIntervalCount,
  }) async {
    final sessionData =
        await circuitRepository.getLatestCompletedComparableSession(
      athleteId: athleteId,
      protocolId: protocolId,
      excludeTrainingSessionId: excludeTrainingSessionId,
    );

    if (sessionData == null) {
      return null;
    }

    return buildFromSession(
      session: sessionData.session,
      performance: sessionData.performance,
      prescribedIntervalCount: prescribedIntervalCount,
    );
  }

  PreviousCircuitPerformance? buildFromSession({
    required TrainingSession session,
    required CircuitPerformance performance,
    int? prescribedIntervalCount,
  }) {
    if (!performance.completed) {
      return null;
    }

    final displaySummary = _displaySummary(
      performance: performance,
      prescribedIntervalCount: prescribedIntervalCount,
    );

    if (displaySummary == null || displaySummary.trim().isEmpty) {
      return null;
    }

    return PreviousCircuitPerformance(
      completedAt: session.completedAt,
      circuitFormat: performance.circuitFormat,
      scoreType: performance.scoreType,
      elapsedDuration: performance.elapsedDuration,
      completedRounds: performance.completedRounds,
      additionalReps: performance.additionalReps,
      totalReps: performance.totalReps,
      completedIntervals: performance.completedIntervals,
      actualLoad: performance.actualLoad,
      averageRpe: performance.rpe,
      athleteNote: performance.athleteNote,
      timeCapped: performance.timeCapped,
      completedMovements: performance.completedMovements,
      displaySummary: displaySummary,
      todayOpportunities: PreviousCircuitPerformance.defaultTodayOpportunities,
    );
  }

  String? _displaySummary({
    required CircuitPerformance performance,
    int? prescribedIntervalCount,
  }) {
    return switch (performance.scoreType) {
      CircuitScoreType.roundsAndReps => _roundsAndRepsSummary(performance),
      CircuitScoreType.elapsedTime => _elapsedSummary(performance),
      CircuitScoreType.roundsCompleted => _intervalsSummary(
          performance,
          prescribedIntervalCount,
        ),
      CircuitScoreType.totalReps => performance.totalReps == null
          ? null
          : '${performance.totalReps} reps',
      CircuitScoreType.movementsCompleted =>
        performance.completedMovements == null
            ? null
            : '${performance.completedMovements} movements',
      CircuitScoreType.benchmarkScore =>
        _elapsedSummary(performance) ?? _roundsAndRepsSummary(performance),
    };
  }

  String? _roundsAndRepsSummary(CircuitPerformance performance) {
    if (performance.completedRounds == null &&
        performance.additionalReps == null) {
      return null;
    }

    final rounds = performance.completedRounds ?? 0;
    final reps = performance.additionalReps ?? 0;

    if (reps > 0) {
      return '$rounds rounds + $reps reps';
    }

    if (rounds > 0) {
      return '$rounds rounds';
    }

    return null;
  }

  String? _elapsedSummary(CircuitPerformance performance) {
    final seconds = performance.elapsedDurationSeconds;
    if (seconds == null || seconds <= 0) {
      return null;
    }

    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String? _intervalsSummary(
    CircuitPerformance performance,
    int? prescribedIntervalCount,
  ) {
    final completed =
        performance.completedIntervals ?? performance.completedRounds;
    if (completed == null) {
      return null;
    }

    if (prescribedIntervalCount != null) {
      return '$completed / $prescribedIntervalCount intervals';
    }

    return '$completed intervals';
  }
}
