enum ProgressionOutcome {
  firstPerformance,
  improved,
  matched,
  belowLastPerformance,
  mixed,
  notComparable,
  insufficientEvidence;

  String get label => switch (this) {
    ProgressionOutcome.firstPerformance => 'First performance',
    ProgressionOutcome.improved => 'Improved',
    ProgressionOutcome.matched => 'Matched',
    ProgressionOutcome.belowLastPerformance => 'Below last performance',
    ProgressionOutcome.mixed => 'Mixed',
    ProgressionOutcome.notComparable => 'Not comparable',
    ProgressionOutcome.insufficientEvidence => 'Insufficient evidence',
  };
}

enum EvidenceConfidence { high, moderate, low, none }

class MetricDelta {
  const MetricDelta({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;
}

class ProgressionComparison {
  const ProgressionComparison({
    required this.outcome,
    required this.confidence,
    required this.summary,
    this.deltas = const [],
    this.previousPerformedAt,
    this.comparisonKey = '',
    this.prescriptionChanged = false,
  });

  final ProgressionOutcome outcome;
  final EvidenceConfidence confidence;
  final String summary;
  final List<MetricDelta> deltas;
  final DateTime? previousPerformedAt;
  final String comparisonKey;
  final bool prescriptionChanged;

  static const first = ProgressionComparison(
    outcome: ProgressionOutcome.firstPerformance,
    confidence: EvidenceConfidence.none,
    summary: 'First comparable performance',
  );

  static const notComparable = ProgressionComparison(
    outcome: ProgressionOutcome.notComparable,
    confidence: EvidenceConfidence.none,
    summary: 'Not comparable',
  );

  static const insufficient = ProgressionComparison(
    outcome: ProgressionOutcome.insufficientEvidence,
    confidence: EvidenceConfidence.low,
    summary: 'Insufficient evidence',
  );
}
