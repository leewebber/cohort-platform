import '../../../data/repositories/session_lineage_store.dart';
import '../../../data/repositories/session_lineage_supabase_store.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/session_revision_vocabulary.dart';
import '../../admin/services/protocol_builder_service.dart';
import '../models/session_revision_action_decision.dart';
import '../models/session_revision_action_vocabulary.dart';
import '../models/session_revision_usage_models.dart';
import 'session_revision_action_message_builder.dart';
import 'session_revision_content_protection.dart';
import 'session_revision_relationship_service.dart';

/// Converts M9.2 relationship facts and M9.1 lifecycle state into typed
/// Session Revision action decisions (M9.3).
class SessionRevisionActionPolicyService {
  SessionRevisionActionPolicyService({
    SessionLineageStore? lineageStore,
    SessionRevisionRelationshipService? relationshipService,
    ProtocolBuilderService? protocolBuilderService,
  })  : _lineageStore = lineageStore ?? const SessionLineageSupabaseStore(),
        _relationshipService = relationshipService ??
            SessionRevisionRelationshipService(
              lineageStore: lineageStore ?? const SessionLineageSupabaseStore(),
            ),
        _protocolBuilderService =
            protocolBuilderService ?? ProtocolBuilderService();

  final SessionLineageStore _lineageStore;
  final SessionRevisionRelationshipService _relationshipService;
  final ProtocolBuilderService _protocolBuilderService;

  static const _deleteBlockerPriority = [
    SessionRevisionActionReasonCode.revisionNotFound,
    SessionRevisionActionReasonCode.relationshipLookupFailed,
    SessionRevisionActionReasonCode.destructiveActionFailsClosed,
    SessionRevisionActionReasonCode.canonicalContentProtected,
    SessionRevisionActionReasonCode.publishedRevisionImmutable,
    SessionRevisionActionReasonCode.archivedRevisionImmutable,
    SessionRevisionActionReasonCode.usedByActiveAssignments,
    SessionRevisionActionReasonCode.referencedByProgrammeVersions,
    SessionRevisionActionReasonCode.hasHistoricalPerformances,
  ];

  Future<SessionRevisionActionDecision> evaluate(
    String protocolId,
    SessionRevisionAction action,
  ) async {
    final context = await _loadContext(protocolId.trim());
    return _evaluateAction(context: context, action: action);
  }

  Future<SessionRevisionActionPolicySummary> evaluateAll(
    String protocolId,
  ) async {
    final normalizedProtocolId = protocolId.trim();
    final context = await _loadContext(normalizedProtocolId);
    final decisions = {
      for (final action in SessionRevisionAction.values)
        action: _evaluateAction(context: context, action: action),
    };

    return SessionRevisionActionPolicySummary(
      protocolId: normalizedProtocolId,
      decisions: decisions,
    );
  }

  Future<SessionRevisionUsageLookupResult> tryGetUsageForRevision(
    String protocolId,
  ) {
    return _relationshipService.tryGetUsageForRevision(protocolId);
  }

  Future<_SessionRevisionPolicyContext> _loadContext(String protocolId) async {
    if (protocolId.isEmpty) {
      return _SessionRevisionPolicyContext.notFound(protocolId);
    }

    final identity = await _lineageStore.getRevisionIdentity(protocolId);
    if (identity == null) {
      return _SessionRevisionPolicyContext.notFound(protocolId);
    }

    final lifecycleStatus =
        await _lineageStore.getRevisionLifecycleStatus(protocolId);

    ProtocolDraft? draft;
    try {
      draft = await _protocolBuilderService.loadProtocol(protocolId);
    } catch (_) {
      draft = null;
    }

    final usageLookup = await _relationshipService.tryGetUsageForRevision(
      protocolId,
    );

    return _SessionRevisionPolicyContext(
      protocolId: protocolId,
      identity: identity,
      lifecycleStatus: lifecycleStatus ?? draft?.lifecycleStatus,
      draft: draft,
      usageLookup: usageLookup,
    );
  }

  SessionRevisionActionDecision _evaluateAction({
    required _SessionRevisionPolicyContext context,
    required SessionRevisionAction action,
  }) {
    switch (action) {
      case SessionRevisionAction.edit:
        return _evaluateEdit(context);
      case SessionRevisionAction.createNewRevision:
        return _evaluateCreateNewRevision(context);
      case SessionRevisionAction.publish:
        return _evaluatePublish(context);
      case SessionRevisionAction.archive:
        return _evaluateArchive(context);
      case SessionRevisionAction.delete:
        return _evaluateDelete(context);
    }
  }

