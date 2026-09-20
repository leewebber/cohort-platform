import '../models/production_session_draft.dart';

class ProductionSessionDraftAuthority {
  const ProductionSessionDraftAuthority({
    required this.athleteId,
    required this.assignmentId,
    required this.programmeVersionId,
    required this.programmedSessionKey,
    this.occurrenceId,
    this.hostedCompleted = false,
  });

  final String athleteId;
  final String assignmentId;
  final String programmeVersionId;
  final String programmedSessionKey;
  final String? occurrenceId;
  final bool hostedCompleted;
}

class ProductionSessionDraftClassifier {
  const ProductionSessionDraftClassifier();

  ProductionDraftRestoreClass classify({
    required ProductionSessionDraft? draft,
    required ProductionSessionDraftAuthority authority,
    bool jsonCorrupt = false,
  }) {
    if (jsonCorrupt) {
      return ProductionDraftRestoreClass.corrupt;
    }
    if (draft == null) {
      return ProductionDraftRestoreClass.corrupt;
    }
    if (draft.schemaVersion > ProductionSessionDraft.currentSchemaVersion) {
      return ProductionDraftRestoreClass.unsupportedFutureVersion;
    }
    if (draft.athleteId.isEmpty ||
        draft.assignmentId.isEmpty ||
        draft.programmeVersionId.isEmpty ||
        draft.programmedSessionKey.isEmpty ||
        draft.packageContentHash.isEmpty ||
        draft.trainingSessionId <= 0) {
      if (draft.schemaVersion < ProductionSessionDraft.currentSchemaVersion) {
        return ProductionDraftRestoreClass.legacyPartial;
      }
      return ProductionDraftRestoreClass.corrupt;
    }
    if (draft.athleteId != authority.athleteId) {
      return ProductionDraftRestoreClass.foreignAthlete;
    }
    if (authority.hostedCompleted) {
      return ProductionDraftRestoreClass.completedHosted;
    }
    if (draft.programmeVersionId != authority.programmeVersionId) {
      return ProductionDraftRestoreClass.staleProgrammeVersion;
    }
    if (authority.occurrenceId != null &&
        draft.occurrenceId != null &&
        draft.occurrenceId != authority.occurrenceId) {
      return ProductionDraftRestoreClass.staleOccurrence;
    }
    if (draft.programmedSessionKey != authority.programmedSessionKey ||
        draft.assignmentId != authority.assignmentId) {
      return ProductionDraftRestoreClass.staleOccurrence;
    }
    if (draft.schemaVersion < ProductionSessionDraft.currentSchemaVersion) {
      return ProductionDraftRestoreClass.legacyPartial;
    }
    return ProductionDraftRestoreClass.compatible;
  }

  bool mayRestore(ProductionDraftRestoreClass value) {
    return value == ProductionDraftRestoreClass.compatible ||
        value == ProductionDraftRestoreClass.legacyPartial;
  }
}
