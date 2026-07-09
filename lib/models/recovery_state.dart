enum RecoveryState {
  slightlyTired,
  poorSleep,
  veryFatigued,
  feelingIll,
}

extension RecoveryStateLabel on RecoveryState {
  String get label {
    switch (this) {
      case RecoveryState.slightlyTired:
        return 'Slightly Tired';
      case RecoveryState.poorSleep:
        return 'Poor Sleep';
      case RecoveryState.veryFatigued:
        return 'Very Fatigued';
      case RecoveryState.feelingIll:
        return 'Feeling Ill';
    }
  }
}
