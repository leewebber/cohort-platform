/// Derived execution decision — does not mutate the programmed session source.
class AcceptedAdaptationDecision {
  const AcceptedAdaptationDecision({
    required this.decisionId,
    required this.programmedSessionKey,
    required this.reasonCode,
    required this.acceptedAt,
    this.changeSummary = const [],
    this.preservedIntent,
    this.requestCategory,
    this.proposalId,
    this.assignmentId,
    this.programmeVersionId,
    this.packageContentHash,
    this.protocolId,
    this.dayKey,
    this.slotOrder,
    this.derivationExplanation,
    this.policyKinds = const [],
    this.evaluationProvenance = const [],
    this.sessionChanges = const [],
    this.exerciseChanges = const [],
    this.proposedAt,
    this.originalPlanFingerprint,
    this.reviewedPlanFingerprint,
    this.snapshotId,
  });

  final String decisionId;
  final String programmedSessionKey;
  final String reasonCode;
  final DateTime acceptedAt;
  final List<String> changeSummary;
  final String? preservedIntent;
  final String? requestCategory;
  final String? proposalId;
  final String? assignmentId;
  final String? programmeVersionId;
  final String? packageContentHash;
  final String? protocolId;
  final String? dayKey;
  final int? slotOrder;
  final String? derivationExplanation;
  final List<String> policyKinds;
  final List<String> evaluationProvenance;
  final List<Map<String, dynamic>> sessionChanges;
  final List<Map<String, dynamic>> exerciseChanges;
  final DateTime? proposedAt;
  final String? originalPlanFingerprint;
  final String? reviewedPlanFingerprint;
  final String? snapshotId;

  Map<String, dynamic> toPersistenceMap() => {
    'decisionId': decisionId,
    'programmedSessionKey': programmedSessionKey,
    'reasonCode': reasonCode,
    'acceptedAt': acceptedAt.toUtc().toIso8601String(),
    'changeSummary': changeSummary,
    'preservedIntent': preservedIntent,
    'requestCategory': requestCategory,
    'proposalId': proposalId,
    'assignmentId': assignmentId,
    'programmeVersionId': programmeVersionId,
    'packageContentHash': packageContentHash,
    'protocolId': protocolId,
    'dayKey': dayKey,
    'slotOrder': slotOrder,
    'derivationExplanation': derivationExplanation,
    'policyKinds': policyKinds,
    'evaluationProvenance': evaluationProvenance,
    'sessionChanges': sessionChanges,
    'exerciseChanges': exerciseChanges,
    'proposedAt': proposedAt?.toUtc().toIso8601String(),
    'originalPlanFingerprint': originalPlanFingerprint,
    'reviewedPlanFingerprint': reviewedPlanFingerprint,
    'snapshotId': snapshotId,
  };

  factory AcceptedAdaptationDecision.fromPersistenceMap(
    Map<String, dynamic> map,
  ) {
    List<Map<String, dynamic>> mapList(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    }

    return AcceptedAdaptationDecision(
      decisionId: map['decisionId']?.toString() ?? '',
      programmedSessionKey: map['programmedSessionKey']?.toString() ?? '',
      reasonCode: map['reasonCode']?.toString() ?? '',
      acceptedAt:
          DateTime.tryParse(map['acceptedAt']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      changeSummary: (map['changeSummary'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      preservedIntent: map['preservedIntent']?.toString(),
      requestCategory: map['requestCategory']?.toString(),
      proposalId: map['proposalId']?.toString(),
      assignmentId: map['assignmentId']?.toString(),
      programmeVersionId: map['programmeVersionId']?.toString(),
      packageContentHash: map['packageContentHash']?.toString(),
      protocolId: map['protocolId']?.toString(),
      dayKey: map['dayKey']?.toString(),
      slotOrder: (map['slotOrder'] as num?)?.toInt(),
      derivationExplanation: map['derivationExplanation']?.toString(),
      policyKinds: (map['policyKinds'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      evaluationProvenance: (map['evaluationProvenance'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      sessionChanges: mapList(map['sessionChanges']),
      exerciseChanges: mapList(map['exerciseChanges']),
      proposedAt: DateTime.tryParse(map['proposedAt']?.toString() ?? '')?.toUtc(),
      originalPlanFingerprint: map['originalPlanFingerprint']?.toString(),
      reviewedPlanFingerprint: map['reviewedPlanFingerprint']?.toString(),
      snapshotId: map['snapshotId']?.toString(),
    );
  }
}

/// In-memory recommendation that must not mutate durable state until accepted.
class PendingAdaptationRecommendation {
  const PendingAdaptationRecommendation({
    required this.recommendationId,
    required this.programmedSessionKey,
    required this.reasonCode,
    required this.proposedChanges,
    this.preservedIntent,
  });

  final String recommendationId;
  final String programmedSessionKey;
  final String reasonCode;
  final List<String> proposedChanges;
  final String? preservedIntent;
}

/// Holds recommendations without applying them.
class AdaptationRecommendationBuffer {
  AdaptationRecommendationBuffer._();

  static PendingAdaptationRecommendation? _pending;

  static PendingAdaptationRecommendation? get pending => _pending;

  static void propose(PendingAdaptationRecommendation recommendation) {
    _pending = recommendation;
  }

  static PendingAdaptationRecommendation? dismiss() {
    final previous = _pending;
    _pending = null;
    return previous;
  }

  static AcceptedAdaptationDecision? accept({DateTime? now}) {
    final pending = _pending;
    if (pending == null) return null;
    _pending = null;
    return AcceptedAdaptationDecision(
      decisionId: 'adapt.${pending.recommendationId}',
      programmedSessionKey: pending.programmedSessionKey,
      reasonCode: pending.reasonCode,
      acceptedAt: now ?? DateTime.now().toUtc(),
      changeSummary: pending.proposedChanges,
      preservedIntent: pending.preservedIntent,
    );
  }

  static void clear() => _pending = null;
}
