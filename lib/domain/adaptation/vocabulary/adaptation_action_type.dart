/// Ordered adaptation operations (smallest valid change first).
enum AdaptationActionType {
  increaseRest,
  reduceVolume,
  reduceIntensity,
  shortenDuration,
  adjustPrescription,
  swapExercise,
  removeExercise,
  removeBlock,
  replaceBlock,
  replaceSession,
}

extension AdaptationActionTypeDb on AdaptationActionType {
  String get dbValue {
    return switch (this) {
      AdaptationActionType.increaseRest => 'increase_rest',
      AdaptationActionType.reduceVolume => 'reduce_volume',
      AdaptationActionType.reduceIntensity => 'reduce_intensity',
      AdaptationActionType.shortenDuration => 'shorten_duration',
      AdaptationActionType.adjustPrescription => 'adjust_prescription',
      AdaptationActionType.swapExercise => 'swap_exercise',
      AdaptationActionType.removeExercise => 'remove_exercise',
      AdaptationActionType.removeBlock => 'remove_block',
      AdaptationActionType.replaceBlock => 'replace_block',
      AdaptationActionType.replaceSession => 'replace_session',
    };
  }

  static AdaptationActionType? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final type in AdaptationActionType.values) {
      if (type.dbValue == normalized) return type;
    }
    return null;
  }

  /// Lower index = prefer earlier in the adaptation ladder.
  int get preferenceOrder {
    return switch (this) {
      AdaptationActionType.increaseRest => 0,
      AdaptationActionType.reduceVolume => 1,
      AdaptationActionType.reduceIntensity => 2,
      AdaptationActionType.shortenDuration => 3,
      AdaptationActionType.adjustPrescription => 4,
      AdaptationActionType.swapExercise => 5,
      AdaptationActionType.removeExercise => 6,
      AdaptationActionType.removeBlock => 7,
      AdaptationActionType.replaceBlock => 8,
      AdaptationActionType.replaceSession => 9,
    };
  }
}
