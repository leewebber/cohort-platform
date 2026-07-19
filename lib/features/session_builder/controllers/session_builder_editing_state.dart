import '../../../models/exercise.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/protocol_metadata_vocabulary.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_exercise_link.dart';
import '../../../models/session_block_type.dart';
import '../../../models/timer_configuration.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../../models/workout_format.dart';
import '../services/protocol_draft_block_resolver.dart';

/// In-memory editing state for [SessionBuilderView] — builds [ProtocolDraft] snapshots.
class SessionBuilderEditingState {
  SessionBuilderEditingState({
    required ProtocolDraft draft,
    ProtocolDraftBlockResolver? blockResolver,
  }) : _blockResolver = blockResolver ?? const ProtocolDraftBlockResolver() {
    applyDraft(draft);
  }

  final ProtocolDraftBlockResolver _blockResolver;

  String protocolId = '';
  String name = '';
  String? sessionFormat;
  String? sessionType;
  String? primaryCapability;
  String? secondaryCapability;
  String? physiologicalDemand;
  String? recoveryCost;
  String? technicalComplexity;
  String? environment;
  Set<String> selectedRequiredEquipment = {};
  Set<String> selectedOptionalEquipment = {};
  Set<String> selectedSuitableFor = {};
  int? durationMin;
  List<SessionBlock> blocks = [];

  TrainingContentKind contentKind = TrainingContentKind.cohortProtocol;
  TrainingAuthoringScope authoringScope = TrainingAuthoringScope.cohortGlobal;
  TrainingEndorsementStatus endorsementStatus =
      TrainingEndorsementStatus.cohortEndorsed;
  String? ownerId;
  String? organisationId;
  String? programmeVersionId;
  String? sourceContentId;
  TrainingContentKind? sourceContentKind;
  String? sourceVersionId;
  bool published = false;

