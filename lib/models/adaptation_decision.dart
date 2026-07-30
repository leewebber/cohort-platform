import 'protocol.dart';

enum AdaptationDecisionType { keepOriginal, recommendAlternative }

class AdaptationDecision {
  const AdaptationDecision({
    required this.decisionType,
    required this.message,
    required this.protocol,
    this.changeSummary = const [],
    this.programmedSessionKey,
    this.preservedIntent,
  });

  final AdaptationDecisionType decisionType;
  final String message;
  final Protocol protocol;
  final List<String> changeSummary;
  final String? programmedSessionKey;
  final String? preservedIntent;

  @override
  String toString() {
    return 'AdaptationDecision('
        'decisionType: $decisionType, '
        'message: $message, '
        'protocol: ${protocol.protocolId}'
        ')';
  }
}
