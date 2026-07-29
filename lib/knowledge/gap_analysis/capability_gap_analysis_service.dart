import 'package:cohort_platform/application/ports/capability_gap_analysis_reader.dart';
import 'package:cohort_platform/application/ports/knowledge_graph_reader.dart';
import 'package:cohort_platform/knowledge/models/knowledge_ontology_models.dart';

import 'capability_evidence_models.dart';

/// Default implementation using [KnowledgeGraphReader] + deterministic scoring.
class CapabilityGapAnalysisService implements CapabilityGapAnalysisReader {
  const CapabilityGapAnalysisService(this._knowledge);

  final KnowledgeGraphReader _knowledge;

  static const double _requiredGoalImportance = 1.0;
  static const double _optionalGoalImportance = 0.55;
  static const double _adequacyThreshold = 0.75;

  @override
  CapabilityGapAnalysisResult analyseGoal({
    required String goalId,
    required AthleteCapabilityEvidenceProfile evidenceProfile,
    DateTime? analysedAt,
  }) {
    final goal = _knowledge.goalRequirements(goalId);
    if (goal == null) {
      throw CapabilityGapAnalysisException('Unknown goal: $goalId');
    }

    final gaps = _buildGaps(goal: goal, evidenceProfile: evidenceProfile);
    final ranked = rankTrainingPriorities(
      goalId: goalId,
      evidenceProfile: evidenceProfile,
    );

    return CapabilityGapAnalysisResult(
      goalId: goalId,
      goalLabel: goal.meta.label,
      gaps: gaps,
      rankedPriorities: ranked,
      analysedAt: analysedAt ?? DateTime.now().toUtc(),
    );
  }

  @override
  List<CapabilityGap> identifyCapabilityGaps({
    required String goalId,
    required AthleteCapabilityEvidenceProfile evidenceProfile,
  }) {
    final goal = _knowledge.goalRequirements(goalId);
    if (goal == null) {
      throw CapabilityGapAnalysisException('Unknown goal: $goalId');
    }
    return _buildGaps(goal: goal, evidenceProfile: evidenceProfile);
  }

  @override
  List<CapabilityGap> rankTrainingPriorities({
    required String goalId,
    required AthleteCapabilityEvidenceProfile evidenceProfile,
  }) {
    final gaps = identifyCapabilityGaps(
      goalId: goalId,
      evidenceProfile: evidenceProfile,
    );
    final sorted = [...gaps]
      ..sort((a, b) {
        final byScore = b.priorityScore.compareTo(a.priorityScore);
        if (byScore != 0) return byScore;
        return a.capabilityId.compareTo(b.capabilityId);
      });
    return sorted;
  }

  List<CapabilityGap> _buildGaps({
    required GoalRequirementKnowledge goal,
    required AthleteCapabilityEvidenceProfile evidenceProfile,
  }) {
    final gaps = <CapabilityGap>[];
    final requirementEntries = [
      ...goal.requiredCapabilityIds.map(
        (id) => (id: id, importance: _requiredGoalImportance),
      ),
      ...goal.optionalCapabilityIds.map(
        (id) => (id: id, importance: _optionalGoalImportance),
      ),
    ];

    final adequacyByCapability = <String, double>{};

    for (final entry in requirementEntries) {
      final capability = _knowledge.capabilityById(entry.id);
      if (capability == null) continue;

      final evidence = evidenceProfile.evidenceFor(entry.id);
      final state = evidence?.state ?? CapabilityEvidenceState.unknown;
      final itemConfidence = evidence?.confidence ?? 0.0;
      final adequacy = _adequacyScore(
        state: state,
        itemConfidence: itemConfidence,
      );
      adequacyByCapability[entry.id] = adequacy;

      if (adequacy >= _adequacyThreshold) continue;

      final deficiency = 1.0 - adequacy;
      final prerequisiteIds = capability.prerequisiteIds;
      final blockers = <String>[];

      for (final prereqId in prerequisiteIds) {
        final prereqAdequacy =
            adequacyByCapability[prereqId] ??
            _adequacyForCapability(
              capabilityId: prereqId,
              evidenceProfile: evidenceProfile,
            );
        if (prereqAdequacy < _adequacyThreshold) {
          blockers.add(prereqId);
        }
      }

      final supportingPenalty = _supportingPenalty(
        capability: capability,
        evidenceProfile: evidenceProfile,
      );

      final score = _priorityScore(
        goalImportance: entry.importance,
        deficiency: deficiency,
        evidenceState: state,
        itemConfidence: itemConfidence,
        blockerCount: blockers.length,
        supportingPenalty: supportingPenalty,
      );

      gaps.add(
        CapabilityGap(
          capabilityId: entry.id,
          capabilityLabel: capability.meta.label,
          goalImportance: entry.importance,
          evidenceState: state,
          severity: _severity(deficiency, blockers.isNotEmpty),
          priorityScore: score,
          confidence: _analysisConfidence(
            state: state,
            itemConfidence: itemConfidence,
          ),
          rationale: _rationale(
            capabilityLabel: capability.meta.label,
            state: state,
            deficiency: deficiency,
            blockers: blockers,
            supportingPenalty: supportingPenalty,
          ),
          supportingEvidence: evidence != null ? [evidence] : const [],
          blockerCapabilityIds: blockers,
          prerequisiteCapabilityIds: prerequisiteIds,
        ),
      );
    }

    return gaps;
  }

