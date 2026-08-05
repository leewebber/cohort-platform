/// Distinguishes hosted write evidence strength for Journey D creator stages.
///
/// A successful application-service response must not be reported as a durable
/// hosted object unless mutation confirmation (and optionally observation) is
/// separately proven.
class JourneyDWriteAccounting {
  const JourneyDWriteAccounting({
    this.invocationAttempted = false,
    this.requestDispatched = false,
    this.responseReceived = false,
    this.mutationConfirmed = false,
    this.objectObservedPostAttempt = false,
    this.outcomeUncertain = false,
  });

  final bool invocationAttempted;
  final bool requestDispatched;
  final bool responseReceived;
  final bool mutationConfirmed;
  final bool objectObservedPostAttempt;
  final bool outcomeUncertain;

  static const none = JourneyDWriteAccounting();

  /// Local builder/preflight failure before any hosted request.
  static const preNetworkSourceFailure = JourneyDWriteAccounting(
    invocationAttempted: true,
  );

  JourneyDWriteAccounting copyWith({
    bool? invocationAttempted,
    bool? requestDispatched,
    bool? responseReceived,
    bool? mutationConfirmed,
    bool? objectObservedPostAttempt,
    bool? outcomeUncertain,
  }) {
    return JourneyDWriteAccounting(
      invocationAttempted: invocationAttempted ?? this.invocationAttempted,
      requestDispatched: requestDispatched ?? this.requestDispatched,
      responseReceived: responseReceived ?? this.responseReceived,
      mutationConfirmed: mutationConfirmed ?? this.mutationConfirmed,
      objectObservedPostAttempt:
          objectObservedPostAttempt ?? this.objectObservedPostAttempt,
      outcomeUncertain: outcomeUncertain ?? this.outcomeUncertain,
    );
  }

  Map<String, Object?> toJson() => {
    'invocation_attempted': invocationAttempted,
    'request_dispatched': requestDispatched,
    'response_received': responseReceived,
    'mutation_confirmed': mutationConfirmed,
    'object_observed_post_attempt': objectObservedPostAttempt,
    'outcome_uncertain': outcomeUncertain,
  };
}
