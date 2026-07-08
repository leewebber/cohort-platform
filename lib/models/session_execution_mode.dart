enum SessionExecutionMode {
  guidedSteps,
  circuit,
}

SessionExecutionMode executionModeForSession(String title) {
  switch (title) {
    case 'Bodyweight Grinder':
      return SessionExecutionMode.circuit;
    default:
      return SessionExecutionMode.guidedSteps;
  }
}
