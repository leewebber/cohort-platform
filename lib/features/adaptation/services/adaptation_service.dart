import '../../../data/repositories/protocol_repository.dart';
import '../../../models/adaptation_scoring_reason.dart';
import '../../../models/adaptation_recommendation.dart';
import '../../../models/protocol.dart';

class AdaptationService {
  const AdaptationService(this._protocolRepository);

  final ProtocolRepository _protocolRepository;

  static const _penalizedRequiredEquipment = [
    'bike erg',
    'row erg',
    'rower',
    'ski erg',
    'full gym',
    'sandbag',
  ];

  static const _preferredLimitedRequiredEquipment = [
    'bodyweight',
    'minimal kit',
  ];

  Future<List<AdaptationRecommendation>> getRecommendations({
    required Protocol currentProtocol,
    required AdaptationScoringReason reason,
  }) async {
    final protocols = await _protocolRepository.getProtocols();

    final candidates = protocols
        .where((protocol) => protocol.protocolId != currentProtocol.protocolId)
        .where((protocol) => _matchesCapability(protocol, currentProtocol, reason))
        .toList();

    final scored = candidates
        .map(
          (protocol) => (
            protocol: protocol,
            score: _scoreProtocol(
              protocol,
              currentProtocol,
              reason,
            ),
          ),
        )
        .toList();

    scored.sort((a, b) {
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;

      return a.protocol.name.compareTo(b.protocol.name);
    });

    final positiveScores =
        scored.where((entry) => entry.score > 0).take(3).toList();

    return positiveScores
        .map(
          (entry) => AdaptationRecommendation(
            protocol: entry.protocol,
            score: entry.score,
          ),
        )
        .toList();
  }

  bool _matchesCapability(
    Protocol candidate,
    Protocol currentProtocol,
    AdaptationScoringReason reason,
  ) {
    if (reason == AdaptationScoringReason.poorRecovery) {
      return _matchesPoorRecoveryCapability(candidate, currentProtocol);
    }

    final currentCapability = currentProtocol.goal?.trim().toLowerCase();
    if (currentCapability == null || currentCapability.isEmpty) {
      return true;
    }

    final candidateCapability = candidate.goal?.trim().toLowerCase();
    return candidateCapability == currentCapability;
  }

  bool _matchesPoorRecoveryCapability(
    Protocol candidate,
    Protocol currentProtocol,
  ) {
    final currentCapability = currentProtocol.goal?.trim().toLowerCase();
    final candidateCapability = candidate.goal?.trim().toLowerCase();

    if (currentCapability == null ||
        currentCapability.isEmpty ||
        candidateCapability == currentCapability) {
      return true;
    }

    return candidateCapability == 'recovery' || candidateCapability == 'mobility';
  }

  int _scoreProtocol(
    Protocol candidate,
    Protocol currentProtocol,
    AdaptationScoringReason reason,
  ) {
    switch (reason) {
      case AdaptationScoringReason.poorRecovery:
        return _scorePoorRecovery(candidate, currentProtocol);
      case AdaptationScoringReason.limitedEquipment:
        return _scoreLimitedEquipment(candidate, currentProtocol);
      case AdaptationScoringReason.travelling:
        return _scoreTravelling(candidate);
      case AdaptationScoringReason.shortOnTime:
        return _scoreShortOnTime(candidate, currentProtocol);
    }
  }

  int _scorePoorRecovery(Protocol candidate, Protocol currentProtocol) {
    var score = 0;

    if (_isLowOrVeryLow(candidate.recovery)) {
      score += 15;
    }

    if (_isLowOrVeryLow(candidate.demand)) {
      score += 15;
    }

    final capability = candidate.goal?.trim().toLowerCase();
    if (capability == 'recovery' || capability == 'mobility') {
      score += 10;
    }

    if (_isLowerLevel(candidate.demand, currentProtocol.demand)) {
      score += 5;
    }

    if (_isLowerLevel(candidate.recovery, currentProtocol.recovery)) {
      score += 5;
    }

    return score;
  }

  int _scoreLimitedEquipment(Protocol candidate, Protocol currentProtocol) {
    var score = 0;

    if (_requiredEquipmentContainsAny(
      candidate.requiredEquipment,
      _preferredLimitedRequiredEquipment,
    )) {
      score += 15;
    } else if (_matchesEquipmentPreference(candidate.equipment)) {
      score += 5;
    }

    if (_adaptabilityAtLeast(candidate.adaptability, 4)) {
      score += 10;
    }

    score += _penalizedRequiredEquipmentScore(candidate.requiredEquipment);
    score += _veryHighStressPenalty(
      candidate,
      currentProtocol: currentProtocol,
      unlessCurrentAlsoVeryHigh: true,
    );

    return score;
  }

