import 'circuit_score_type.dart';

/// Programmed circuit workout format derived from protocol metadata.
///
/// See `07 Documentation/39_Circuit_Execution_Engine.md`.
enum CircuitFormat {
  amrap,
  forTime,
  roundsForTime,
  emom,
  intervalClock,
  chipper,
  fixedDuration,
  benchmark,
}

/// Default score semantics for a programmed [CircuitFormat].
extension CircuitFormatDefaults on CircuitFormat {
  CircuitScoreType get defaultScoreType {
    return switch (this) {
      CircuitFormat.amrap => CircuitScoreType.roundsAndReps,
      CircuitFormat.forTime => CircuitScoreType.elapsedTime,
      CircuitFormat.roundsForTime => CircuitScoreType.elapsedTime,
      CircuitFormat.emom => CircuitScoreType.roundsCompleted,
      CircuitFormat.intervalClock => CircuitScoreType.roundsCompleted,
      CircuitFormat.chipper => CircuitScoreType.elapsedTime,
      CircuitFormat.fixedDuration => CircuitScoreType.totalReps,
      CircuitFormat.benchmark => CircuitScoreType.benchmarkScore,
    };
  }

  String get displayLabel {
    return switch (this) {
      CircuitFormat.amrap => 'AMRAP',
      CircuitFormat.forTime => 'For time',
      CircuitFormat.roundsForTime => 'Rounds for time',
      CircuitFormat.emom => 'EMOM',
      CircuitFormat.intervalClock => 'Interval clock',
      CircuitFormat.chipper => 'Chipper',
      CircuitFormat.fixedDuration => 'Fixed duration',
      CircuitFormat.benchmark => 'Benchmark',
    };
  }
}

/// Human-readable scoring guidance for athletes.
extension CircuitScoreTypeLabels on CircuitScoreType {
  String get athleteSummary {
    return switch (this) {
      CircuitScoreType.roundsAndReps =>
        'Score is rounds plus extra reps, e.g. 5+12.',
      CircuitScoreType.elapsedTime =>
        'Score is total time to finish.',
      CircuitScoreType.roundsCompleted =>
        'Score is rounds or intervals completed.',
      CircuitScoreType.totalReps =>
        'Score is total reps completed in the allotted time.',
      CircuitScoreType.movementsCompleted =>
        'Score is how far you got before the cap.',
      CircuitScoreType.benchmarkScore =>
        'Score follows the benchmark rules for this workout.',
    };
  }
}
