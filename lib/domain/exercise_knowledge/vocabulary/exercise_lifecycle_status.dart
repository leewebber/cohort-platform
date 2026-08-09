/// Controlled lifecycle for exercise definitions and relationships.
enum ExerciseLifecycleStatus {
  draft,
  published,
  retired,
}

extension ExerciseLifecycleStatusCodec on ExerciseLifecycleStatus {
  String get wireValue {
    return switch (this) {
      ExerciseLifecycleStatus.draft => 'draft',
      ExerciseLifecycleStatus.published => 'published',
      ExerciseLifecycleStatus.retired => 'retired',
    };
  }

  /// Draft knowledge is never runtime-authoritative.
  bool get isRuntimeAuthoritative => this == ExerciseLifecycleStatus.published;

  /// Retired definitions remain resolvable for historical evidence.
  bool get remainsResolvable =>
      this == ExerciseLifecycleStatus.published ||
      this == ExerciseLifecycleStatus.retired;

  static ExerciseLifecycleStatus? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase();
    for (final value in ExerciseLifecycleStatus.values) {
      if (value.wireValue == normalized) return value;
    }
    return null;
  }

  /// Allowed transitions: draft→published→retired; draft may retire without publish.
  bool canTransitionTo(ExerciseLifecycleStatus next) {
    if (this == next) return true;
    return switch (this) {
      ExerciseLifecycleStatus.draft =>
        next == ExerciseLifecycleStatus.published ||
            next == ExerciseLifecycleStatus.retired,
      ExerciseLifecycleStatus.published =>
        next == ExerciseLifecycleStatus.retired,
      ExerciseLifecycleStatus.retired => false,
    };
  }
}
