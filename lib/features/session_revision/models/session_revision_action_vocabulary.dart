/// Supported Session Revision actions for policy evaluation (M9.3).
enum SessionRevisionAction {
  edit,
  createNewRevision,
  publish,
  archive,
  delete,
}

extension SessionRevisionActionLabels on SessionRevisionAction {
  String get displayLabel {
    switch (this) {
      case SessionRevisionAction.edit:
        return 'Edit';
      case SessionRevisionAction.createNewRevision:
        return 'Create new revision';
      case SessionRevisionAction.publish:
        return 'Publish';
      case SessionRevisionAction.archive:
        return 'Archive';
      case SessionRevisionAction.delete:
        return 'Delete';
    }
  }
}

/// Structured reason codes for Session Revision action decisions.
enum SessionRevisionActionReasonCode {
  allowedDraftEdit,
  publishedRevisionImmutable,
  archivedRevisionImmutable,
  createRevisionFromPublished,
  createRevisionFromArchived,
  draftRequiredForPublish,
  revisionAlreadyPublished,
  archivedRevisionCannotPublish,
  referencedByProgrammeVersions,
  usedByActiveAssignments,
  hasHistoricalPerformances,
  unusedDraft,
  archivePublishedRevision,
  draftRevisionCannotArchive,
  alreadyArchived,
  revisionNotFound,
  relationshipLookupFailed,
  destructiveActionFailsClosed,
  canonicalContentProtected,
  draftContinueEditing,
  publishAllowedSubjectToValidation,
}

/// Decision severity for future Coach Studio UI.
enum SessionRevisionActionSeverity {
  info,
  warning,
  blocking,
}

extension SessionRevisionActionSeverityLabels on SessionRevisionActionSeverity {
  String get displayLabel {
    switch (this) {
      case SessionRevisionActionSeverity.info:
        return 'Info';
      case SessionRevisionActionSeverity.warning:
        return 'Warning';
      case SessionRevisionActionSeverity.blocking:
        return 'Blocking';
    }
  }
}
