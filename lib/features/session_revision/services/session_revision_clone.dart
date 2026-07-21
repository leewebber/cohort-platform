import '../../../models/protocol_draft.dart';
import '../../../models/protocol_step_draft.dart';
import '../../../models/session_revision_vocabulary.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../session_builder/services/protocol_draft_block_resolver.dart';

/// Deep-clones a Session Revision into a new draft revision within the same lineage.
class SessionRevisionClone {
  const SessionRevisionClone({
    ProtocolDraftBlockResolver? blockResolver,
  }) : _blockResolver = blockResolver ?? const ProtocolDraftBlockResolver();

  final ProtocolDraftBlockResolver _blockResolver;

  static const revisionProtocolIdPrefix = 'session-rev-';

  static String newRevisionProtocolId() {
    return '$revisionProtocolIdPrefix${DateTime.now().microsecondsSinceEpoch}';
  }

  static String revisionProtocolIdForNumber({
    required String sourceProtocolId,
    required int revisionNumber,
  }) {
    return '$sourceProtocolId-rev-$revisionNumber';
  }

  ProtocolDraft cloneNewRevisionDraft({
    required ProtocolDraft source,
    required String newProtocolId,
    required String sessionLineageId,
    required int revisionNumber,
  }) {
    final sourceBlocks = _blockResolver.resolveBlocks(source);
    final clonedBlocks = sourceBlocks
        .asMap()
        .entries
        .map((entry) => entry.value.deepClone(position: entry.key + 1))
        .toList(growable: false);

    final clonedSteps = source.steps
        .asMap()
        .entries
        .map(
          (entry) => _cloneStep(
            entry.value,
            index: entry.key,
          ),
        )
        .toList(growable: false);

    return source.copyWith(
      protocolId: newProtocolId,
      steps: clonedSteps,
      blocks: clonedBlocks,
      published: false,
      sessionLineageId: sessionLineageId,
      revisionNumber: revisionNumber,
      lifecycleStatus: SessionRevisionLifecycleStatus.draft,
      clearPublishedAt: true,
      clearArchivedAt: true,
      sourceContentId: source.protocolId,
      sourceContentKind: source.contentKind,
      sourceVersionId: source.revisionNumber.toString(),
    );
  }

  ProtocolStepDraft _cloneStep(ProtocolStepDraft source, {required int index}) {
    return ProtocolStepDraft(
      localId: 'step-rev-${DateTime.now().microsecondsSinceEpoch}-$index',
      stepOrder: source.stepOrder,
      title: source.title,
      persistedId: null,
      section: source.section,
      stepType: source.stepType,
      displayStyle: source.displayStyle,
      exerciseId: source.exerciseId,
      notes: source.notes,
      sets: source.sets,
      reps: source.reps,
      distance: source.distance,
      duration: source.duration,
      rest: source.rest,
      tempo: source.tempo,
      load: source.load,
    );
  }
}
