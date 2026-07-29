/// Stable knowledge relationship types (blueprint §4).
enum KnowledgeRelationshipType {
  expresses,
  requires,
  optionallyUses,
  primarilyTrains,
  secondarilyTrains,
  involvesJointAction,
  developsCapability,
  constrainedBy,
  suitableForEnvironment,
  targetsEnergySystem,
  supportsTrainingIntent,
  substitutesFor,
  preserves,
  compromises,
}

extension KnowledgeRelationshipTypeIds on KnowledgeRelationshipType {
  String get wireValue => switch (this) {
    KnowledgeRelationshipType.expresses => 'expresses',
    KnowledgeRelationshipType.requires => 'requires',
    KnowledgeRelationshipType.optionallyUses => 'optionally_uses',
    KnowledgeRelationshipType.primarilyTrains => 'primarily_trains',
    KnowledgeRelationshipType.secondarilyTrains => 'secondarily_trains',
    KnowledgeRelationshipType.involvesJointAction => 'involves_joint_action',
    KnowledgeRelationshipType.developsCapability => 'develops_capability',
    KnowledgeRelationshipType.constrainedBy => 'constrained_by',
    KnowledgeRelationshipType.suitableForEnvironment =>
      'suitable_for_environment',
    KnowledgeRelationshipType.targetsEnergySystem => 'targets_energy_system',
    KnowledgeRelationshipType.supportsTrainingIntent =>
      'supports_training_intent',
    KnowledgeRelationshipType.substitutesFor => 'substitutes_for',
    KnowledgeRelationshipType.preserves => 'preserves',
    KnowledgeRelationshipType.compromises => 'compromises',
  };
}
