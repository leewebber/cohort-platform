import 'user_role.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.isCoach,
    required this.isAthlete,
  });

  final String id;
  final String displayName;
  final bool isCoach;
  final bool isAthlete;

  bool hasRole(UserRole role) {
    return switch (role) {
      UserRole.coach => isCoach,
      UserRole.athlete => isAthlete,
    };
  }

  Set<UserRole> get roles {
    return {
      if (isCoach) UserRole.coach,
      if (isAthlete) UserRole.athlete,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      isCoach: map['is_coach'] as bool? ?? false,
      isAthlete: map['is_athlete'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'id': id,
      'display_name': displayName,
      'is_coach': isCoach,
      'is_athlete': isAthlete,
    };
  }
}
