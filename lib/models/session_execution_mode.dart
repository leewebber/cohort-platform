enum SessionExecutionMode {
  guidedSteps,
  circuit,
}

// TODO(technical-debt): Derive execution mode from protocol metadata in Supabase
// (e.g. display_style or step_type) instead of hardcoded identifiers.
SessionExecutionMode executionModeForSession(String identifier) {
  switch (identifier) {
    case 'Bodyweight Grinder':
    case 'BW-001':
      return SessionExecutionMode.circuit;
    default:
      return SessionExecutionMode.guidedSteps;
  }
}
