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
      currentWeek: _nullableInt(map['current_week']),
      currentDay: _trimString(map['current_day']),
      currentProtocolId: _trimString(map['current_protocol_id']),
      sessionStatus: _trimString(map['session_status']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'athlete_id': athleteId,
      if (currentGoal != null) 'current_goal': currentGoal,
      if (programmeId != null) 'current_programme_id': programmeId,
      if (currentWeek != null) 'current_week': currentWeek,
      if (currentDay != null) 'current_day': currentDay,
      if (currentProtocolId != null) 'current_protocol_id': currentProtocolId,
      if (sessionStatus != null) 'session_status': sessionStatus,
    };
  }

  Map<String, dynamic> toProgrammeProjectionClearMap() {
    return {
      'current_programme_id': null,
      'current_week': null,
      'current_day': null,
      'current_protocol_id': null,
      'session_status': null,
    };
  }

  AthleteState copyWith({
    String? athleteId,
    String? currentGoal,
    String? programmeId,
    int? currentWeek,
    String? currentDay,
    String? currentProtocolId,
    String? sessionStatus,
    bool clearCurrentGoal = false,
    bool clearProgrammeId = false,
    bool clearCurrentWeek = false,
    bool clearCurrentDay = false,
    bool clearCurrentProtocolId = false,
    bool clearSessionStatus = false,
  }) {
    return AthleteState(
      athleteId: athleteId ?? this.athleteId,
      currentGoal: clearCurrentGoal ? null : (currentGoal ?? this.currentGoal),
      programmeId:
          clearProgrammeId ? null : (programmeId ?? this.programmeId),
      currentWeek: clearCurrentWeek ? null : (currentWeek ?? this.currentWeek),
      currentDay: clearCurrentDay ? null : (currentDay ?? this.currentDay),
      currentProtocolId: clearCurrentProtocolId
          ? null
          : (currentProtocolId ?? this.currentProtocolId),
      sessionStatus:
          clearSessionStatus ? null : (sessionStatus ?? this.sessionStatus),
    );
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;

    return int.tryParse(value.toString());
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