  SessionRevisionActionDecision _evaluateEdit(_SessionRevisionPolicyContext context) {
    if (context.revisionNotFound) {
      return _blockingDecision(
        action: SessionRevisionAction.edit,
        primaryReasonCode: SessionRevisionActionReasonCode.revisionNotFound,
        reasons: const [SessionRevisionActionReasonCode.revisionNotFound],
        userMessage: 'This session revision could not be found.',
      );
    }

    final lifecycle = context.resolvedLifecycle;
    final nextRevision = context.identity!.revisionNumber + 1;

    if (lifecycle == SessionRevisionLifecycleStatus.draft) {
      return SessionRevisionActionDecision(
        action: SessionRevisionAction.edit,
        allowed: true,
        severity: SessionRevisionActionSeverity.info,
        primaryReasonCode: SessionRevisionActionReasonCode.allowedDraftEdit,
        reasons: const [SessionRevisionActionReasonCode.allowedDraftEdit],
        userMessage: SessionRevisionActionMessageBuilder.editBlockMessage(
          lifecycle: lifecycle,
          nextRevisionNumber: nextRevision,
        ),
      );
    }

    if (lifecycle == SessionRevisionLifecycleStatus.published) {
      return SessionRevisionActionDecision(
        action: SessionRevisionAction.edit,
        allowed: false,
        severity: SessionRevisionActionSeverity.blocking,
        primaryReasonCode:
            SessionRevisionActionReasonCode.publishedRevisionImmutable,
        reasons: const [
          SessionRevisionActionReasonCode.publishedRevisionImmutable,
        ],
        userMessage: SessionRevisionActionMessageBuilder.editBlockMessage(
          lifecycle: lifecycle,
          nextRevisionNumber: nextRevision,
        ),
        recommendedAlternative:
            SessionRevisionActionMessageBuilder.createRevisionRecommendation(
          nextRevision,
        ),
      );
    }

    return SessionRevisionActionDecision(
      action: SessionRevisionAction.edit,
      allowed: false,
      severity: SessionRevisionActionSeverity.blocking,
      primaryReasonCode:
          SessionRevisionActionReasonCode.archivedRevisionImmutable,
      reasons: const [
        SessionRevisionActionReasonCode.archivedRevisionImmutable,
      ],
      userMessage: SessionRevisionActionMessageBuilder.editBlockMessage(
        lifecycle: SessionRevisionLifecycleStatus.archived,
        nextRevisionNumber: nextRevision,
      ),
      recommendedAlternative:
          SessionRevisionActionMessageBuilder.createRevisionRecommendation(
        nextRevision,
      ),
    );
  }

