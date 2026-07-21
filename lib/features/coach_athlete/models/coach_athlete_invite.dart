enum CoachAthleteInviteStatus {
  pending,
  accepted,
  revoked,
}

extension CoachAthleteInviteStatusDb on CoachAthleteInviteStatus {
  String get dbValue {
    return switch (this) {
      CoachAthleteInviteStatus.pending => 'pending',
      CoachAthleteInviteStatus.accepted => 'accepted',
      CoachAthleteInviteStatus.revoked => 'revoked',
    };
  }

  static CoachAthleteInviteStatus fromDb(String value) {
    return switch (value) {
      'pending' => CoachAthleteInviteStatus.pending,
      'accepted' => CoachAthleteInviteStatus.accepted,
      'revoked' => CoachAthleteInviteStatus.revoked,
      _ => CoachAthleteInviteStatus.pending,
    };
  }
}

class CoachAthleteInvite {
  const CoachAthleteInvite({
    required this.id,
    required this.coachId,
    required this.code,
    required this.status,
    required this.expiresAt,
    required this.createdAt,
    this.acceptedAt,
    this.acceptedByAthleteId,
  });

  final String id;
  final String coachId;
  final String code;
  final CoachAthleteInviteStatus status;
  final DateTime expiresAt;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final String? acceptedByAthleteId;

  bool get isPending => status == CoachAthleteInviteStatus.pending;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  bool get isUsable => isPending && !isExpired;

  factory CoachAthleteInvite.fromMap(Map<String, dynamic> map) {
    return CoachAthleteInvite(
      id: map['id'] as String,
      coachId: map['coach_id'] as String,
      code: map['code'] as String,
      status: CoachAthleteInviteStatusDb.fromDb(map['status'] as String),
      expiresAt: DateTime.parse(map['expires_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      acceptedAt: map['accepted_at'] == null
          ? null
          : DateTime.parse(map['accepted_at'] as String),
      acceptedByAthleteId: map['accepted_by_athlete_id'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap({
    required String coachId,
    required String code,
    required DateTime expiresAt,
  }) {
    return {
      'coach_id': coachId,
      'code': code,
      'status': CoachAthleteInviteStatus.pending.dbValue,
      'expires_at': expiresAt.toUtc().toIso8601String(),
    };
  }
}
