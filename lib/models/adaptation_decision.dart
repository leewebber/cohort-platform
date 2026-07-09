import 'protocol.dart';

enum AdaptationDecisionType {
  keepOriginal,
  recommendAlternative,
}

class AdaptationDecision {
  const AdaptationDecision({
    required this.decisionType,
    required this.message,
    required this.protocol,
  });

  final AdaptationDecisionType decisionType;
  final String message;
  final Protocol protocol;

  @override
  String toString() {
    return 'AdaptationDecision('
        'decisionType: $decisionType, '
        'message: $message, '
        'protocol: ${protocol.protocolId}'
        ')';
  }
}
