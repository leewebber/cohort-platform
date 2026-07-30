import '../../../models/protocol_draft.dart';
import '../../../models/protocol_step_draft.dart';
import '../../../models/training_content_vocabulary.dart';
import '../models/cohort_protocol_copy_destination.dart';
import 'protocol_draft_block_resolver.dart';

/// Deep-clones Cohort Protocol content into independent coach Session drafts.
class SessionCloneService {
  const SessionCloneService({ProtocolDraftBlockResolver? blockResolver})
    : _blockResolver = blockResolver ?? const ProtocolDraftBlockResolver();

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
    return _cloneToSession(
      source: source,
      newContentId: newContentId,
      ownerId: ownerId,
      destination: destination,
      programmeVersionId: programmeVersionId,
      sourceContentKind: TrainingContentKind.cohortProtocol,
      nameSuffix: ' — Custom',
    );
  }

  /// Creates an independent programme Session draft from a session template.
  ///
  /// Templates are never attached by live reference — always copy-on-use.
  ProtocolDraft cloneTemplateToSession({
    required ProtocolDraft source,
    required String newContentId,
    required String ownerId,
    CohortProtocolCopyDestination destination =
        CohortProtocolCopyDestination.programmeOnly,
    String? programmeVersionId,
  }) {
    if (destination == CohortProtocolCopyDestination.programmeOnly &&
        (programmeVersionId == null || programmeVersionId.trim().isEmpty)) {
      throw ArgumentError(
        'programmeVersionId is required when cloning a template for a programme.',
      );
    }

    return _cloneToSession(
      source: source,
      newContentId: newContentId,
      ownerId: ownerId,
      destination: destination,
      programmeVersionId: programmeVersionId,
      sourceContentKind: TrainingContentKind.sessionTemplate,
      nameSuffix: '',
    );
  }

  ProtocolDraft _cloneToSession({
    required ProtocolDraft source,
    required String newContentId,
    required String ownerId,
    required CohortProtocolCopyDestination destination,
    required TrainingContentKind sourceContentKind,
    required String nameSuffix,
    String? programmeVersionId,
  }) {
    final trimmedNewId = newContentId.trim();
    final trimmedSourceId = source.protocolId.trim();
    if (trimmedNewId.isEmpty || trimmedNewId == trimmedSourceId) {
      throw ArgumentError(
        'Clone requires a new content identity distinct from the source.',
      );
    }

    final destinationScope =
        destination == CohortProtocolCopyDestination.programmeOnly
        ? TrainingAuthoringScope.programmeOnly
        : TrainingAuthoringScope.coachPrivate;

    final copiedName = nameSuffix.isEmpty
        ? source.name.trim().isEmpty
              ? 'Session from template'
              : source.name.trim()
        : _copiedSessionName(source.name);
    final sourceBlocks = _blockResolver.resolveBlocks(source);
    final clonedBlocks = sourceBlocks
        .asMap()
        .entries
        .map((entry) => entry.value.deepClone(position: entry.key + 1))
        .toList(growable: false);

    final clonedSteps = source.steps
        .asMap()
        .entries
        .map((entry) => _cloneStep(entry.value, index: entry.key))
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
      programmeVersionId:
          destination == CohortProtocolCopyDestination.programmeOnly
          ? programmeVersionId
          : null,
      sourceContentId: source.protocolId,
      sourceContentKind: sourceContentKind,
      sourceVersionId: null,
      primaryCapability: source.primaryCapability,
      secondaryCapability: source.secondaryCapability,
      sessionType: source.sessionType,
      sessionFormat: source.sessionFormat?.trim().isNotEmpty == true
          ? source.sessionFormat
          : source.sessionType,
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
      primarySessionIntent: source.primarySessionIntent,
      secondarySessionIntents: source.secondarySessionIntents,
      minimumViableDurationMin: source.minimumViableDurationMin,
    );
  }

  ProtocolStepDraft _cloneStep(ProtocolStepDraft source, {required int index}) {
    return ProtocolStepDraft(
      localId: 'step-clone-${DateTime.now().microsecondsSinceEpoch}-$index',
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
