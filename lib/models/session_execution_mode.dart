/// How a programmed session should be executed in the athlete player.
///
/// Routing is determined by [SessionExecutionRouter] from protocol metadata.
/// Each mode will eventually mount a dedicated session view.
enum SessionExecutionMode {
  circuit,
  structuredStrength,
  intervals,
  recoveryFlow,
}
