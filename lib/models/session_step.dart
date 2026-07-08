/// Runtime execution model for a single step shown in the session player.
///
/// [ProtocolStep] is the stored programming model (persisted in Supabase).
/// [SessionStep] is derived from that data at play time for display and flow.
class SessionStep {
  const SessionStep({
    required this.stepNumber,
    required this.title,
    required this.prescription,
    required this.coachCue,
  });

  final int stepNumber;
  final String title;
  final String prescription;
  final String coachCue;
}
