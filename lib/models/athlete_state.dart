class AthleteState {
  const AthleteState({
    required this.athleteId,
    this.currentGoal,
    this.programmeId,
    this.currentWeek,
    this.currentDay,
    this.currentProtocolId,
    this.sessionStatus,
  });

  final String athleteId;
  final String? currentGoal;
  final String? programmeId;
  final int? currentWeek;
  final String? currentDay;
  final String? currentProtocolId;
  final String? sessionStatus;

  factory AthleteState.fromMap(Map<String, dynamic> map) {
    return AthleteState(
      athleteId: _trimStringRequired(map['athlete_id']),
      currentGoal: _trimString(map['current_goal']),
      programmeId: _trimString(map['current_programme_id']),
      currentWeek: map['current_week'],
      currentDay: _trimString(map['current_day']),
      currentProtocolId: _trimString(map['current_protocol_id']),
      sessionStatus: _trimString(map['session_status']),
    );
  }

  static String? _trimString(dynamic value) {
    if (value == null) return null;

    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _trimStringRequired(dynamic value) {
    return value?.toString().trim() ?? '';
  }
}
