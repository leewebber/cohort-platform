/// M9 Content Relationship Graph vocabulary.
///
/// These types are the local Sprint 1 contract. They do not replace
/// `programme_lineages` / `programme_versions` / `protocol_id` production
/// tables and must not be imported by `lib/main.dart`.
library;

enum ContentNodeType {
  exercise,
  sessionTemplate,
  sessionTemplateVersion,
  programme,
  programmeVersion,
  programmePlacement,
  authoredBlock,
  pinnedAssignment,
  equipmentRequirement,
  capabilityTag,
  publisher,
}

enum ContentLifecycle {
  draft,
  published,
  retired,
}

enum ContentRelationshipType {
  exerciseUsedByBlock,
  blockBelongsToSessionTemplateVersion,
  sessionTemplateVersionUsedByPlacement,
  placementBelongsToProgrammeVersion,
  programmeVersionBelongsToProgramme,
  programmeVersionSupersedes,
  programmeVersionRequiresEquipment,
  targetsCapability,
  authoredBy,
  assignmentPinnedToProgrammeVersion,
  occurrenceDerivedFromPlacement,
  executionPlanDerivedFromAssignedContent,
  evidenceReferencesExerciseAndSlot,
}

enum ContentDiffClass {
  breakingExecution,
  materialTraining,
  metadataPresentation,
}

enum ContentGraphFailureCode {
  unauthorized,
  illegalLifecycle,
  publishedImmutable,
  unresolvedReference,
  ambiguousReference,
  identicalCanonicalContent,
  danglingRelationship,
  cycleDetected,
  namespaceIsolation,
  assignmentPinned,
  notFound,
  validationFailed,
  staleGraph,
  sourceHashMismatch,
  missingSourceHash,
  unsupportedCompiler,
  compositeMismatch,
  supplementalMismatch,
}

enum ContentUsageScope {
  draft,
  published,
  retired,
  historicalAssigned,
  activeAssigned,
}

enum ContentAuthRole {
  firstPartyPublisher,
  externalPublisher,
  reader,
}
