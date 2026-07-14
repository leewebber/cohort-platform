/// Observational circuit progress outcome for a completed session.
class CircuitProgressResult {
  const CircuitProgressResult({
    required this.progressType,
    required this.title,
    required this.message,
    required this.reasons,
  });

  final CircuitProgressType progressType;
  final String title;
  final String message;
  final List<String> reasons;

  String get headline {
    return switch (progressType) {
      CircuitProgressType.firstPerformance =>
        'First recorded circuit performance.',
      CircuitProgressType.moreRoundsOrReps => 'More rounds or reps completed.',
      CircuitProgressType.fasterCompletion => 'Faster completion.',
      CircuitProgressType.moreWorkCompleted => 'More work completed.',
      CircuitProgressType.heavierLoad => 'Heavier load at equal or better score.',
      CircuitProgressType.effortImproved => 'Same work at lower effort.',
      CircuitProgressType.matchedPerformance =>
        'Performance matched — strong consistency.',
      CircuitProgressType.mixedResult =>
        'Mixed result compared with your last session.',
      CircuitProgressType.insufficientData => 'Session logged successfully.',
    };
  }
}

enum CircuitProgressType {
  firstPerformance,
  moreRoundsOrReps,
  fasterCompletion,
  moreWorkCompleted,
  heavierLoad,
  effortImproved,
  matchedPerformance,
  mixedResult,
  insufficientData,
}
