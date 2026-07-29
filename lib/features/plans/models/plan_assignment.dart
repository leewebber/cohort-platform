/// Relationship between an athlete and a [Plan].
///
/// MVP: one active assignment. Model allows future multi-assignment.
class PlanAssignment {
  const PlanAssignment({
    required this.assignmentId,
    required this.athleteId,
    required this.planId,
    required this.assignedAt,
    this.startedAt,
    this.currentPhase = 'Foundation',
    this.currentWeek = 1,
    this.currentDay = 1,
    this.status = PlanAssignmentStatus.active,
    this.configuration = const {},
  });

  final String assignmentId;
  final String athleteId;
  final String planId;
  final DateTime assignedAt;
  final DateTime? startedAt;
  final String currentPhase;
  final int currentWeek;
  final int currentDay;
  final PlanAssignmentStatus status;

  /// Reserved for future athlete-specific plan configuration.
  final Map<String, String> configuration;

  bool get isActive => status == PlanAssignmentStatus.active;

  String get weekDayLabel => 'Week $currentWeek · Day $currentDay';

  PlanAssignment copyWith({
    DateTime? startedAt,
    String? currentPhase,
    int? currentWeek,
    int? currentDay,
    PlanAssignmentStatus? status,
    Map<String, String>? configuration,
  }) {
    return PlanAssignment(
      assignmentId: assignmentId,
      athleteId: athleteId,
      planId: planId,
      assignedAt: assignedAt,
      startedAt: startedAt ?? this.startedAt,
      currentPhase: currentPhase ?? this.currentPhase,
      currentWeek: currentWeek ?? this.currentWeek,
      currentDay: currentDay ?? this.currentDay,
      status: status ?? this.status,
      configuration: configuration ?? this.configuration,
    );
  }

  Map<String, dynamic> toPersistenceMap() => {
    'assignmentId': assignmentId,
    'athleteId': athleteId,
    'planId': planId,
    'assignedAt': assignedAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'currentPhase': currentPhase,
    'currentWeek': currentWeek,
    'currentDay': currentDay,
    'status': status.name,
    'configuration': configuration,
  };
}

enum PlanAssignmentStatus { active, paused, completed, cancelled }
