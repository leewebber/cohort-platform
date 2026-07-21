import '../../../models/session_revision_vocabulary.dart';
import '../models/session_revision_action_vocabulary.dart';
import '../models/session_revision_usage_models.dart';

/// User-facing messages for Session Revision action policy decisions.
class SessionRevisionActionMessageBuilder {
  const SessionRevisionActionMessageBuilder._();

  static String createRevisionRecommendation(int nextRevisionNumber) {
    return 'Create draft revision $nextRevisionNumber instead.';
  }

  static String programmeReferenceDeleteBlock({
    required int programmeReferenceCount,
    required int slotReferenceCount,
  }) {
    if (programmeReferenceCount <= 0) {
      return 'Cannot delete this revision because it is referenced by programme content.';
    }

    final versionLabel = programmeReferenceCount == 1
        ? '1 programme version'
        : '$programmeReferenceCount programme versions';
    final slotLabel =
        slotReferenceCount == 1 ? '1 slot' : '$slotReferenceCount slots';

    return 'Cannot delete this draft because it is used in $versionLabel across $slotLabel.';
  }

  static String activeAssignmentDeleteBlock(int assignmentCount) {
    final label = assignmentCount == 1
        ? '1 active programme assignment'
        : '$assignmentCount active programme assignments';
    return 'Cannot delete this revision because $label depend on it.';
  }

  static String historicalDeleteBlock(int recordCount) {
    final label = recordCount == 1
        ? '1 historical performance'
        : '$recordCount historical performances';
    return 'Cannot delete this revision because it has $label. Archive it instead.';
  }

  static String archiveImpactMessage(SessionRevisionUsageSummary usage) {
    if (usage.isUnused) {
      return 'You can archive this revision.';
    }

    return 'You can archive this revision. Existing programmes and athlete history will continue to use it.';
  }

  static String primaryDeleteBlockMessage({
    required SessionRevisionActionReasonCode primaryReasonCode,
    required SessionRevisionUsageSummary? usage,
  }) {
    switch (primaryReasonCode) {
      case SessionRevisionActionReasonCode.revisionNotFound:
        return 'This session revision could not be found.';
      case SessionRevisionActionReasonCode.relationshipLookupFailed:
      case SessionRevisionActionReasonCode.destructiveActionFailsClosed:
        return 'Cannot delete this revision because usage could not be verified. Try again later.';
      case SessionRevisionActionReasonCode.canonicalContentProtected:
        return 'This canonical session content is protected and cannot be deleted.';
      case SessionRevisionActionReasonCode.publishedRevisionImmutable:
        return 'Published revisions cannot be deleted. Archive it instead.';
      case SessionRevisionActionReasonCode.archivedRevisionImmutable:
        return 'Archived revisions cannot be deleted.';
      case SessionRevisionActionReasonCode.usedByActiveAssignments:
        return activeAssignmentDeleteBlock(
          usage?.activeAssignmentReferences.length ?? 0,
        );
      case SessionRevisionActionReasonCode.referencedByProgrammeVersions:
        return programmeReferenceDeleteBlock(
          programmeReferenceCount: usage?.programmeReferenceCount ?? 0,
          slotReferenceCount: usage?.slotReferenceCount ?? 0,
        );
      case SessionRevisionActionReasonCode.hasHistoricalPerformances:
        return historicalDeleteBlock(usage?.historicalUsage.recordCount ?? 0);
      case SessionRevisionActionReasonCode.unusedDraft:
        return 'This unused draft revision can be deleted.';
      default:
        return 'This action is not allowed for the current revision state.';
    }
  }

  static String editBlockMessage({
    required SessionRevisionLifecycleStatus lifecycle,
    required int nextRevisionNumber,
  }) {
    switch (lifecycle) {
      case SessionRevisionLifecycleStatus.published:
        return 'Published revisions cannot be edited. '
            '${createRevisionRecommendation(nextRevisionNumber)}';
      case SessionRevisionLifecycleStatus.archived:
        return 'Archived revisions cannot be edited in place. '
            '${createRevisionRecommendation(nextRevisionNumber)}';
      case SessionRevisionLifecycleStatus.draft:
        return 'This draft revision can be edited in place.';
    }
  }
}
