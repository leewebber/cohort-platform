/// How a circuit session is scored and compared over time.
///
/// See `07 Documentation/39_Circuit_Execution_Engine.md`.
enum CircuitScoreType {
  /// Rounds plus additional reps, e.g. `5+12`.
  roundsAndReps,

  /// Total elapsed time to completion.
  elapsedTime,

  /// Rounds or intervals completed within a fixed clock.
  roundsCompleted,

  /// Total repetitions completed within a fixed duration.
  totalReps,

  /// Movements completed in a chipper before time cap or finish.
  movementsCompleted,

  /// Custom benchmark metric defined by the programmed session.
  benchmarkScore,
}
