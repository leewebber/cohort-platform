import '../../../models/protocol.dart';
import '../../../models/session_execution_mode.dart';

/// Selects the execution experience for a programmed session.
///
/// See `07 Documentation/33_Execution_Engine.md`.
class SessionExecutionRouter {
  const SessionExecutionRouter();

  SessionExecutionMode determineExecutionMode(Protocol protocol) {
    final sessionType = protocol.sessionType?.trim().toLowerCase() ?? '';

    switch (sessionType) {
      case 'circuit':
        return SessionExecutionMode.circuit;
      case 'strength':
        return SessionExecutionMode.structuredStrength;
      case 'running':
        return SessionExecutionMode.intervals;
      case 'recovery':
        return SessionExecutionMode.recoveryFlow;
      default:
        return SessionExecutionMode.circuit;
    }
  }
}
