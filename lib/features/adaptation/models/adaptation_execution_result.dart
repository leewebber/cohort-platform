import 'programme_adaptation_event.dart';

/// Outcome of post-completion adaptation orchestration.
class AdaptationExecutionResult {
  const AdaptationExecutionResult({
    required this.applied,
    required this.athleteMessage,
    this.coachMessage,
    this.event,
    this.skippedReason,
  });

  final bool applied;
  final String athleteMessage;
  final String? coachMessage;
  final ProgrammeAdaptationEvent? event;
  final String? skippedReason;

  factory AdaptationExecutionResult.skipped(String reason) {
    return AdaptationExecutionResult(
      applied: false,
      athleteMessage: 'Programme continues as planned.',
      skippedReason: reason,
    );
  }

  factory AdaptationExecutionResult.fromEvent(ProgrammeAdaptationEvent event) {
    return AdaptationExecutionResult(
      applied: true,
      athleteMessage: event.athleteSummary,
      coachMessage: event.explanation,
      event: event,
    );
  }
}
