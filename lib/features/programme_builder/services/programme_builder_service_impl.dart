import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_store_exception.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_lineage.dart';
import '../../../models/programme_vocabulary.dart';
import '../../programme/models/programme_catalog_entry.dart';
import '../../programme/services/programme_catalog_entry_mapper.dart';
import '../diagnostics/programme_create_diagnostics.dart';
import '../models/programme_partial_creation_state.dart';
import '../models/programme_builder_document.dart';
import '../models/programme_builder_operation_result.dart';
import '../models/programme_seed_template.dart';
import '../models/programme_version_draft_metadata.dart';
import 'programme_builder_compiler.dart';
import 'programme_builder_edit_operations.dart';
import 'programme_builder_service.dart';
import 'programme_builder_validation_service.dart';
import 'programme_seed_template_builder.dart';

/// Programme Builder implementation for catalogue and editor workflows.
class ProgrammeBuilderServiceImpl implements ProgrammeBuilderService {
  ProgrammeBuilderServiceImpl({
    required ProgrammeVersionStore versionStore,
    required ProgrammeAssignmentStore assignmentStore,
    required ProgrammeBuilderValidationService validationService,
    ProgrammeBuilderCompiler compiler = const ProgrammeBuilderCompiler(),
    ProgrammeSeedTemplateBuilder seedTemplateBuilder =
        const ProgrammeSeedTemplateBuilder(),
    ProgrammeBuilderEditOperations editOperations =
        const ProgrammeBuilderEditOperations(),
  })  : _versionStore = versionStore,
        _assignmentStore = assignmentStore,
        _validationService = validationService,
        _compiler = compiler,
        _seedTemplateBuilder = seedTemplateBuilder,
        _editOperations = editOperations;

  final ProgrammeVersionStore _versionStore;
  final ProgrammeAssignmentStore _assignmentStore;
  final ProgrammeBuilderValidationService _validationService;
  final ProgrammeBuilderCompiler _compiler;
  final ProgrammeSeedTemplateBuilder _seedTemplateBuilder;
  final ProgrammeBuilderEditOperations _editOperations;

  @override
  Future<ProgrammeBuilderOperationResult> createDraftProgramme({
    required String coachId,
    required ProgrammeVersionDraftMetadata seedMetadata,
    ProgrammeSeedTemplate seedTemplate = ProgrammeSeedTemplate.empty,
  }) async {
    ProgrammeCreateDiagnostics.log('service createDraftProgramme start');
    ProgrammeCreateDiagnostics.log('coachId=$coachId');
    ProgrammeCreateDiagnostics.log('lineage=${seedMetadata.lineageCode}');
    ProgrammeCreateDiagnostics.log('seedTemplate=${seedTemplate.name}');

    if (!_compiler.isValidLineageCode(seedMetadata.lineageCode)) {
      ProgrammeCreateDiagnostics.log('result status=validationFailed (lineage code)');
      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.validationFailed,
        validation: _validationService.validate(
          ProgrammeBuilderDocument.clean(
            metadata: seedMetadata,
            template: _seedTemplateBuilder.build(seedTemplate),
          ),
        ),
      );
    }