  void applyDraft(ProtocolDraft draft) {
    protocolId = draft.protocolId;
    name = draft.name;
    sessionFormat = draft.sessionFormat;
    sessionType = draft.sessionType;
    primaryCapability = draft.primaryCapability;
    secondaryCapability = draft.secondaryCapability;
    physiologicalDemand = draft.physiologicalDemand;
    recoveryCost = draft.recoveryCost;
    technicalComplexity = draft.technicalComplexity;
    environment = draft.environment;
    durationMin = draft.durationMin;
    selectedRequiredEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
      draft.requiredEquipment,
    );
    selectedOptionalEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
      draft.optionalEquipment,
    );
    selectedSuitableFor = ProtocolMetadataVocabulary.parseCommaSeparated(
      draft.suitableFor,
    );
    blocks = List<SessionBlock>.from(_blockResolver.resolveBlocks(draft));
    contentKind = draft.contentKind;
    authoringScope = draft.authoringScope;
    endorsementStatus = draft.endorsementStatus;
    ownerId = draft.ownerId;
    organisationId = draft.organisationId;
    programmeVersionId = draft.programmeVersionId;
    sourceContentId = draft.sourceContentId;
    sourceContentKind = draft.sourceContentKind;
    sourceVersionId = draft.sourceVersionId;
    published = draft.published;
  }

  ProtocolDraft buildDraft() {
    final normalizedBlocks = _renumberedBlocks();
    return _blockResolver.withSyncedStepsFromBlocks(
      ProtocolDraft(
        protocolId: protocolId.trim(),
        name: name.trim(),
        sessionFormat: sessionFormat,
        sessionType: sessionType,
        primaryCapability: primaryCapability,
        secondaryCapability: secondaryCapability,
        durationMin: durationMin,
        physiologicalDemand: physiologicalDemand,
        recoveryCost: recoveryCost,
        technicalComplexity: technicalComplexity,
        environment: environment,
        requiredEquipment: ProtocolMetadataVocabulary.formatCommaSeparated(
          selectedRequiredEquipment,
          ProtocolMetadataVocabulary.equipment,
        ),
        optionalEquipment: ProtocolMetadataVocabulary.formatCommaSeparated(
          selectedOptionalEquipment,
          ProtocolMetadataVocabulary.equipment,
        ),
        suitableFor: ProtocolMetadataVocabulary.formatCommaSeparated(
          selectedSuitableFor,
          ProtocolMetadataVocabulary.suitableFor,
        ),
        blocks: normalizedBlocks,
        steps: const [],
        published: published,
        contentKind: contentKind,
        authoringScope: authoringScope,
        endorsementStatus: endorsementStatus,
        ownerId: ownerId,
        organisationId: organisationId,
        programmeVersionId: programmeVersionId,
        sourceContentId: sourceContentId,
        sourceContentKind: sourceContentKind,
        sourceVersionId: sourceVersionId,
      ),
    );
  }

  void addBlock(SessionBlockType blockType) {
    blocks = [
      ...blocks,
      SessionBlock.create(
        blockType: blockType,
        position: blocks.length + 1,
      ),
    ];
  }

  void updateBlock(SessionBlock updated) {
    blocks = blocks
        .map((block) => block.localId == updated.localId ? updated : block)
        .toList();
  }

  void deleteBlock(String localId) {
    blocks = blocks.where((block) => block.localId != localId).toList();
    renumberBlocks();
  }

  void duplicateBlock(String localId) {
    final index = blocks.indexWhere((block) => block.localId == localId);
    if (index < 0) return;

    final clone = blocks[index].deepClone(
      position: index + 2,
      titleSuffix: blocks[index].title.trim().endsWith('Copy') ? null : ' Copy',
    );

    final reordered = List<SessionBlock>.from(blocks);
    reordered.insert(index + 1, clone);
    blocks = reordered;
    renumberBlocks();
  }

  void moveBlock(String localId, int direction) {
    final index = blocks.indexWhere((block) => block.localId == localId);
    if (index < 0) return;

    final targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= blocks.length) return;

    final reordered = List<SessionBlock>.from(blocks);
    final item = reordered.removeAt(index);
    reordered.insert(targetIndex, item);
    blocks = reordered;
    renumberBlocks();
  }

  void renumberBlocks() {
    blocks = [
      for (var i = 0; i < blocks.length; i++)
        blocks[i].copyWith(position: i + 1),
    ];
  }

  void updateWorkoutFormat(String localId, WorkoutFormat format) {
    final index = blocks.indexWhere((block) => block.localId == localId);
    if (index < 0) return;

    final block = blocks[index];
    updateBlock(
      block.copyWith(
        workoutFormat: format,
        timerConfiguration: TimerConfiguration.normalizedForFormat(
          format,
          block.timerConfiguration,
        ),
      ),
    );
  }

  void updateTimerConfiguration(
    String localId,
    TimerConfiguration configuration,
  ) {
    final index = blocks.indexWhere((block) => block.localId == localId);
    if (index < 0) return;

    updateBlock(
      blocks[index].copyWith(timerConfiguration: configuration),
    );
  }

  void addExerciseLink(String localId, Exercise exercise) {
    final index = blocks.indexWhere((block) => block.localId == localId);
    if (index < 0) return;

    final block = blocks[index];
    if (block.linkedExercises.any((link) => link.exerciseId == exercise.exerciseId)) {
      return;
    }

    final nextPosition = block.linkedExercises.length + 1;
    updateBlock(
      block.copyWith(
        linkedExercises: [
          ...block.linkedExercises,
          SessionBlockExerciseLink(
            localId: 'link-${DateTime.now().microsecondsSinceEpoch}',
            exerciseId: exercise.exerciseId,
            position: nextPosition,
          ),
        ],
      ),
    );
  }

  void removeExerciseLink(String blockLocalId, String linkLocalId) {
    final index = blocks.indexWhere((block) => block.localId == blockLocalId);
    if (index < 0) return;

    final block = blocks[index];
    final filtered = block.linkedExercises
        .where((link) => link.localId != linkLocalId)
        .toList(growable: false);

    updateBlock(
      block.copyWith(
        linkedExercises: [
          for (var i = 0; i < filtered.length; i++)
            filtered[i].copyWith(position: i + 1),
        ],
      ),
    );
  }

  void moveExerciseLink(String blockLocalId, String linkLocalId, int direction) {
    final blockIndex = blocks.indexWhere((block) => block.localId == blockLocalId);
    if (blockIndex < 0) return;

    final block = blocks[blockIndex];
    final linkIndex =
        block.linkedExercises.indexWhere((link) => link.localId == linkLocalId);
    if (linkIndex < 0) return;

    final targetIndex = linkIndex + direction;
    if (targetIndex < 0 || targetIndex >= block.linkedExercises.length) return;

    final reordered = List<SessionBlockExerciseLink>.from(block.linkedExercises);
    final item = reordered.removeAt(linkIndex);
    reordered.insert(targetIndex, item);

    updateBlock(
      block.copyWith(
        linkedExercises: [
          for (var i = 0; i < reordered.length; i++)
            reordered[i].copyWith(position: i + 1),
        ],
      ),
    );
  }

  void updateExerciseLinkLabel(
    String blockLocalId,
    String linkLocalId,
    String? label,
  ) {
    final blockIndex = blocks.indexWhere((block) => block.localId == blockLocalId);
    if (blockIndex < 0) return;

    final block = blocks[blockIndex];
    updateBlock(
      block.copyWith(
        linkedExercises: block.linkedExercises
            .map(
              (link) => link.localId == linkLocalId
                  ? link.copyWith(displayLabelOverride: label)
                  : link,
            )
            .toList(),
      ),
    );
  }

  List<SessionBlock> _renumberedBlocks() {
    renumberBlocks();
    return List<SessionBlock>.from(blocks);
  }
}
