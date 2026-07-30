/// Relationship between an athlete and a [PlanDefinition].
///
/// Contains **progress only** — never workouts or coaching product copy.
/// MVP: one active assignment. Model allows future multi-assignment.
class PlanAssignment {
  const PlanAssignment({
    required this.assignmentId,
    required this.athleteId,
    required this.planId,
    required this.assignedAt,
    this.startedAt,
    this.completedAt,
    this.currentPhase = 'Foundation',
    this.currentWeek = 1,
    this.currentDay = 1,
    this.status = PlanAssignmentStatus.active,
    this.configuration = const {},
  });

  final String assignmentId;
  final String athleteId;
  final String planId;
  final PlanAssignmentStatus status;
  final DateTime assignedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String currentPhase;
  final int currentWeek;
  final int currentDay;

  /// Reserved for future athlete-specific plan configuration.
  final Map<String, String> configuration;

  bool get isActive => status == PlanAssignmentStatus.active;

  String get weekDayLabel => 'Week $currentWeek · Day $currentDay';

  PlanAssignment copyWith({
    DateTime? startedAt,
    DateTime? completedAt,
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
      completedAt: completedAt ?? this.completedAt,
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
    'status': status.name,
    'assignedAt': assignedAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'currentPhase': currentPhase,
    'currentWeek': currentWeek,
    'currentDay': currentDay,
    'configuration': configuration,
  };

  factory PlanAssignment.fromPersistenceMap(Map<String, dynamic> map) {
    final statusName = map['status']?.toString() ?? 'active';
    final status = PlanAssignmentStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => PlanAssignmentStatus.active,
    );
    DateTime? parseOptional(String key) {
      final raw = map[key]?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toUtc();
    }

    final assignedRaw = map['assignedAt']?.toString();
    final assignedAt = assignedRaw == null
        ? null
        : DateTime.tryParse(assignedRaw)?.toUtc();
    if (assignedAt == null) {
      throw const FormatException('Invalid assignedAt');
    }

    final configRaw = map['configuration'];
    final configuration = <String, String>{};
    if (configRaw is Map) {
      configRaw.forEach((k, v) {
        configuration[k.toString()] = v.toString();
      });
    }

    return PlanAssignment(
      assignmentId: map['assignmentId']?.toString() ?? '',
      athleteId: map['athleteId']?.toString() ?? '',
      planId: map['planId']?.toString() ?? '',
      assignedAt: assignedAt,
      startedAt: parseOptional('startedAt'),
      completedAt: parseOptional('completedAt'),
      currentPhase: map['currentPhase']?.toString() ?? 'Foundation',
      currentWeek: (map['currentWeek'] as num?)?.toInt() ?? 1,
      currentDay: (map['currentDay'] as num?)?.toInt() ?? 1,
      status: status,
      configuration: configuration,
    );
  }
}

enum PlanAssignmentStatus { active, paused, completed, cancelled }