  SessionRevisionActionDecision _evaluateCreateNewRevision(
    _SessionRevisionPolicyContext context,
  ) {
    if (context.revisionNotFound) {
      return _blockingDecision(
        action: SessionRevisionAction.createNewRevision,
        primaryReasonCode: SessionRevisionActionReasonCode.revisionNotFound,
        reasons: const [SessionRevisionActionReasonCode.revisionNotFound],
        userMessage: 'This session revision could not be found.',
      );
    }

    final draft = context.draft;
    if (draft != null &&
        SessionRevisionContentProtection.isCanonicalProtected(draft)) {
      return SessionRevisionActionDecision(
        action: SessionRevisionAction.createNewRevision,
        allowed: false,
        severity: SessionRevisionActionSeverity.blocking,
        primaryReasonCode:
            SessionRevisionActionReasonCode.canonicalContentProtected,
        reasons: const [
          SessionRevisionActionReasonCode.canonicalContentProtected,
        ],
        userMessage:
            'Official canonical content cannot be forked as a new revision here.',
        recommendedAlternative:
            SessionRevisionContentProtection.copyAndCustomiseAlternative(draft),
      );
    }

    final lifecycle = context.resolvedLifecycle;
    if (lifecycle == SessionRevisionLifecycleStatus.draft) {
      return SessionRevisionActionDecision(
        action: SessionRevisionAction.createNewRevision,
        allowed: false,
        severity: SessionRevisionActionSeverity.blocking,
        primaryReasonCode: SessionRevisionActionReasonCode.draftContinueEditing,
        reasons: const [SessionRevisionActionReasonCode.draftContinueEditing],
        userMessage:
            'Draft revisions are already editable in place. Continue editing this draft rather than creating another revision.',
        recommendedAlternative: 'Edit the existing draft in place.',
      );
    }

    if (lifecycle == SessionRevisionLifecycleStatus.published) {
      return SessionRevisionActionDecision(
        action: SessionRevisionAction.createNewRevision,
        allowed: true,
        severity: SessionRevisionActionSeverity.info,
        primaryReasonCode:
            SessionRevisionActionReasonCode.createRevisionFromPublished,
        reasons: const [
          SessionRevisionActionReasonCode.createRevisionFromPublished,
        ],
        userMessage:
            'You can create a new draft revision from this published revision.',
      );
    }

    return SessionRevisionActionDecision(
      action: SessionRevisionAction.createNewRevision,
      allowed: true,
      severity: SessionRevisionActionSeverity.info,
      primaryReasonCode:
          SessionRevisionActionReasonCode.createRevisionFromArchived,
      reasons: const [
        SessionRevisionActionReasonCode.createRevisionFromArchived,
      ],
      userMessage:
          'You can create a new draft revision from this archived revision.',
    );
  }

  SessionRevisionActionDecision _evaluatePublish(
    _SessionRevisionPolicyContext context,
  ) {
    if (context.revisionNotFound) {
      return _blockingDecision(
        action: SessionRevisionAction.publish,
        primaryReasonCode: SessionRevisionActionReasonCode.revisionNotFound,
        reasons: const [SessionRevisionActionReasonCode.revisionNotFound],
        userMessage: 'This session revision could not be found.',
      );
    }

    final lifecycle = context.resolvedLifecycle;
    if (lifecycle == SessionRevisionLifecycleStatus.draft) {
      return SessionRevisionActionDecision(
        action: SessionRevisionAction.publish,
        allowed: true,
        severity: SessionRevisionActionSeverity.info,
        primaryReasonCode:
            SessionRevisionActionReasonCode.publishAllowedSubjectToValidation,
        reasons: const [
          SessionRevisionActionReasonCode.publishAllowedSubjectToValidation,
          SessionRevisionActionReasonCode.draftRequiredForPublish,
        ],
        userMessage:
            'This draft revision can be published once existing builder validation passes.',
      );
    }

    if (lifecycle == SessionRevisionLifecycleStatus.published) {
      return _blockingDecision(
        action: SessionRevisionAction.publish,
        primaryReasonCode:
            SessionRevisionActionReasonCode.revisionAlreadyPublished,
        reasons: const [
          SessionRevisionActionReasonCode.revisionAlreadyPublished,
        ],
        userMessage: 'This revision is already published.',
      );
    }

    return SessionRevisionActionDecision(
      action: SessionRevisionAction.publish,
      allowed: false,
      severity: SessionRevisionActionSeverity.blocking,
      primaryReasonCode:
          SessionRevisionActionReasonCode.archivedRevisionCannotPublish,
      reasons: const [
        SessionRevisionActionReasonCode.archivedRevisionCannotPublish,
      ],
      userMessage: 'Archived revisions cannot be published.',
      recommendedAlternative:
          SessionRevisionActionMessageBuilder.createRevisionRecommendation(
        context.identity!.revisionNumber + 1,
      ),
    );
  }