    final existingLineage =
        await _versionStore.getLineageByCode(seedMetadata.lineageCode);
    if (existingLineage != null) {
      ProgrammeCreateDiagnostics.log('result status=storeFailed (duplicate lineage)');
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
        warnings: ['Lineage code already exists. Choose a unique code.'],
      );
    }

    String? createdLineageId;
    String? createdVersionId;

    try {
      ProgrammeCreateDiagnostics.log('insert lineage start');
      final lineage = await _versionStore.insertLineage(
        ProgrammeLineage(
          id: '',
          code: seedMetadata.lineageCode.trim(),
          createdBy: coachId,
        ),
      );
      createdLineageId = lineage.id;
      ProgrammeCreateDiagnostics.log('insert lineage success id=${lineage.id}');

      final versionRow = _compiler.toVersionRow(
        seedMetadata.copyWith(
          lineageId: lineage.id,
          lineageCode: lineage.code,
          versionNumber: 1,
          lifecycleStatus: ProgrammeLifecycleStatus.draft,
          ownerType: ProgrammeOwnerType.coach,
          ownerId: coachId,
        ),
      );

      ProgrammeCreateDiagnostics.log('insert version start');
      final savedVersion = await _versionStore.saveDraftVersion(versionRow);
      createdVersionId = savedVersion.id;
      ProgrammeCreateDiagnostics.log('insert version success id=${savedVersion.id}');

      final template = _compiler.assignLocalIds(
        _seedTemplateBuilder.build(seedTemplate),
      );
      final document = ProgrammeBuilderDocument.clean(
        metadata: seedMetadata.copyWith(
          versionId: savedVersion.id,
          lineageId: lineage.id,
          lineageCode: lineage.code,
          versionNumber: 1,
          ownerId: coachId,
          updatedAt: savedVersion.updatedAt,
        ),
        template: template,
        lastSavedAt: DateTime.now().toUtc(),
      );

      final tree = _compiler.toTemplateTree(document);
      ProgrammeCreateDiagnostics.log('save template tree start');
      try {
        await _versionStore.saveTemplateTree(
          version: savedVersion,
          tree: tree,
        );
      } on ProgrammeStoreException catch (error, stackTrace) {
        ProgrammeCreateDiagnostics.logException(
          error,
          stackTrace: stackTrace,
          stage: 'saveTemplateTree',
        );
        final partialCreation = ProgrammePartialCreationState(
          lineageId: lineage.id,
          versionId: savedVersion.id,
          failureStage: error.operation ?? 'saveTemplateTree',
        );
        ProgrammeCreateDiagnostics.logPartialCreation(partialCreation);
        final warnings = [
          ...ProgrammeCreateDiagnostics.warningsFromStoreException(error),
          ...partialCreation.toDiagnosticLines(),
        ];
        return ProgrammeBuilderOperationResult(
          status: ProgrammeBuilderOperationStatus.storeFailed,
          warnings: warnings,
          partialCreation: partialCreation,
        );
      }
      ProgrammeCreateDiagnostics.log('save template tree success');

      final result = ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.created,
        document: document.markSaved(savedAt: DateTime.now().toUtc()),
      );
      ProgrammeCreateDiagnostics.logOperationResult(result);
      return result;
    } on ProgrammeStoreException catch (error, stackTrace) {
      ProgrammeCreateDiagnostics.logException(
        error,
        stackTrace: stackTrace,
        stage: 'createDraftProgramme',
      );
      final partialCreation = (createdLineageId != null || createdVersionId != null)
          ? ProgrammePartialCreationState(
              lineageId: createdLineageId,
              versionId: createdVersionId,
              failureStage: error.operation ?? 'createDraftProgramme',
            )
          : null;
      if (partialCreation != null) {
        ProgrammeCreateDiagnostics.logPartialCreation(partialCreation);
      }
      final warnings = [
        ...ProgrammeCreateDiagnostics.warningsFromStoreException(error),
        if (partialCreation != null) ...partialCreation.toDiagnosticLines(),
      ];
      ProgrammeCreateDiagnostics.log('warnings=${warnings.join(' | ')}');
      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
        warnings: warnings,
        partialCreation: partialCreation,
      );
    } catch (error, stackTrace) {
      ProgrammeCreateDiagnostics.logException(
        error,
        stackTrace: stackTrace,
        stage: 'createDraftProgramme(unexpected)',
      );
      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
        warnings: ['message=$error'],
      );
    }
  }

  @override
  Future<ProgrammeBuilderDocument> loadDocument({
    required String versionId,
  }) async {
    final tree = await _versionStore.loadTemplateTree(versionId);
    if (tree == null) {
      throw ProgrammeStoreException('Programme version not found');
    }

    final lineage = await _versionStore.getLineageById(
      tree.template.version.lineageId,
    );

    return _compiler.fromTemplateTree(
      tree: tree,
      metadata: ProgrammeVersionDraftMetadata(
        versionId: tree.template.version.id,
        lineageId: tree.template.version.lineageId,
        lineageCode: lineage?.code ?? '',
        versionNumber: tree.template.version.versionNumber,
        lifecycleStatus: tree.template.version.lifecycleStatus,
        libraryScope: tree.template.version.libraryScope,
        ownerType: tree.template.version.ownerType,
        ownerId: tree.template.version.ownerId,
        name: tree.template.version.name,
        description: tree.template.version.description,
        durationWeeks: tree.template.version.durationWeeks,
        targetAthlete: tree.template.version.targetAthlete,
        difficulty: tree.template.version.difficulty,
        primaryGoal: tree.template.version.primaryGoal,
        equipmentRequirements: tree.template.version.equipmentRequirements,
        sessionsPerWeek: tree.template.version.sessionsPerWeek,
        updatedAt: tree.template.version.updatedAt,
      ),
      lastSavedAt: tree.template.version.updatedAt,
    );
  }

  @override
  Future<ProgrammeBuilderOperationResult> saveDocument(
    ProgrammeBuilderDocument document,
  ) async {
    if (!document.isEditable) {
      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.notEditable,
        document: document,
      );
    }

    try {
      final version = _compiler.toVersionRow(document.metadata);
      final savedVersion = await _versionStore.saveDraftVersion(version);
      final tree = _compiler.toTemplateTree(document);
      await _versionStore.saveTemplateTree(
        version: savedVersion,
        tree: tree,
      );

      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.saved,
        document: document.markSaved(savedAt: DateTime.now().toUtc()),
      );
    } on ProgrammeStoreException {
      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
        document: document,
      );
    }
  }

  @override
  Future<List<ProgrammeCatalogEntry>> listCoachDrafts({
    required String coachId,
  }) async {
    final entries = await _versionStore.listCatalogueVersions(
      ProgrammeCatalogueQuery(
        ownerType: ProgrammeOwnerType.coach,
        ownerId: coachId,
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
      ),
    );

    final enriched = <ProgrammeCatalogEntry>[];
    for (final entry in entries) {
      if (entry.lifecycleStatus != ProgrammeLifecycleStatus.draft) continue;

      var hasBlockingValidationErrors = false;
      try {
        final document = await loadDocument(versionId: entry.versionId);
        final validation = _validationService.validate(document);
        hasBlockingValidationErrors = validation.blockingIssueCount > 0;
      } catch (_) {
        hasBlockingValidationErrors = true;
      }

      enriched.add(
        entry.copyWith(
          hasBlockingValidationErrors: hasBlockingValidationErrors,
          ownerDisplayLabel: programmeCatalogOwnerDisplayLabel(
            entry: entry,
            coachId: coachId,
          ),
        ),
      );
    }

    return enriched;
  }

  @override
  Future<ProgrammeBuilderOperationResult> duplicateProgramme({
    required String sourceVersionId,
    required String coachId,
    required String newLineageCode,
    required String newProgrammeName,
  }) async {
    if (!_compiler.isValidLineageCode(newLineageCode)) {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.validationFailed,
      );
    }

    final existingLineage = await _versionStore.getLineageByCode(newLineageCode);
    if (existingLineage != null) {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
        warnings: ['Lineage code already exists.'],
      );
    }

    try {
      final sourceDocument = await loadDocument(versionId: sourceVersionId);
      final lineage = await _versionStore.insertLineage(
        ProgrammeLineage(
          id: '',
          code: newLineageCode.trim(),
          createdBy: coachId,
        ),
      );

      final metadata = sourceDocument.metadata.copyWith(
        versionId: null,
        lineageId: lineage.id,
        lineageCode: lineage.code,
        versionNumber: 1,
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
        ownerType: ProgrammeOwnerType.coach,
        ownerId: coachId,
        name: newProgrammeName.trim(),
      );

      final versionRow = _compiler.toVersionRow(metadata);
      final savedVersion = await _versionStore.saveDraftVersion(versionRow);
      final document = ProgrammeBuilderDocument.clean(
        metadata: metadata.copyWith(versionId: savedVersion.id),
        template: sourceDocument.template,
        lastSavedAt: DateTime.now().toUtc(),
      );

      await _versionStore.saveTemplateTree(
        version: savedVersion,
        tree: _compiler.toTemplateTree(document),
      );

      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.duplicated,
        document: document,
        sourceVersionId: sourceVersionId,
        newLineageCode: lineage.code,
      );
    } on ProgrammeStoreException {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
      );
    }
  }

  @override
  Future<ProgrammeBuilderOperationResult> deleteDraft({
    required String versionId,
    required String coachId,
  }) async {
    final version = await _versionStore.getVersionById(versionId);
    if (version == null) {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
      );
    }

    if (version.lifecycleStatus != ProgrammeLifecycleStatus.draft) {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.notEditable,
      );
    }

    if (version.ownerId != coachId) {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.notEditable,
      );
    }

    if (version.publishedAt != null) {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.notEditable,
      );
    }

    final assignmentCount =
        await _assignmentStore.countAssignmentsForVersion(versionId);
    if (assignmentCount > 0) {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.notEditable,
        warnings: ['Draft is referenced by athlete assignments.'],
      );
    }

    try {
      await _versionStore.deleteDraftVersion(versionId);
      return ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.deleted,
        sourceVersionId: versionId,
      );
    } on ProgrammeStoreException {
      return const ProgrammeBuilderOperationResult(
        status: ProgrammeBuilderOperationStatus.storeFailed,
      );
    }
  }

  @override
  Future<ProgrammeBuilderEditResult> addWeek(ProgrammeBuilderDocument document) {
    return _edit(document, _editOperations.addWeek(document));
  }

  @override
  Future<ProgrammeBuilderEditResult> duplicateWeek(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  }) {
    return _edit(
      document,
      _editOperations.duplicateWeek(document, weekLocalId: weekLocalId),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> removeWeek(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  }) {
    return _edit(
      document,
      _editOperations.removeWeek(document, weekLocalId: weekLocalId),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> addDay(
    ProgrammeBuilderDocument document, {
    required String weekLocalId,
  }) {
    return _edit(
      document,
      _editOperations.addDay(document, weekLocalId: weekLocalId),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> removeDay(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
  }) {
    return _edit(
      document,
      _editOperations.removeDay(document, dayLocalId: dayLocalId),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> updateDayMetadata(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
    String? title,
    ProgrammeIntent? intent,
    bool clearTitle = false,
    bool clearIntent = false,
  }) {
    return _edit(
      document,
      _editOperations.updateDayMetadata(
        document,
        dayLocalId: dayLocalId,
        title: title,
        intent: intent,
        clearTitle: clearTitle,
        clearIntent: clearIntent,
      ),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> setDayType(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
    required ProgrammeDayType dayType,
  }) {
    return _edit(
      document,
      _editOperations.setDayType(
        document,
        dayLocalId: dayLocalId,
        dayType: dayType,
      ),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> addSlot(
    ProgrammeBuilderDocument document, {
    required String dayLocalId,
  }) {
    return _edit(
      document,
      _editOperations.addSlot(document, dayLocalId: dayLocalId),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> removeSlot(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
  }) {
    return _edit(
      document,
      _editOperations.removeSlot(document, slotLocalId: slotLocalId),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> assignProtocol(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
    required String protocolId,
    String? displayTitle,
  }) {
    return _edit(
      document,
      _editOperations.assignProtocol(
        document,
        slotLocalId: slotLocalId,
        protocolId: protocolId,
        displayTitle: displayTitle,
      ),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> clearProtocol(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
  }) {
    return _edit(
      document,
      _editOperations.clearProtocol(document, slotLocalId: slotLocalId),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> updateSlotMetadata(
    ProgrammeBuilderDocument document, {
    required String slotLocalId,
    String? displayTitle,
    ProgrammeSessionTimeOfDay? timeOfDay,
    bool? isOptional,
    ProgrammeSessionCompletionExpectation? completionExpectation,
    String? coachNote,
    String? athleteNote,
    bool clearDisplayTitle = false,
    bool clearCoachNote = false,
    bool clearAthleteNote = false,
  }) {
    return _edit(
      document,
      _editOperations.updateSlotMetadata(
        document,
        slotLocalId: slotLocalId,
        displayTitle: displayTitle,
        timeOfDay: timeOfDay,
        isOptional: isOptional,
        completionExpectation: completionExpectation,
        coachNote: coachNote,
        athleteNote: athleteNote,
        clearDisplayTitle: clearDisplayTitle,
        clearCoachNote: clearCoachNote,
        clearAthleteNote: clearAthleteNote,
      ),
    );
  }

  @override
  Future<ProgrammeBuilderEditResult> updateMetadata(
    ProgrammeBuilderDocument document,
    ProgrammeVersionDraftMetadata metadata,
  ) {
    return _edit(document, _editOperations.updateMetadata(document, metadata));
  }

  @override
  ProgrammeBuilderEditResult? undo(ProgrammeBuilderDocument document) => null;

  @override
  ProgrammeBuilderEditResult? redo(ProgrammeBuilderDocument document) => null;

  Future<ProgrammeBuilderEditResult> _edit(
    ProgrammeBuilderDocument before,
    ProgrammeBuilderDocument after,
  ) async {
    if (!before.isEditable) {
      return ProgrammeBuilderEditResult(document: before);
    }

    final validation = _validationService.validate(after);
    return ProgrammeBuilderEditResult(
      document: after.copyWith(lastValidation: validation),
      validation: validation,
    );
  }
}
