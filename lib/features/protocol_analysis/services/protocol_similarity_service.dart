import '../../../models/movement_profile.dart';
import '../../../models/protocol_analysis.dart';
import '../../../models/protocol_similarity_result.dart';
import '../../../models/session_fingerprint.dart';

/// Compares two [ProtocolAnalysis] objects for experiential similarity.
///
/// v0.1 scores fingerprint enum matches and movement-profile percentage
/// alignment. Not yet wired into adaptation ranking.
class ProtocolSimilarityService {
  const ProtocolSimilarityService();

  static const _dominantStimulusWeight = 25.0;
  static const _structureTypeWeight = 15.0;
  static const _pacingStyleWeight = 10.0;
  static const _equipmentDependencyWeight = 10.0;
  static const _movementBiasWeight = 10.0;
  static const _transitionDensityWeight = 5.0;
  static const _substitutionDifficultyWeight = 5.0;
  static const _movementProfileWeight = 20.0;

  static const _movementDistributionReasonThreshold = 16.0;

  ProtocolSimilarityResult compare({
    required ProtocolAnalysis source,
    required ProtocolAnalysis candidate,
  }) {
    final reasons = <String>[];
    var score = 0.0;

    final sourceFingerprint = source.fingerprint;
    final candidateFingerprint = candidate.fingerprint;

    if (sourceFingerprint != null && candidateFingerprint != null) {
      if (sourceFingerprint.dominantStimulus ==
          candidateFingerprint.dominantStimulus) {
        score += _dominantStimulusWeight;
        reasons.add('Same dominant stimulus');
      }

      if (sourceFingerprint.structureType == candidateFingerprint.structureType) {
        score += _structureTypeWeight;
        reasons.add(_structureMatchReason(sourceFingerprint.structureType));
      }

      if (sourceFingerprint.pacingStyle == candidateFingerprint.pacingStyle) {
        score += _pacingStyleWeight;
        reasons.add('Same pacing style');
      }

      if (sourceFingerprint.equipmentDependency ==
          candidateFingerprint.equipmentDependency) {
        score += _equipmentDependencyWeight;
        reasons.add('Same equipment dependency');
      }

      if (sourceFingerprint.movementBias == candidateFingerprint.movementBias) {
        score += _movementBiasWeight;
        reasons.add('Same movement bias');
      }

      if (sourceFingerprint.transitionDensity ==
          candidateFingerprint.transitionDensity) {
        score += _transitionDensityWeight;
        reasons.add('Same transition density');
      }

      if (sourceFingerprint.substitutionDifficulty ==
          candidateFingerprint.substitutionDifficulty) {
        score += _substitutionDifficultyWeight;
        reasons.add('Same substitution difficulty');
      }
    }

    final movementScore = _movementProfileSimilarityScore(
      source.movementProfile,
      candidate.movementProfile,
    );
    score += movementScore;

    if (movementScore >= _movementDistributionReasonThreshold) {
      reasons.add('Similar movement distribution');
    }

    return ProtocolSimilarityResult(
      sourceProtocolId: source.protocolId,
      candidateProtocolId: candidate.protocolId,
      score: score.clamp(0, 100),
      reasons: reasons,
    );
  }

  List<ProtocolSimilarityResult> rankCandidates({
    required ProtocolAnalysis source,
    required List<ProtocolAnalysis> candidates,
  }) {
    final results = candidates
        .where((candidate) => candidate.protocolId != source.protocolId)
        .map(
          (candidate) => compare(source: source, candidate: candidate),
        )
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return results;
  }

  double _movementProfileSimilarityScore(
    MovementProfile? source,
    MovementProfile? candidate,
  ) {
    if (source == null || candidate == null) {
      return 0;
    }

    final diffs = <double>[
      (source.pushPercent - candidate.pushPercent).abs(),
      (source.pullPercent - candidate.pullPercent).abs(),
      (source.squatPercent - candidate.squatPercent).abs(),
      (source.hingePercent - candidate.hingePercent).abs(),
      (source.lungePercent - candidate.lungePercent).abs(),
      (source.carryPercent - candidate.carryPercent).abs(),
      (source.corePercent - candidate.corePercent).abs(),
      (source.runningPercent - candidate.runningPercent).abs(),
      (source.ergPercent - candidate.ergPercent).abs(),
    ];

    final meanAbsDiff = diffs.reduce((sum, diff) => sum + diff) / diffs.length;
    final similarityRatio = (1 - (meanAbsDiff / 100)).clamp(0.0, 1.0);

    return _movementProfileWeight * similarityRatio;
  }

  String _structureMatchReason(SessionStructureType structureType) {
    switch (structureType) {
      case SessionStructureType.circuit:
        return 'Same circuit structure';
      case SessionStructureType.amrap:
        return 'Same AMRAP structure';
      case SessionStructureType.emom:
        return 'Same EMOM structure';
      case SessionStructureType.intervals:
        return 'Same interval structure';
      case SessionStructureType.strength:
        return 'Same strength structure';
      case SessionStructureType.continuous:
        return 'Same continuous structure';
      case SessionStructureType.unknown:
        return 'Same session structure';
    }
  }
}
