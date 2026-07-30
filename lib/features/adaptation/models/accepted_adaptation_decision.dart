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
  });

  final String decisionId;
  final String programmedSessionKey;
  final String reasonCode;
  final DateTime acceptedAt;
  final List<String> changeSummary;
  final String? preservedIntent;
  final String? requestCategory;

  Map<String, dynamic> toPersistenceMap() => {
    'decisionId': decisionId,
    'programmedSessionKey': programmedSessionKey,
    'reasonCode': reasonCode,
    'acceptedAt': acceptedAt.toUtc().toIso8601String(),
    'changeSummary': changeSummary,
    'preservedIntent': preservedIntent,
    'requestCategory': requestCategory,
  };

  factory AcceptedAdaptationDecision.fromPersistenceMap(
    Map<String, dynamic> map,
  ) {
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
