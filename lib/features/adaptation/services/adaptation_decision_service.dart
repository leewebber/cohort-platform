import '../../../models/adaptation_decision.dart';
import '../../../models/adaptation_reason.dart';
import '../../../models/adaptation_request.dart';
import '../../../models/adaptation_session_environment.dart';
import '../../../models/protocol.dart';
import '../../../models/protocol_metadata_vocabulary.dart';
import '../../../models/recovery_state.dart';

class AdaptationDecisionService {
  const AdaptationDecisionService();

  AdaptationDecision evaluate({
    required Protocol currentProtocol,
    required AdaptationRequest request,
  }) {
    final keepsOriginal = _keepsOriginal(currentProtocol, request);

    return AdaptationDecision(
      decisionType: keepsOriginal
          ? AdaptationDecisionType.keepOriginal
          : AdaptationDecisionType.recommendAlternative,
      message: _messageFor(
        keepsOriginal: keepsOriginal,
        reason: request.reason,
      ),
      protocol: currentProtocol,
    );
  }

  String _messageFor({
    required bool keepsOriginal,
    required AdaptationReason reason,
  }) {
    if (keepsOriginal) {
      switch (reason) {
        case AdaptationReason.environment:
          return 'Good news — today\'s planned session already works in this environment. No changes needed.';
        case AdaptationReason.equipment:
          return 'Good news — today\'s planned session already fits the equipment you have. Stay with the plan.';
        case AdaptationReason.time:
          return 'Today\'s planned session already fits your available time. Stay with the plan.';
        case AdaptationReason.recovery:
          return 'Today\'s planned session is already recovery-friendly. Stay with the plan.';
      }
    }

    switch (reason) {
      case AdaptationReason.equipment:
        return 'Today\'s session needs equipment you don\'t currently have. We\'ll adapt the plan while preserving the training objective.';
      case AdaptationReason.recovery:
        return 'Based on today\'s recovery, I\'d recommend reducing the training load while preserving the purpose of the session.';
      case AdaptationReason.environment:
        return 'Today\'s planned session may not fit this environment. We\'ll adapt the plan while preserving the training objective.';
      case AdaptationReason.time:
        return 'Today\'s planned session is longer than your available time. We\'ll adapt the plan while preserving the training objective.';
    }
  }

  bool _keepsOriginal(Protocol protocol, AdaptationRequest request) {
    switch (request.reason) {
      case AdaptationReason.environment:
        return _environmentSatisfied(protocol, request.environment);
      case AdaptationReason.equipment:
        return _equipmentSatisfied(protocol, request.availableEquipment);
      case AdaptationReason.time:
        return _timeSatisfied(protocol, request.availableMinutes);
      case AdaptationReason.recovery:
        return _recoverySatisfied(protocol, request.recoveryState);
    }
  }

  bool _environmentSatisfied(
    Protocol protocol,
    AdaptationSessionEnvironment? environment,
  ) {
    if (environment == null) return false;

    switch (environment) {
      case AdaptationSessionEnvironment.home:
        return protocol.indoorFriendly == true ||
            _protocolEnvironmentMatches(protocol, ['home', 'anywhere']);
      case AdaptationSessionEnvironment.hotelRoom:
        return protocol.hotelFriendly == true ||
            protocol.indoorFriendly == true ||
            _protocolEnvironmentMatches(protocol, ['home', 'anywhere']);
      case AdaptationSessionEnvironment.hotelGym:
        return protocol.hotelFriendly == true ||
            _protocolEnvironmentMatches(
              protocol,
              ['hotel gym', 'gym', 'full gym', 'anywhere'],
            );
      case AdaptationSessionEnvironment.commercialGym:
        return _protocolEnvironmentMatches(
          protocol,
          ['gym', 'full gym', 'anywhere'],
        );
      case AdaptationSessionEnvironment.outdoors:
        return _protocolEnvironmentMatches(
          protocol,
          ['outdoor', 'track', 'trail', 'anywhere'],
        );
    }
  }

  bool _protocolEnvironmentMatches(Protocol protocol, List<String> tokens) {
    final environment = protocol.environment?.trim().toLowerCase();
    if (environment == null || environment.isEmpty) {
      return false;
    }

    for (final token in tokens) {
      if (environment.contains(token)) {
        return true;
      }
    }

    return false;
  }

  bool _equipmentSatisfied(
    Protocol protocol,
    Set<String>? availableEquipment,
  ) {
    final requiredEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
      protocol.requiredEquipment,
    );

    if (requiredEquipment.isEmpty) {
      return true;
    }

    if (availableEquipment == null || availableEquipment.isEmpty) {
      return false;
    }

    final available = availableEquipment
        .map(_normalizeEquipmentToken)
        .toSet();

    for (final required in requiredEquipment) {
      if (!available.contains(_normalizeEquipmentToken(required))) {
        return false;
      }
    }

    return true;
  }

  String _normalizeEquipmentToken(String token) {
    final normalized = token.trim().toLowerCase();
    if (normalized == 'none') {
      return 'bodyweight';
    }

    return normalized;
  }

  bool _timeSatisfied(Protocol protocol, int? availableMinutes) {
    if (availableMinutes == null) return false;

    final durationMin = protocol.durationMin;
    if (durationMin == null) return false;

    return durationMin <= availableMinutes;
  }

  bool _recoverySatisfied(Protocol protocol, RecoveryState? recoveryState) {
    if (recoveryState == null) return false;

    return _isLowOrVeryLow(protocol.recovery);
  }

  bool _isLowOrVeryLow(String? recoveryCost) {
    if (recoveryCost == null || recoveryCost.trim().isEmpty) {
      return false;
    }

    final lower = recoveryCost.trim().toLowerCase();
    return lower == 'low' || lower == 'very low';
  }
}
