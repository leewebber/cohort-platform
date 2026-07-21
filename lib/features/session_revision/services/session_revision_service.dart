import '../../../data/repositories/session_lineage_store.dart';
import '../../../data/repositories/session_lineage_supabase_store.dart';
import '../../../data/repositories/session_revision_delete_store.dart';
import '../../../data/repositories/session_revision_delete_supabase_store.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/session_lineage.dart';
import '../../../models/session_revision_vocabulary.dart';
import '../../admin/services/protocol_builder_service.dart';
import '../models/session_revision_action_decision.dart';
import '../models/session_revision_action_vocabulary.dart';
import 'session_revision_action_policy_service.dart';
import 'session_revision_clone.dart';

class CreateSessionRevisionResult {
  const CreateSessionRevisionResult({
    required this.draft,
    required this.sourceProtocolId,
    required this.sessionLineageId,
    required this.revisionNumber,
  });

  final ProtocolDraft draft;
  final String sourceProtocolId;
  final String sessionLineageId;
  final int revisionNumber;
}

class SessionRevisionService {
  SessionRevisionService({
    SessionLineageStore? lineageStore,
    ProtocolBuilderService? protocolBuilderService,
    SessionRevisionClone? revisionClone,
    SessionRevisionActionPolicyService? actionPolicyService,
    SessionRevisionDeleteStore? deleteStore,
  })  : _lineageStore = lineageStore ?? const SessionLineageSupabaseStore(),
        _protocolBuilderService =
            protocolBuilderService ?? ProtocolBuilderService(),
        _revisionClone = revisionClone ?? const SessionRevisionClone(),
        _actionPolicyService = actionPolicyService ??
            SessionRevisionActionPolicyService(
              lineageStore: lineageStore ?? const SessionLineageSupabaseStore(),
              protocolBuilderService: protocolBuilderService,
            ),
        _deleteStore = deleteStore ?? const SessionRevisionDeleteSupabaseStore();

  final SessionLineageStore _lineageStore;
  final ProtocolBuilderService _protocolBuilderService;
  final SessionRevisionClone _revisionClone;
  final SessionRevisionActionPolicyService _actionPolicyService;
  final SessionRevisionDeleteStore _deleteStore;

  Future<SessionLineage> createLineage({
    required String displayName,
    String? id,
  }) {
    return _lineageStore.insertLineage(displayName: displayName, id: id);
  }

  Future<bool> isRevisionEditable(String protocolId) async {
    final status = await _lineageStore.getRevisionLifecycleStatus(protocolId);
    return status == SessionRevisionLifecycleStatus.draft;
  }

  Future<bool> isRevisionPublished(String protocolId) async {
    final status = await _lineageStore.getRevisionLifecycleStatus(protocolId);
    return status == SessionRevisionLifecycleStatus.published;
  }

  Future<SessionRevisionActionDecision> evaluateAction({
    required String protocolId,
    required SessionRevisionAction action,
  }) {
    return _actionPolicyService.evaluate(protocolId, action);
  }

  /// Creates a new draft revision from a published or archived revision.
  ///
  /// Published revisions are never edited in place — callers must use this path.
  Future<CreateSessionRevisionResult> createNewSessionRevision({
    required String sourceProtocolId,
    String? newProtocolId,
  }) async {
    final decision = await _actionPolicyService.evaluate(
      sourceProtocolId,
      SessionRevisionAction.createNewRevision,
    );
    _assertPolicyAllows(decision);

    final source = await _protocolBuilderService.loadProtocol(sourceProtocolId);
    _assertCanForkRevision(source);

    final lineageId = source.sessionLineageId?.trim();
    if (lineageId == null || lineageId.isEmpty) {
      throw SessionLineageStoreException(
        'Session revision $sourceProtocolId is missing session_lineage_id.',
      );
    }

    final nextRevisionNumber =
        (await _lineageStore.getMaxRevisionNumber(lineageId)) + 1;
    final resolvedProtocolId = newProtocolId?.trim().isNotEmpty == true
        ? newProtocolId!.trim()
        : SessionRevisionClone.revisionProtocolIdForNumber(
            sourceProtocolId: source.protocolId,
            revisionNumber: nextRevisionNumber,
          );

    final cloned = _revisionClone.cloneNewRevisionDraft(
      source: source,
      newProtocolId: resolvedProtocolId,
      sessionLineageId: lineageId,
      revisionNumber: nextRevisionNumber,
    );

    await _protocolBuilderService.saveDraft(cloned);

    await _lineageStore.assignRevisionLineage(
      protocolId: cloned.protocolId,
      sessionLineageId: lineageId,
      revisionNumber: nextRevisionNumber,
      lifecycleStatus: SessionRevisionLifecycleStatus.draft,
    );

    return CreateSessionRevisionResult(
      draft: cloned,
      sourceProtocolId: source.protocolId,
      sessionLineageId: lineageId,
      revisionNumber: nextRevisionNumber,
    );
  }

  Future<ProtocolDraft> publishRevision(ProtocolDraft draft) async {
    final decision = await _actionPolicyService.evaluate(
      draft.protocolId,
      SessionRevisionAction.publish,
    );
    _assertPolicyAllows(decision);

    if (draft.lifecycleStatus != SessionRevisionLifecycleStatus.draft) {
      throw SessionLineageStoreException(
        'Only draft session revisions can be published.',
      );
    }

    final result = await _protocolBuilderService.publishDraft(draft);
    final published = draft.copyWith(
      published: true,
      lifecycleStatus: SessionRevisionLifecycleStatus.published,
      publishedAt: DateTime.now().toUtc(),
    );

    await _lineageStore.updateRevisionLifecycle(
      protocolId: result.protocolId,
      lifecycleStatus: SessionRevisionLifecycleStatus.published,
      publishedAt: published.publishedAt,
    );

    return published;
  }

  Future<ProtocolDraft> archiveRevision(String protocolId) async {
    final decision = await _actionPolicyService.evaluate(
      protocolId,
      SessionRevisionAction.archive,
    );
    _assertPolicyAllows(decision);

    final draft = await _protocolBuilderService.loadProtocol(protocolId);
    if (draft.lifecycleStatus != SessionRevisionLifecycleStatus.published) {
      throw SessionLineageStoreException(
        'Only published session revisions can be archived.',
      );
    }

    final archivedAt = DateTime.now().toUtc();
    await _lineageStore.updateRevisionLifecycle(
      protocolId: protocolId,
      lifecycleStatus: SessionRevisionLifecycleStatus.archived,
      archivedAt: archivedAt,
    );

    return draft.copyWith(
      lifecycleStatus: SessionRevisionLifecycleStatus.archived,
      archivedAt: archivedAt,
      published: false,
    );
  }

  Future<void> deleteRevision(String protocolId) async {
    final decision = await _actionPolicyService.evaluate(
      protocolId,
      SessionRevisionAction.delete,
    );
    _assertPolicyAllows(decision);

    await _deleteStore.deleteRevision(protocolId);
  }

  void _assertCanForkRevision(ProtocolDraft source) {
    if (source.lifecycleStatus == SessionRevisionLifecycleStatus.draft) {
      throw SessionLineageStoreException(
        'Draft revision ${source.protocolId} is already editable in place.',
      );
    }
  }

  void _assertPolicyAllows(SessionRevisionActionDecision decision) {
    if (decision.allowed) return;

    throw SessionRevisionPolicyException(
      decision.userMessage,
      decision: decision,
    );
  }
}
