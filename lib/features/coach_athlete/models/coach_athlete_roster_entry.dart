class CoachAthleteRosterEntry {
  const CoachAthleteRosterEntry({
    required this.athleteId,
    required this.displayName,
    required this.relationshipId,
    this.activeProgrammeName,
    this.activeProgrammeVersionLabel,
    this.hasActiveAssignment = false,
  });

  final String athleteId;
  final String displayName;
  final String relationshipId;
  final String? activeProgrammeName;
  final String? activeProgrammeVersionLabel;
  final bool hasActiveAssignment;
}

class CoachAthleteAcceptInviteResult {
  const CoachAthleteAcceptInviteResult({
    required this.coachDisplayName,
    required this.coachId,
  });

  final String coachDisplayName;
  final String coachId;
}
