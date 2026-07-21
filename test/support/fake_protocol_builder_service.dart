import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/session_builder/services/protocol_draft_block_resolver.dart';
import 'package:cohort_platform/models/protocol_builder_save_result.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';

/// In-memory [ProtocolBuilderService] stand-in for session revision tests.
class FakeProtocolBuilderService extends ProtocolBuilderService {
  FakeProtocolBuilderService({
    ProtocolDraftBlockResolver? blockResolver,
  }) : super(blockResolver: blockResolver);

  final Map<String, ProtocolDraft> draftsById = <String, ProtocolDraft>{};
  final List<ProtocolDraft> saveDraftCalls = <ProtocolDraft>[];
  final List<ProtocolDraft> publishDraftCalls = <ProtocolDraft>[];

  void seed(ProtocolDraft draft) {
    draftsById[draft.protocolId] = draft;
  }

  @override
  Future<ProtocolDraft> loadProtocol(String protocolId) async {
    final draft = draftsById[protocolId.trim()];
    if (draft == null) {
      throw ProtocolBuilderException(
        'Protocol $protocolId could not be found.',
      );
    }
    return draft;
  }

  @override
  Future<ProtocolBuilderSaveResult> saveDraft(ProtocolDraft draft) async {
    final existing = draftsById[draft.protocolId];
    if (existing != null &&
        (existing.lifecycleStatus == SessionRevisionLifecycleStatus.published ||
            existing.lifecycleStatus ==
                SessionRevisionLifecycleStatus.archived)) {
      throw ProtocolBuilderException(
        'Published session revisions cannot be edited in place. '
        'Create a new revision instead.',
      );
    }

    saveDraftCalls.add(draft);
    draftsById[draft.protocolId] = draft;
    return ProtocolBuilderSaveResult.draft(
      protocolId: draft.protocolId,
      created: !draftsById.containsKey(draft.protocolId),
      stepCount: draft.steps.length,
    );
  }

  @override
  Future<ProtocolBuilderSaveResult> publishDraft(ProtocolDraft draft) async {
    publishDraftCalls.add(draft);
    final published = draft.copyWith(
      published: true,
      lifecycleStatus: SessionRevisionLifecycleStatus.published,
      publishedAt: DateTime.now().toUtc(),
    );
    draftsById[draft.protocolId] = published;
    return ProtocolBuilderSaveResult.published(
      protocolId: draft.protocolId,
      created: false,
      stepCount: draft.steps.length,
    );
  }
}
