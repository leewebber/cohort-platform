/// Observational interval progress outcome for a completed session.
class IntervalProgressResult {
  const IntervalProgressResult({
    required this.progressType,
    required this.title,
    required this.message,
    required this.reasons,
  });

  final IntervalProgressType progressType;
  final String title;
  final String message;
  final List<String> reasons;

  String get headline {
    return switch (progressType) {
      IntervalProgressType.firstPerformance =>
        'First recorded interval performance.',
      IntervalProgressType.averagePaceImproved => 'Average pace improved.',
      IntervalProgressType.consistencyImproved => 'Pacing consistency improved.',
      IntervalProgressType.effortImproved => 'Same work at lower effort.',
      IntervalProgressType.moreWorkCompleted => 'More work completed.',
      IntervalProgressType.matchedPerformance =>
        'Performance matched — strong consistency.',
      IntervalProgressType.mixedResult =>
        'Mixed result across today\'s intervals.',
      IntervalProgressType.insufficientData => 'Session logged successfully.',
    };
  }
}

enum IntervalProgressType {
  firstPerformance,
  averagePaceImproved,
  consistencyImproved,
  effortImproved,
  moreWorkCompleted,
  matchedPerformance,
  mixedResult,
  insufficientData,
}
