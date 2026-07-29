/// How capability evidence was obtained (not athlete storage).
enum CapabilityEvidenceState {
  assessed,
  estimated,
  inferred,
  coachObservation,
  unknown,
}

/// Confidence in a single evidence item (0–1).
typedef EvidenceConfidence = double;

/// One in-memory evidence item for gap analysis (ephemeral input).
class CapabilityEvidenceItem {
  const CapabilityEvidenceItem({
    required this.capabilityId,
    required this.state,
    this.confidence = 0.5,
    this.source,
    this.recordedAt,
    this.notes,
    this.decayPolicyId,
  });

  final String capabilityId;
  final CapabilityEvidenceState state;
  final EvidenceConfidence confidence;
  final String? source;
  final DateTime? recordedAt;
  final String? notes;

  /// Optional decay policy id (documentation only in v1; not applied at runtime).
  final String? decayPolicyId;
}

/// Snapshot of athlete capability evidence for a single analysis run.
class AthleteCapabilityEvidenceProfile {
  const AthleteCapabilityEvidenceProfile({required this.items});

  factory AthleteCapabilityEvidenceProfile.fromItems(
    List<CapabilityEvidenceItem> items,
  ) {
    return AthleteCapabilityEvidenceProfile(items: items);
  }

  final List<CapabilityEvidenceItem> items;

  CapabilityEvidenceItem? evidenceFor(String capabilityId) {
    for (final item in items) {
      if (item.capabilityId == capabilityId) return item;
    }
    return null;
  }

  Map<String, CapabilityEvidenceItem> get byCapabilityId => {
    for (final item in items) item.capabilityId: item,
  };
}

/// Severity band for prioritisation.
enum CapabilityGapSeverity { low, moderate, high, critical }

/// Deterministic gap output for one capability relative to a goal.
class CapabilityGap {
  const CapabilityGap({
    required this.capabilityId,
    required this.capabilityLabel,
    required this.goalImportance,
    required this.evidenceState,
    required this.severity,
    required this.priorityScore,
    required this.confidence,
    required this.rationale,
    this.supportingEvidence = const [],
    this.blockerCapabilityIds = const [],
    this.prerequisiteCapabilityIds = const [],
  });

  final String capabilityId;
  final String capabilityLabel;
  final double goalImportance;
  final CapabilityEvidenceState evidenceState;
  final CapabilityGapSeverity severity;
  final double priorityScore;
  final double confidence;
  final String rationale;
  final List<CapabilityEvidenceItem> supportingEvidence;
  final List<String> blockerCapabilityIds;
  final List<String> prerequisiteCapabilityIds;
}

/// Full analysis result for a goal + evidence profile.
class CapabilityGapAnalysisResult {
  const CapabilityGapAnalysisResult({
    required this.goalId,
    required this.goalLabel,
    required this.gaps,
    required this.rankedPriorities,
    required this.analysedAt,
  });

  final String goalId;
  final String goalLabel;
  final List<CapabilityGap> gaps;
  final List<CapabilityGap> rankedPriorities;
  final DateTime analysedAt;
}

extension CapabilityEvidenceStateQuality on CapabilityEvidenceState {
  /// Transparent quality weight for scoring (see Capability_Gap_Analysis_v1.md).
  double get qualityWeight => switch (this) {
    CapabilityEvidenceState.assessed => 1.0,
    CapabilityEvidenceState.coachObservation => 0.85,
    CapabilityEvidenceState.estimated => 0.65,
    CapabilityEvidenceState.inferred => 0.45,
    CapabilityEvidenceState.unknown => 0.0,
  };

  bool get isKnown => this != CapabilityEvidenceState.unknown;
}
