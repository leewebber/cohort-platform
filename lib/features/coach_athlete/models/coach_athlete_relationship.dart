enum CoachAthleteRelationshipStatus {
  active,
  ended,
}

extension CoachAthleteRelationshipStatusDb on CoachAthleteRelationshipStatus {
  String get dbValue {
    return switch (this) {
      CoachAthleteRelationshipStatus.active => 'active',
      CoachAthleteRelationshipStatus.ended => 'ended',
    };
  }

  static CoachAthleteRelationshipStatus fromDb(String value) {
    return switch (value) {
      'active' => CoachAthleteRelationshipStatus.active,
      'ended' => CoachAthleteRelationshipStatus.ended,
      _ => CoachAthleteRelationshipStatus.active,
    };
  }
}

class CoachAthleteRelationship {
  const CoachAthleteRelationship({
    required this.id,
    required this.coachId,
    required this.athleteId,
    required this.status,
    required this.createdAt,
    this.endedAt,
  });

  final String id;
  final String coachId;
  final String athleteId;
  final CoachAthleteRelationshipStatus status;
  final DateTime createdAt;
  final DateTime? endedAt;

  bool get isActive => status == CoachAthleteRelationshipStatus.active;

  factory CoachAthleteRelationship.fromMap(Map<String, dynamic> map) {
    return CoachAthleteRelationship(
      id: map['id'] as String,
      coachId: map['coach_id'] as String,
      athleteId: map['athlete_id'] as String,
      status: CoachAthleteRelationshipStatusDb.fromDb(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.parse(map['ended_at'] as String),
    );
  }
}
