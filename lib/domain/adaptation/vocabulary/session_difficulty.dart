/// Coarse session difficulty for catalogue and adaptation down-ranking.
enum SessionDifficulty {
  beginner,
  intermediate,
  advanced,
  elite,
}

extension SessionDifficultyDb on SessionDifficulty {
  String get dbValue => name;

  static SessionDifficulty? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final level in SessionDifficulty.values) {
      if (level.dbValue == normalized) return level;
    }
    return null;
  }
}
