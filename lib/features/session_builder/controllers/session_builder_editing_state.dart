import '../../../models/exercise.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/protocol_metadata_vocabulary.dart';
import '../../../models/protocol_step_draft.dart';
import '../../../models/training_content_vocabulary.dart';

/// In-memory editing state for [SessionBuilderView] — builds [ProtocolDraft] snapshots.
class SessionBuilderEditingState {
  SessionBuilderEditingState({required ProtocolDraft draft}) {
    applyDraft(draft);
  }

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
  List<ProtocolStepDraft> steps = [];
  final Set<String> customisedTitles = {};

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
    steps = List<ProtocolStepDraft>.from(draft.steps);
    customisedTitles
      ..clear()
      ..addAll(draft.steps.map((step) => step.localId));
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
    return ProtocolDraft(
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
      steps: steps,
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
    );
  }

  String newLocalId() {
    return 'step-${DateTime.now().microsecondsSinceEpoch}';
  }

  void addStep() {
    final localId = newLocalId();
    steps = [
      ...steps,
      ProtocolStepDraft(
        localId: localId,
        stepOrder: steps.length + 1,
        title: 'New Step',
        section: 'Main Set',
        stepType: 'Exercise',
        displayStyle: 'exercise',
      ),
    ];
  }

  void updateStep(ProtocolStepDraft updated) {
    steps = steps
        .map((step) => step.localId == updated.localId ? updated : step)
        .toList();
  }

  void deleteStep(String localId) {
    steps = steps.where((step) => step.localId != localId).toList();
    customisedTitles.remove(localId);
    renumberSteps();
  }

  void moveStep(String localId, int direction) {
    final index = steps.indexWhere((step) => step.localId == localId);
    if (index < 0) return;

    final targetIndex = index + direction;
    if (targetIndex < 0 || targetIndex >= steps.length) return;

    final reordered = List<ProtocolStepDraft>.from(steps);
    final item = reordered.removeAt(index);
    reordered.insert(targetIndex, item);
    steps = reordered;
    renumberSteps();
  }

  void renumberSteps() {
    steps = [
      for (var i = 0; i < steps.length; i++) steps[i].copyWith(stepOrder: i + 1),
    ];
  }

  void markTitleCustomised(String localId) {
    customisedTitles.add(localId);
  }

  void onExerciseSelected({
    required String localId,
    required Exercise? exercise,
    required String currentTitle,
  }) {
    final index = steps.indexWhere((step) => step.localId == localId);
    if (index < 0) return;

    final step = steps[index];
    final titleCustomised = customisedTitles.contains(localId);
    final nextTitle = exercise == null
        ? step.title
        : titleCustomised
            ? currentTitle
            : exercise.name;

    updateStep(
      step.copyWith(
        exerciseId: exercise?.exerciseId,
        title: nextTitle,
      ),
    );
  }
}
