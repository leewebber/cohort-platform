/// Athlete-facing overview metadata derived from planning / execution plan.
///
/// No analytics. Values come from [PlanningContext] + [SessionExecutionPlan].
class WorkoutSessionBrief {
  const WorkoutSessionBrief({
    required this.sessionName,
    this.objective,
    this.estimatedDurationMinutes,
    this.primaryFocus,
    this.trainingIntent,
    this.sessionDifficulty,
    this.sessionNotes,
    this.coachNotes,
  });

  final String sessionName;
  final String? objective;
  final int? estimatedDurationMinutes;
  final String? primaryFocus;
  final String? trainingIntent;
  final String? sessionDifficulty;
  final String? sessionNotes;
  final String? coachNotes;

  String get durationLabel {
    final minutes = estimatedDurationMinutes;
    if (minutes == null || minutes <= 0) return 'Duration TBD';
    return '~$minutes min';
  }
}