  SessionRevisionActionDecision _evaluateArchive(
    _SessionRevisionPolicyContext context,
  ) {
    if (context.revisionNotFound) {
      return _blockingDecision(
        action: SessionRevisionAction.archive,
        primaryReasonCode: SessionRevisionActionReasonCode.revisionNotFound,
        reasons: const [SessionRevisionActionReasonCode.revisionNotFound],
        userMessage: 'This session revision could not be found.',
      );
    }

    final lifecycle = context.resolvedLifecycle;
    if (lifecycle == SessionRevisionLifecycleStatus.draft) {
      return _blockingDecision(
        action: SessionRevisionAction.archive,
        primaryReasonCode:
            SessionRevisionActionReasonCode.draftRevisionCannotArchive,
        reasons: const [
          SessionRevisionActionReasonCode.draftRevisionCannotArchive,
        ],
        userMessage:
            'Draft revisions are not archived. Delete the draft if it is unused, or publish it first.',
        recommendedAlternative: 'Delete the unused draft or publish it first.',
      );
    }

    if (lifecycle == SessionRevisionLifecycleStatus.archived) {
      return _blockingDecision(
        action: SessionRevisionAction.archive,
        primaryReasonCode: SessionRevisionActionReasonCode.alreadyArchived,
        reasons: const [SessionRevisionActionReasonCode.alreadyArchived],
        userMessage: 'This revision is already archived.',
      );
    }

    final usage = context.usageSummary;
    final userMessage = usage == null
        ? 'You can archive this published revision.'
        : SessionRevisionActionMessageBuilder.archiveImpactMessage(usage);

    final reasons = <SessionRevisionActionReasonCode>[
      SessionRevisionActionReasonCode.archivePublishedRevision,
    ];

    if (usage?.hasDirectAuthoredUsage == true) {
      reasons.add(SessionRevisionActionReasonCode.referencedByProgrammeVersions);
    }
    if (usage?.hasActiveOperationalUsage == true) {
      reasons.add(SessionRevisionActionReasonCode.usedByActiveAssignments);
    }
    if (usage?.hasHistoricalUsage == true) {
      reasons.add(SessionRevisionActionReasonCode.hasHistoricalPerformances);
    }

    return SessionRevisionActionDecision(
      action: SessionRevisionAction.archive,
      allowed: true,
      severity: usage != null && !usage.isUnused
          ? SessionRevisionActionSeverity.warning
          : SessionRevisionActionSeverity.info,
      primaryReasonCode: SessionRevisionActionReasonCode.archivePublishedRevision,
      reasons: reasons,
      userMessage: userMessage,
      usageSummary: usage,
    );
  }

  SessionRevisionActionDecision _evaluateDelete(
    _SessionRevisionPolicyContext context,
  ) {
    if (context.revisionNotFound) {
      return _blockingDecision(
        action: SessionRevisionAction.delete,
        primaryReasonCode: SessionRevisionActionReasonCode.revisionNotFound,
        reasons: const [SessionRevisionActionReasonCode.revisionNotFound],
        userMessage: SessionRevisionActionMessageBuilder.primaryDeleteBlockMessage(
          primaryReasonCode: SessionRevisionActionReasonCode.revisionNotFound,
          usage: null,
        ),
      );
    }

    if (context.usageLookupFailed) {
      return _blockingDecision(
        action: SessionRevisionAction.delete,
        primaryReasonCode:
            SessionRevisionActionReasonCode.relationshipLookupFailed,
        reasons: const [
          SessionRevisionActionReasonCode.relationshipLookupFailed,
          SessionRevisionActionReasonCode.destructiveActionFailsClosed,
        ],
        userMessage: SessionRevisionActionMessageBuilder.primaryDeleteBlockMessage(
          primaryReasonCode:
              SessionRevisionActionReasonCode.relationshipLookupFailed,
          usage: null,
        ),
      );
    }

    final blockers = <SessionRevisionActionReasonCode>[];
    final draft = context.draft;
    final lifecycle = context.resolvedLifecycle;
    final usage = context.usageSummary;

    if (draft != null &&
        SessionRevisionContentProtection.isCanonicalProtected(draft)) {
      blockers.add(SessionRevisionActionReasonCode.canonicalContentProtected);
    }

    if (lifecycle != SessionRevisionLifecycleStatus.draft) {
      blockers.add(
        lifecycle == SessionRevisionLifecycleStatus.published
            ? SessionRevisionActionReasonCode.publishedRevisionImmutable
            : SessionRevisionActionReasonCode.archivedRevisionImmutable,
      );
    }

    if (usage?.hasActiveOperationalUsage == true) {
      blockers.add(SessionRevisionActionReasonCode.usedByActiveAssignments);
    }

    if (usage?.hasDirectAuthoredUsage == true) {
      blockers.add(SessionRevisionActionReasonCode.referencedByProgrammeVersions);
    }

    if (usage?.hasHistoricalUsage == true) {
      blockers.add(SessionRevisionActionReasonCode.hasHistoricalPerformances);
    }

    if (blockers.isEmpty) {
      return SessionRevisionActionDecision(
        action: SessionRevisionAction.delete,
        allowed: true,
        severity: SessionRevisionActionSeverity.info,
        primaryReasonCode: SessionRevisionActionReasonCode.unusedDraft,
        reasons: const [SessionRevisionActionReasonCode.unusedDraft],
        userMessage: 'This unused draft revision can be deleted.',
        usageSummary: usage,
      );
    }

    final primaryReasonCode = _primaryDeleteBlocker(blockers);
    return SessionRevisionActionDecision(
      action: SessionRevisionAction.delete,
      allowed: false,
      severity: SessionRevisionActionSeverity.blocking,
      primaryReasonCode: primaryReasonCode,
      reasons: blockers,
      userMessage: SessionRevisionActionMessageBuilder.primaryDeleteBlockMessage(
        primaryReasonCode: primaryReasonCode,
        usage: usage,
      ),
      recommendedAlternative: _deleteRecommendedAlternative(
        primaryReasonCode: primaryReasonCode,
        draft: draft,
        nextRevisionNumber: (context.identity?.revisionNumber ?? 1) + 1,
      ),
      usageSummary: usage,
    );
  }

