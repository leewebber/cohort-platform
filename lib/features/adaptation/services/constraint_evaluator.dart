import '../../../models/adaptation_session_environment.dart';
import '../../../models/protocol.dart';
import '../../../models/protocol_metadata_vocabulary.dart';
import '../../../models/recovery_state.dart';

/// Result of evaluating whether a protocol satisfies a coaching constraint.
class ConstraintEvaluation {
  const ConstraintEvaluation({
    required this.satisfied,
    this.reason,
  });

  final bool satisfied;
  final String? reason;

  static const satisfiedResult = ConstraintEvaluation(satisfied: true);

  @override
  String toString() {
    return 'ConstraintEvaluation(satisfied: $satisfied, reason: $reason)';
  }
}

/// Single source of truth for adaptation constraint evaluation.
class ConstraintEvaluator {
  const ConstraintEvaluator();

  ConstraintEvaluation environmentSatisfied(
    Protocol protocol,
    AdaptationSessionEnvironment? environment,
  ) {
    if (environment == null) {
      return const ConstraintEvaluation(
        satisfied: false,
        reason: 'No environment provided',
      );
    }

    if (!_environmentMetadataSatisfied(protocol, environment)) {
      return ConstraintEvaluation(
        satisfied: false,
        reason: 'Not compatible with ${environment.label} environment',
      );
    }

    if (environment == AdaptationSessionEnvironment.hotelRoom) {
      return _evaluateHotelRoomEquipment(protocol);
    }

    return ConstraintEvaluation.satisfiedResult;
  }

  ConstraintEvaluation equipmentSatisfied(
    Protocol protocol,
    Set<String>? availableEquipment,
  ) {
    final requiredEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
      protocol.requiredEquipment,
    );

    if (requiredEquipment.isEmpty) {
      return ConstraintEvaluation.satisfiedResult;
    }

    if (availableEquipment == null || availableEquipment.isEmpty) {
      return const ConstraintEvaluation(
        satisfied: false,
        reason: 'No available equipment provided',
      );
    }

    final available = availableEquipment
        .map(_normalizeEquipmentToken)
        .toSet();

    for (final required in requiredEquipment) {
      final normalizedRequired = _normalizeEquipmentToken(required);
      if (!available.contains(normalizedRequired)) {
        return ConstraintEvaluation(
          satisfied: false,
          reason: 'Missing required equipment: $required',
        );
      }
    }