  double _adequacyForCapability({
    required String capabilityId,
    required AthleteCapabilityEvidenceProfile evidenceProfile,
  }) {
    final evidence = evidenceProfile.evidenceFor(capabilityId);
    final state = evidence?.state ?? CapabilityEvidenceState.unknown;
    return _adequacyScore(
      state: state,
      itemConfidence: evidence?.confidence ?? 0.0,
    );
  }

  double _adequacyScore({
    required CapabilityEvidenceState state,
    required double itemConfidence,
  }) {
    if (state == CapabilityEvidenceState.unknown) return 0.0;
    final quality = state.qualityWeight;
    return (quality * 0.7 + itemConfidence.clamp(0.0, 1.0) * 0.3).clamp(
      0.0,
      1.0,
    );
  }

  double _supportingPenalty({
    required CapabilityKnowledge capability,
    required AthleteCapabilityEvidenceProfile evidenceProfile,
  }) {
    if (capability.supportingCapabilityIds.isEmpty) return 0.0;
    var weak = 0;
    for (final supportId in capability.supportingCapabilityIds) {
      final adequacy = _adequacyForCapability(
        capabilityId: supportId,
        evidenceProfile: evidenceProfile,
      );
      if (adequacy < _adequacyThreshold) weak++;
    }
    return (weak / capability.supportingCapabilityIds.length) * 0.15;
  }

  double _priorityScore({
    required double goalImportance,
    required double deficiency,
    required CapabilityEvidenceState evidenceState,
    required double itemConfidence,
    required int blockerCount,
    required double supportingPenalty,
  }) {
    final evidenceQuality =
        evidenceState.qualityWeight * itemConfidence.clamp(0.0, 1.0);
    final base = goalImportance * deficiency * (1.0 - evidenceQuality * 0.5);
    final prerequisiteBoost = blockerCount * 0.12 * goalImportance;
    return (base + prerequisiteBoost + supportingPenalty).clamp(0.0, 2.0);
  }

  CapabilityGapSeverity _severity(double deficiency, bool hasBlockers) {
    if (hasBlockers && deficiency > 0.4) return CapabilityGapSeverity.critical;
    if (deficiency > 0.65) return CapabilityGapSeverity.high;
    if (deficiency > 0.35) return CapabilityGapSeverity.moderate;
    return CapabilityGapSeverity.low;
  }

  double _analysisConfidence({
    required CapabilityEvidenceState state,
    required double itemConfidence,
  }) {
    if (state == CapabilityEvidenceState.unknown) return 0.35;
    return (0.4 + state.qualityWeight * 0.4 + itemConfidence * 0.2).clamp(
      0.0,
      1.0,
    );
  }

  String _rationale({
    required String capabilityLabel,
    required CapabilityEvidenceState state,
    required double deficiency,
    required List<String> blockers,
    required double supportingPenalty,
  }) {
    final buffer = StringBuffer(
      '$capabilityLabel is underdeveloped for this goal (adequacy gap ${(deficiency * 100).toStringAsFixed(0)}%). ',
    );
    buffer.write(
      state == CapabilityEvidenceState.unknown
          ? 'No evidence on file. '
          : 'Evidence is ${state.name} with limited adequacy. ',
    );
    if (blockers.isNotEmpty) {
      buffer.write('Blocked by weak prerequisites: ${blockers.join(', ')}. ');
    }
    if (supportingPenalty > 0.05) {
      buffer.write('Supporting capabilities are also underdeveloped. ');
    }
    return buffer.toString().trim();
  }
}

class CapabilityGapAnalysisException implements Exception {
  CapabilityGapAnalysisException(this.message);
  final String message;
  @override
  String toString() => 'CapabilityGapAnalysisException: $message';
}
