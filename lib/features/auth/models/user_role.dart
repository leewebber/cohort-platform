/// Roles a Cohort user can hold. One user may be coach, athlete, or both.
enum UserRole {
  coach,
  athlete,
}

extension UserRoleLabels on UserRole {
  String get label {
    return switch (this) {
      UserRole.coach => 'Coach',
      UserRole.athlete => 'Athlete',
    };
  }

  String get description {
    return switch (this) {
      UserRole.coach =>
        'Create programmes, assign training, and review athlete progress.',
      UserRole.athlete =>
        'View scheduled training, execute sessions, and track progress.',
    };
  }
}