  SessionRevisionActionReasonCode _primaryDeleteBlocker(
    List<SessionRevisionActionReasonCode> blockers,
  ) {
    for (final reason in _deleteBlockerPriority) {
      if (blockers.contains(reason)) {
        return reason;
      }
    }

    return blockers.first;
  }

  String? _deleteRecommendedAlternative({
    required SessionRevisionActionReasonCode primaryReasonCode,
    required ProtocolDraft? draft,
    required int nextRevisionNumber,
  }) {
    switch (primaryReasonCode) {
      case SessionRevisionActionReasonCode.canonicalContentProtected:
        if (draft == null) return null;
        return SessionRevisionContentProtection.copyAndCustomiseAlternative(
          draft,
        );
      case SessionRevisionActionReasonCode.publishedRevisionImmutable:
      case SessionRevisionActionReasonCode.archivedRevisionImmutable:
      case SessionRevisionActionReasonCode.hasHistoricalPerformances:
        return 'Archive this revision instead.';
      case SessionRevisionActionReasonCode.usedByActiveAssignments:
        return 'Archive this revision and keep pinned programme execution intact.';
      case SessionRevisionActionReasonCode.referencedByProgrammeVersions:
        return 'Remove this revision from programme drafts before deleting it.';
      default:
        return null;
    }
  }

  SessionRevisionActionDecision _blockingDecision({
    required SessionRevisionAction action,
    required SessionRevisionActionReasonCode primaryReasonCode,
    required List<SessionRevisionActionReasonCode> reasons,
    required String userMessage,
    String? recommendedAlternative,
  }) {
    return SessionRevisionActionDecision(
      action: action,
      allowed: false,
      severity: SessionRevisionActionSeverity.blocking,
      primaryReasonCode: primaryReasonCode,
      reasons: reasons,
      userMessage: userMessage,
      recommendedAlternative: recommendedAlternative,
    );
  }
}

class _SessionRevisionPolicyContext {
  const _SessionRevisionPolicyContext({
    required this.protocolId,
    this.identity,
    this.lifecycleStatus,
    this.draft,
    required this.usageLookup,
  });

  factory _SessionRevisionPolicyContext.notFound(String protocolId) {
    return _SessionRevisionPolicyContext(
      protocolId: protocolId,
      usageLookup: const SessionRevisionUsageLookupResult.revisionNotFound(),
    );
  }

  final String protocolId;
  final SessionRevisionIdentity? identity;
  final SessionRevisionLifecycleStatus? lifecycleStatus;
  final ProtocolDraft? draft;
  final SessionRevisionUsageLookupResult usageLookup;

  bool get revisionNotFound => identity == null;

  bool get usageLookupFailed =>
      usageLookup.status == SessionRevisionUsageLookupStatus.lookupFailed;

  SessionRevisionUsageSummary? get usageSummary =>
      usageLookup.isSuccess ? usageLookup.summary : null;

  SessionRevisionLifecycleStatus get resolvedLifecycle =>
      lifecycleStatus ??
      draft?.lifecycleStatus ??
      SessionRevisionLifecycleStatus.draft;
}