  int _scoreTravelling(Protocol candidate) {
    var score = 0;

    if (candidate.hotelFriendly == true) {
      score += 10;
    } else if (_matchesTravelEnvironment(candidate.environment)) {
      score += 5;
    }

    if (_adaptabilityAtLeast(candidate.adaptability, 4)) {
      score += 10;
    }

    score += _penalizedRequiredEquipmentScore(candidate.requiredEquipment);
    score += _veryHighStressPenalty(candidate);

    if (_matchesEquipmentPreference(candidate.equipment)) {
      score += 5;
    }

    return score;
  }

  int _scoreShortOnTime(Protocol candidate, Protocol currentProtocol) {
    var score = 0;

    if (_isMicroOrShort(candidate.durationCategory)) {
      score += 15;
    }

    if (_isLowOrModerate(candidate.recovery)) {
      score += 10;
    }

    final candidateDuration = candidate.durationMin;
    if (candidateDuration != null && candidateDuration <= 30) {
      score += 10;
    }

    score += _veryHighStressPenalty(
      candidate,
      currentProtocol: currentProtocol,
      unlessCurrentAlsoVeryHigh: true,
    );

    final currentDuration = currentProtocol.durationMin;
    if (candidateDuration == null) {
      return score;
    }

    if (currentDuration == null) {
      return score + (1000 - candidateDuration);
    }

    if (candidateDuration < currentDuration) {
      score += 10 + (currentDuration - candidateDuration);
    } else if (candidateDuration == currentDuration) {
      score += 1;
    }

    return score;
  }

  int _veryHighStressPenalty(
    Protocol candidate, {
    Protocol? currentProtocol,
    bool unlessCurrentAlsoVeryHigh = false,
  }) {
    var penalty = 0;

    if (_isVeryHigh(candidate.demand)) {
      final shouldPenalize = !unlessCurrentAlsoVeryHigh ||
          !_isVeryHigh(currentProtocol?.demand);
      if (shouldPenalize) {
        penalty -= 20;
      }
    }

    if (_isVeryHigh(candidate.recovery)) {
      final shouldPenalize = !unlessCurrentAlsoVeryHigh ||
          !_isVeryHigh(currentProtocol?.recovery);
      if (shouldPenalize) {
        penalty -= 20;
      }
    }

    return penalty;
  }

  bool _isVeryHigh(String? value) {
    if (value == null || value.trim().isEmpty) return false;

    return value.trim().toLowerCase() == 'very high';
  }

  bool _isLowOrModerate(String? value) {
    if (value == null || value.trim().isEmpty) return false;

    final lower = value.trim().toLowerCase();
    return lower == 'low' || lower == 'moderate';
  }

  int _penalizedRequiredEquipmentScore(String? requiredEquipment) {
    if (!_requiredEquipmentContainsAny(
      requiredEquipment,
      _penalizedRequiredEquipment,
    )) {
      return 0;
    }

    return -20;
  }

  bool _adaptabilityAtLeast(int? adaptability, int minimum) {
    return adaptability != null && adaptability >= minimum;
  }

  bool _isMicroOrShort(String? durationCategory) {
    if (durationCategory == null || durationCategory.trim().isEmpty) {
      return false;
    }

    final lower = durationCategory.trim().toLowerCase();
    return lower == 'micro' || lower == 'short';
  }

  bool _isLowOrVeryLow(String? value) {
    if (value == null || value.trim().isEmpty) return false;

    final lower = value.trim().toLowerCase();
    return lower == 'very low' || lower == 'low';
  }

  bool _requiredEquipmentContainsAny(
    String? requiredEquipment,
    List<String> tokens,
  ) {
    final equipmentTokens = _equipmentTokens(requiredEquipment);
    if (equipmentTokens.isEmpty) return false;

    for (final token in equipmentTokens) {
      for (final match in tokens) {
        if (token == match || token.contains(match)) {
          return true;
        }
      }
    }

    return false;
  }

  Set<String> _equipmentTokens(String? value) {
    if (value == null || value.trim().isEmpty) {
      return {};
    }

    return value
        .split(',')
        .map((part) => part.trim().toLowerCase())
        .where((part) => part.isNotEmpty)
        .toSet();
  }

  bool _isLowerLevel(String? candidateValue, String? currentValue) {
    final candidateRank = _levelRank(candidateValue);
    final currentRank = _levelRank(currentValue);

    if (candidateRank == currentRank) return false;

    return candidateRank < currentRank;
  }

  int _levelRank(String? value) {
    if (value == null || value.trim().isEmpty) return 99;

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

  bool _matchesEquipmentPreference(String? equipment) {
    if (equipment == null || equipment.trim().isEmpty) return false;

    final lower = equipment.toLowerCase();

    return lower.contains('bodyweight') ||
        lower.contains('body weight') ||
        lower.contains('minimal') ||
        lower.contains('min kit') ||
        lower.contains('home');
  }

  bool _matchesTravelEnvironment(String? environment) {
    if (environment == null || environment.trim().isEmpty) return false;

    final lower = environment.toLowerCase();

    return lower.contains('hotel') ||
        lower.contains('home') ||
        lower.contains('anywhere');
  }
}