    return ConstraintEvaluation.satisfiedResult;
  }

  ConstraintEvaluation timeSatisfied(
    Protocol protocol,
    int? availableMinutes,
  ) {
    if (availableMinutes == null) {
      return const ConstraintEvaluation(
        satisfied: false,
        reason: 'No available time provided',
      );
    }

    final durationMin = protocol.durationMin;
    if (durationMin == null) {
      return const ConstraintEvaluation(
        satisfied: false,
        reason: 'Candidate duration is unknown',
      );
    }

    if (durationMin > availableMinutes) {
      return ConstraintEvaluation(
        satisfied: false,
        reason:
            'Duration ${durationMin}min exceeds available ${availableMinutes}min',
      );
    }

    return ConstraintEvaluation.satisfiedResult;
  }

  ConstraintEvaluation recoverySatisfied(
    Protocol protocol,
    RecoveryState? recoveryState,
  ) {
    if (recoveryState == null) {
      return const ConstraintEvaluation(
        satisfied: false,
        reason: 'No recovery state provided',
      );
    }

    final maxAllowedLevel = _maxAllowedLevel(recoveryState);
    final demandRank = _levelRank(protocol.demand);
    final recoveryRank = _levelRank(protocol.recovery);

    if (demandRank > maxAllowedLevel) {
      return ConstraintEvaluation(
        satisfied: false,
        reason: 'Physiological demand too high for ${recoveryState.label}',
      );
    }

    if (recoveryRank > maxAllowedLevel) {
      return ConstraintEvaluation(
        satisfied: false,
        reason: 'Recovery cost too high for ${recoveryState.label}',
      );
    }

    return ConstraintEvaluation.satisfiedResult;
  }

  bool _environmentMetadataSatisfied(
    Protocol protocol,
    AdaptationSessionEnvironment environment,
  ) {
    switch (environment) {
      case AdaptationSessionEnvironment.home:
        return protocol.indoorFriendly == true ||
            _protocolEnvironmentIsOneOf(protocol, ['home', 'anywhere']);
      case AdaptationSessionEnvironment.hotelRoom:
        return protocol.hotelFriendly == true;
      case AdaptationSessionEnvironment.hotelGym:
        return protocol.hotelFriendly == true ||
            _protocolEnvironmentIsOneOf(protocol, ['hotel gym']);
      case AdaptationSessionEnvironment.commercialGym:
        return _protocolEnvironmentIsOneOf(
          protocol,
          ['gym', 'full gym', 'anywhere'],
        );
      case AdaptationSessionEnvironment.outdoors:
        return _protocolEnvironmentIsOneOf(
          protocol,
          ['outdoor', 'track', 'trail', 'anywhere'],
        );
    }
  }

  ConstraintEvaluation _evaluateHotelRoomEquipment(Protocol protocol) {
    final requiredEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
      protocol.requiredEquipment,
    );

    if (requiredEquipment.isEmpty) {
      return ConstraintEvaluation.satisfiedResult;
    }

    for (final required in requiredEquipment) {
      final normalized = _normalizeEquipmentToken(required);
      if (_isBodyweightCompatibleEquipment(normalized)) {
        continue;
      }

      final incompatible = _findHotelRoomIncompatibleEquipment(normalized);
      if (incompatible != null) {
        return ConstraintEvaluation(
          satisfied: false,
          reason:
              'Requires equipment not suitable for Hotel Room: $required',
        );
      }
    }

    return ConstraintEvaluation.satisfiedResult;
  }

  static const _hotelRoomIncompatibleEquipment = [
    'full gym',
    'barbell',
    'bike erg',
    'row erg',
    'rower',
    'ski erg',
    'sandbag',
    'wall ball',
    'box',
  ];

  String? _findHotelRoomIncompatibleEquipment(String normalizedEquipment) {
    for (final incompatible in _hotelRoomIncompatibleEquipment) {
      if (normalizedEquipment == incompatible ||
          normalizedEquipment.contains(incompatible)) {
        return incompatible;
      }
    }

    return null;
  }

  bool _isBodyweightCompatibleEquipment(String normalizedEquipment) {
    return normalizedEquipment.isEmpty ||
        normalizedEquipment == 'bodyweight' ||
        normalizedEquipment == 'none';
  }

  bool _protocolEnvironmentIsOneOf(Protocol protocol, List<String> allowed) {
    final environment = _normalizeToken(protocol.environment);
    if (environment.isEmpty) {
      return false;
    }

    for (final allowedEnvironment in allowed) {
      if (environment == _normalizeToken(allowedEnvironment)) {
        return true;
      }
    }

    return false;
  }

  String _normalizeToken(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  String _normalizeEquipmentToken(String token) {
    final normalized = token.trim().toLowerCase();
    if (normalized == 'none') {
      return 'bodyweight';
    }

    return normalized;
  }

  int _maxAllowedLevel(RecoveryState recoveryState) {
    switch (recoveryState) {
      case RecoveryState.slightlyTired:
        return 3;
      case RecoveryState.poorSleep:
        return 2;
      case RecoveryState.veryFatigued:
        return 1;
      case RecoveryState.feelingIll:
        return 0;
    }
  }

  int _levelRank(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 99;
    }

    final lower = value.toLowerCase();

    if (lower.contains('very high') || lower.contains('very hard')) {
      return 4;
    }

    if (lower.contains('high') || lower.contains('hard')) {
      return 3;
    }

    if (lower.contains('moderate') ||
        lower.contains('medium') ||
        lower.contains('standard')) {
      return 2;
    }

    if (lower.contains('very low')) {
      return 0;
    }

    if (lower.contains('low') ||
        lower.contains('light') ||
        lower.contains('minimal')) {
      return 1;
    }

    return 2;
  }
}
