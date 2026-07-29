enum PlanningRecommendationStatus {
  /// Phase, block, week type, intents, and archetype coherently resolved.
  complete,

  /// Strategic recommendation exists; one or more non-critical outputs missing.
  partial,

  /// Required capabilities lack evidence for confident prioritisation.
  insufficientEvidence,

  /// Hard constraints prevent a coherent semantic recommendation.
  infeasible,

  /// Input contracts, ontology, ids, or precomputed outputs incompatible.
  invalidInput,
}

enum PlanningExplainabilityLayer {
  goal,
  evidence,
  capabilityGap,
  trainingIntent,
  programmeSemantics,
  planningPolicy,
}

enum PlanningFactorSeverity { info, notice, warning, critical }

class PlanningExplainabilityFactor {
  const PlanningExplainabilityFactor({
    required this.layer,
    required this.code,
    required this.summary,
    required this.rationale,
    this.sourceEntityIds = const [],
    this.confidence,
    this.severity = PlanningFactorSeverity.info,
    this.metadata = const {},
  });

  final PlanningExplainabilityLayer layer;
  final String code;
  final String summary;
  final String rationale;
  final List<String> sourceEntityIds;
  final double? confidence;
  final PlanningFactorSeverity severity;
  final Map<String, String> metadata;
}

class PlanningExplainability {
  const PlanningExplainability({
    required this.factors,
    required this.narrativeSummary,
  });

  final List<PlanningExplainabilityFactor> factors;
  final String narrativeSummary;
}

class PlanningCapabilityPriority {
  const PlanningCapabilityPriority({
    required this.capabilityId,
    required this.capabilityLabel,
    required this.priorityScore,
    required this.rationale,
    this.gapSeverity,
  });

  final String capabilityId;
  final String capabilityLabel;
  final double priorityScore;
  final String rationale;
  final String? gapSeverity;
}

class PlanningIntentPriority {
  const PlanningIntentPriority({
    required this.trainingIntentId,
    required this.trainingIntentLabel,
    required this.priorityScore,
    required this.suitability,
    required this.rationale,
    required this.capabilityId,
  });

  final String trainingIntentId;
  final String trainingIntentLabel;
  final double priorityScore;
  final double suitability;
  final String rationale;
  final String capabilityId;
}

enum PlanningConstraintKind {
  equipment,
  environment,
  time,
  injury,
  travel,
  policy,
}

class PlanningConstraint {
  const PlanningConstraint({
    required this.kind,
    required this.code,
    required this.description,
  });

  final PlanningConstraintKind kind;
  final String code;
  final String description;
}

class PlanningWarning {
  const PlanningWarning({required this.code, required this.message});

  final String code;
  final String message;
}

class PlanningPhaseSelection {
  const PlanningPhaseSelection({
    required this.phaseId,
    required this.label,
    required this.inferred,
  });

  final String phaseId;
  final String label;
  final bool inferred;
}

class PlanningBlockSelection {
  const PlanningBlockSelection({
    required this.blockId,
    required this.label,
    required this.inferred,
    this.selectionScore,
  });

  final String blockId;
  final String label;
  final bool inferred;
  final double? selectionScore;
}

class PlanningWeekTypeSelection {
  const PlanningWeekTypeSelection({
    required this.weekTypeId,
    required this.label,
    required this.inferred,
  });

  final String weekTypeId;
  final String label;
  final bool inferred;
}

class PlanningArchetypeSelection {
  const PlanningArchetypeSelection({
    required this.archetypeId,
    required this.label,
    required this.planningRelevanceScore,
    required this.primaryTrainingIntentId,
  });

  final String archetypeId;
  final String label;
  final double planningRelevanceScore;
  final String primaryTrainingIntentId;
}

/// Canonical planning output (ADR-026) — no exercises or prescriptions.
class PlanningRecommendation {
  const PlanningRecommendation({
    required this.athleteId,
    required this.goalId,
    required this.ontologyVersion,
    required this.generatedAt,
    required this.status,
    required this.capabilityPriorities,
    required this.trainingIntentRecommendations,
    this.selectedProgrammePhase,
    this.recommendedTrainingBlock,
    this.selectedWeekType,
    this.recommendedSessionArchetype,
    this.constraints = const [],
    required this.confidence,
    required this.adaptationRationale,
    required this.explainability,
    this.warnings = const [],
  });

  final String athleteId;
  final String goalId;
  final String ontologyVersion;
  final DateTime generatedAt;
  final PlanningRecommendationStatus status;
  final List<PlanningCapabilityPriority> capabilityPriorities;
  final List<PlanningIntentPriority> trainingIntentRecommendations;
  final PlanningPhaseSelection? selectedProgrammePhase;
  final PlanningBlockSelection? recommendedTrainingBlock;
  final PlanningWeekTypeSelection? selectedWeekType;
  final PlanningArchetypeSelection? recommendedSessionArchetype;
  final List<PlanningConstraint> constraints;
  final double confidence;
  final List<String> adaptationRationale;
  final PlanningExplainability explainability;
  final List<PlanningWarning> warnings;
}
