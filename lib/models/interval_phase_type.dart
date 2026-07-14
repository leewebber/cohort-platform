/// Phase classification within an interval session timeline.
///
/// Device-neutral and modality-agnostic. See
/// `07 Documentation/37_Interval_Execution_Engine.md`.
enum IntervalPhaseType {
  warmUp,
  work,
  recovery,
  coolDown,
  instruction,
}
