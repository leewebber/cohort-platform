import '../../../models/protocol_draft.dart';
import '../../../models/protocol_step_draft.dart';
import '../../../models/session_block.dart';
import '../../../models/training_content_vocabulary.dart';
import '../models/cohort_protocol_copy_destination.dart';
import 'protocol_draft_block_resolver.dart';

/// Deep-clones Cohort Protocol content into independent coach Session drafts.
class SessionCloneService {
  const SessionCloneService({
    ProtocolDraftBlockResolver? blockResolver,
  }) : _blockResolver = blockResolver ?? const ProtocolDraftBlockResolver();

  final ProtocolDraftBlockResolver _blockResolver;

  static const localCloneIdPrefix = 'local-copy-session-';

  static bool isLocalCloneDraftId(String protocolId) {
    return protocolId.trim().startsWith(localCloneIdPrefix);
  }

  static String newLocalCloneDraftId() {
    return '$localCloneIdPrefix${DateTime.now().microsecondsSinceEpoch}';
  }

  /// Creates an independent coach Session draft from an official Cohort Protocol.
  ProtocolDraft cloneCohortProtocolToSession({
    required ProtocolDraft source,
    required String newContentId,
    required String ownerId,
    required CohortProtocolCopyDestination destination,
    String? programmeVersionId,
  }) {
    final destinationScope = destination ==
            CohortProtocolCopyDestination.programmeOnly
        ? TrainingAuthoringScope.programmeOnly
        : TrainingAuthoringScope.coachPrivate;

    final copiedName = _copiedSessionName(source.name);
    final sourceBlocks = _blockResolver.resolveBlocks(source);
    final clonedBlocks = sourceBlocks
        .asMap()
        .entries
        .map(
          (entry) => entry.value.deepClone(position: entry.key + 1),
        )
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

    return ProtocolDraft(
      protocolId: newContentId,
      name: copiedName,
      blocks: clonedBlocks,
      steps: clonedSteps,
      published: destination == CohortProtocolCopyDestination.sessionLibrary,
      contentKind: TrainingContentKind.session,
      authoringScope: destinationScope,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      ownerId: ownerId,
      organisationId: null,
      programmeVersionId: destination == CohortProtocolCopyDestination.programmeOnly
          ? programmeVersionId
          : null,
      sourceContentId: source.protocolId,
      sourceContentKind: TrainingContentKind.cohortProtocol,
      sourceVersionId: null,
      primaryCapability: source.primaryCapability,
      secondaryCapability: source.secondaryCapability,
      sessionType: source.sessionType,
      sessionFormat: source.sessionFormat,
      durationMin: source.durationMin,
      durationCategory: source.durationCategory,
      physiologicalDemand: source.physiologicalDemand,
      recoveryCost: source.recoveryCost,
      technicalComplexity: source.technicalComplexity,
      environment: source.environment,
      requiredEquipment: source.requiredEquipment,
      optionalEquipment: source.optionalEquipment,
      suitableFor: source.suitableFor,
      adaptability: source.adaptability,
      runningRequired: source.runningRequired,
      runningReplaceable: source.runningReplaceable,
      hotelFriendly: source.hotelFriendly,
      indoorFriendly: source.indoorFriendly,
      noiseFriendly: source.noiseFriendly,
      coachingNotes: source.coachingNotes,
      purpose: source.purpose,
    );
  }

  ProtocolStepDraft _cloneStep(ProtocolStepDraft source, {required int index}) {
    return ProtocolStepDraft(
      localId:
          'step-clone-${DateTime.now().microsecondsSinceEpoch}-$index',
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

  String _copiedSessionName(String sourceName) {
    final trimmed = sourceName.trim();
    if (trimmed.isEmpty) return 'Custom Session';
    return '$trimmed — Custom';
  }
}
