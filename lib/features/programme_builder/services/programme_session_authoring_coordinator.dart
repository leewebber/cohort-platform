import '../../../core/services/current_coach_identity.dart';
import '../../../core/services/training_content_id_generator.dart';
import '../../../core/utils/database_uuid.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../../features/session_builder/models/cohort_protocol_copy_destination.dart';
import '../../../features/session_builder/models/programme_session_authoring_context.dart';
import '../../../features/session_builder/models/session_builder_host_mode.dart';
import '../../../features/session_builder/services/session_clone_service.dart';
import '../../../features/session_builder/services/programme_session_persistence_validation.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/training_content_edit_policy.dart';
import '../../../models/training_content_vocabulary.dart';
import '../diagnostics/programme_session_authoring_diagnostics.dart';
import '../models/programme_session_authoring_result.dart';
import '../ports/programme_session_assignment_port.dart';

/// Orchestrates programme-only Session persistence and slot attachment.
class ProgrammeSessionAuthoringCoordinator {
  ProgrammeSessionAuthoringCoordinator({
    required ProtocolBuilderService protocolBuilderService,
    required ProgrammeSessionAssignmentPort assignmentPort,
    required TrainingContentIdGenerator idGenerator,
    required CurrentCoachIdentity coachIdentity,
    SessionCloneService cloneService = const SessionCloneService(),
    TrainingContentEditPolicy editPolicy = const TrainingContentEditPolicy(),
  }) : _protocolBuilderService = protocolBuilderService,
       _assignmentPort = assignmentPort,
       _idGenerator = idGenerator,
       _coachIdentity = coachIdentity,
       _cloneService = cloneService,
       _editPolicy = editPolicy;

  final ProtocolBuilderService _protocolBuilderService;
  final ProgrammeSessionAssignmentPort _assignmentPort;
  final TrainingContentIdGenerator _idGenerator;
  final CurrentCoachIdentity _coachIdentity;
  final SessionCloneService _cloneService;
  final TrainingContentEditPolicy _editPolicy;

  bool _attachInFlight = false;
  String? _lastSuccessfulAttachKey;

  /// Copy-on-use: load a template and return an independent programme session draft.
  Future<ProtocolDraft> prepareDraftFromTemplate({
    required ProgrammeSessionAuthoringContext context,
    required String templateContentId,
  }) async {
    final loaded = await _protocolBuilderService.loadProtocol(
      templateContentId.trim(),
    );
    if (!_editPolicy.isCanonicalTemplateSource(loaded)) {
      throw ProtocolBuilderException(
        'Only official Cohort Templates can be used with Use Template.',
      );
    }

    final ownerId = _coachIdentity.coachId?.trim();
    if (ownerId == null || ownerId.isEmpty) {
      throw ProtocolBuilderException(
        'A signed-in coach is required to use a template.',
      );
    }

    return _cloneService.cloneTemplateToSession(
      source: loaded,
      newContentId: SessionCloneService.newLocalCloneDraftId(),
      ownerId: ownerId,
      destination: CohortProtocolCopyDestination.programmeOnly,
      programmeVersionId: context.programmeVersionId,
    );
  }

  Future<ProgrammeSessionAuthoringResult> saveAndAttach({
    required ProgrammeSessionAuthoringContext context,
    required ProtocolDraft draft,
  }) async {
    final isEdit =
        context.authoringIntent ==
        ProgrammeSessionAuthoringIntent.editCoachSession;

    ProgrammeSessionAuthoringDiagnostics.log(
      'saveStart version=${context.programmeVersionId} '
      'slot=${context.slotLocalId} isEdit=$isEdit',
    );

    if (_attachInFlight) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.duplicateAttachIgnored,
        coachMessage: 'Session attach is already in progress.',
      );
    }

    final preflight = _validatePreflight(context);
    if (preflight != null) return preflight;

    if (_editPolicy.isReadOnlyCohortProtocol(draft) ||
        draft.contentKind == TrainingContentKind.cohortProtocol) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage:
            'Official Cohort Protocol content cannot be saved as a programme Session.',
      );
    }

    if (draft.contentKind == TrainingContentKind.sessionTemplate) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage:
            'Templates cannot be attached directly. Use Template creates a copy.',
      );
    }

    final contentId = draft.protocolId.trim();
    final sourceId = draft.sourceContentId?.trim();
    if (sourceId != null && sourceId.isNotEmpty && contentId == sourceId) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'Copied Sessions must use a new content identity.',
      );
    }

    final warnings = <String>[];
    final normalized = _normalizeDraft(
      draft: draft,
      context: context,
      warnings: warnings,
    );

    final validationMessages =
        ProgrammeSessionPersistenceValidation.validateForSave(normalized);
    if (validationMessages.isNotEmpty) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: validationMessages.first,
        warnings: validationMessages,
      );
    }

    final draftToSave = _assignDurableIdIfNeeded(normalized, isEdit: isEdit);

    final pendingAttachKey = _attachKey(context, draftToSave.protocolId);
    if (_lastSuccessfulAttachKey == pendingAttachKey) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.duplicateAttachIgnored,
        coachMessage: 'This Session is already attached to the slot.',
      );
    }

    if (isEdit) {
      final editGate = await _assertExistingRowEditableForProgramme(
        draftToSave,
        context: context,
      );
      if (editGate != null) return editGate;
    }

    _attachInFlight = true;
    try {
      ProtocolDraft persistedDraft;
      try {
        final saveResult = await _protocolBuilderService.saveDraft(draftToSave);
        ProgrammeSessionAuthoringDiagnostics.log('sessionSaved');
        persistedDraft = draftToSave.copyWith(
          protocolId: saveResult.protocolId,
          published: false,
        );
      } on ProtocolBuilderException catch (error) {
        ProgrammeSessionAuthoringDiagnostics.log('attachFailed stage=save');
        return ProgrammeSessionAuthoringResult.sessionSaveFailed(
          coachMessage: 'Session could not be saved.',
          error: error,
        );
      } catch (error) {
        ProgrammeSessionAuthoringDiagnostics.log('attachFailed stage=save');
        return ProgrammeSessionAuthoringResult.sessionSaveFailed(
          coachMessage: 'Session could not be saved.',
          error: error,
        );
      }

      // Slot may have disappeared while save was in flight.
      final postSavePreflight = _validatePreflight(context);
      if (postSavePreflight != null) {
        return ProgrammeSessionAuthoringResult.sessionSavedAttachFailed(
          savedContentId: persistedDraft.protocolId,
          partialState: ProgrammeSessionPartialState(
            savedContentId: persistedDraft.protocolId,
            programmeVersionId: context.programmeVersionId,
            dayLocalId: context.dayLocalId,
            slotLocalId: context.slotLocalId,
            failureStage: 'attach',
          ),
        );
      }

      return _attachSavedContent(
        context: context,
        savedContentId: persistedDraft.protocolId,
        displayTitle: persistedDraft.name.trim(),
        persistedDraft: persistedDraft,
        warnings: warnings,
      );
    } finally {
      _attachInFlight = false;
    }
  }

  Future<ProgrammeSessionAuthoringResult> retryAttach({
    required ProgrammeSessionAuthoringContext context,
    required String savedContentId,
    required String displayTitle,
  }) async {
    ProgrammeSessionAuthoringDiagnostics.log('retryAttach start');

    final preflight = _validatePreflight(context);
    if (preflight != null) return preflight;

    final trimmedId = savedContentId.trim();
    if (trimmedId.isEmpty) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'Session could not be added to the programme.',
      );
    }

    ProtocolDraft persistedDraft;
    try {
      persistedDraft = await _protocolBuilderService.loadProtocol(trimmedId);
    } catch (error) {
      ProgrammeSessionAuthoringDiagnostics.log('retryAttach result=loadFailed');
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'Session could not be added to the programme.',
        warnings: const ['Saved session content is no longer available.'],
      );
    }

    final result = await _attachSavedContent(
      context: context,
      savedContentId: trimmedId,
      displayTitle: displayTitle.trim().isEmpty
          ? persistedDraft.name.trim()
          : displayTitle.trim(),
      persistedDraft: persistedDraft,
      warnings: const [],
    );

    ProgrammeSessionAuthoringDiagnostics.log(
      'retryAttach result=${result.status.name}',
    );

    return result;
  }

  /// Attaches an existing reusable coach Session to a programme slot (live reference).
  Future<ProgrammeSessionAuthoringResult> attachExistingSession({
    required ProgrammeSessionAuthoringContext context,
    required String contentId,
    required String displayTitle,
  }) async {
    ProgrammeSessionAuthoringDiagnostics.log('attachExistingSession start');

    if (_attachInFlight) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.duplicateAttachIgnored,
        coachMessage: 'Session attach is already in progress.',
      );
    }

    final preflight = _validatePreflight(context);
    if (preflight != null) return preflight;

    final trimmedId = contentId.trim();
    if (trimmedId.isEmpty) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'Session could not be added to the programme.',
      );
    }

    final duplicateKey = _attachKey(context, trimmedId);
    if (_lastSuccessfulAttachKey == duplicateKey) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.duplicateAttachIgnored,
        coachMessage: 'This Session is already attached to the slot.',
      );
    }

    ProtocolDraft loaded;
    try {
      loaded = await _protocolBuilderService.loadProtocol(trimmedId);
    } catch (_) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'Session could not be added to the programme.',
      );
    }

    final ownerId = _coachIdentity.coachId;
    if (!_editPolicy.canAttachAsLiveReference(loaded, coachId: ownerId)) {
      if (loaded.contentKind == TrainingContentKind.sessionTemplate) {
        return ProgrammeSessionAuthoringResult.validationFailed(
          coachMessage:
              'Templates cannot be attached directly. Choose Use Template.',
        );
      }
      if (_editPolicy.isReadOnlyCohortProtocol(loaded)) {
        return ProgrammeSessionAuthoringResult.validationFailed(
          coachMessage: 'Cohort Protocols cannot be added from My Sessions.',
        );
      }
      if (ownerId != null &&
          loaded.ownerId != null &&
          loaded.ownerId != ownerId) {
        return const ProgrammeSessionAuthoringResult(
          status: ProgrammeSessionAuthoringStatus.ownershipInvalid,
          coachMessage: 'This Session belongs to another coach.',
        );
      }
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'Only your reusable My Sessions can be attached here.',
      );
    }

    final title = displayTitle.trim().isEmpty
        ? loaded.name.trim()
        : displayTitle.trim();

    _attachInFlight = true;
    try {
      final result = await _attachSavedContent(
        context: context,
        savedContentId: trimmedId,
        displayTitle: title,
        persistedDraft: loaded,
        warnings: const [],
      );

      ProgrammeSessionAuthoringDiagnostics.log(
        'attachExistingSession result=${result.status.name}',
      );

      return result;
    } finally {
      _attachInFlight = false;
    }
  }

  ProgrammeSessionAuthoringResult? _validatePreflight(
    ProgrammeSessionAuthoringContext context,
  ) {
    if (context.programmeVersionId.trim().isEmpty) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'This programme version is no longer available.',
      );
    }

    if (!_assignmentPort.isEditable) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.programmeNotEditable,
        coachMessage: 'This programme is read-only.',
      );
    }

    final document = _assignmentPort.document;
    if (document == null) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.programmeNotEditable,
        coachMessage: 'This programme is not ready for editing.',
      );
    }

    if (document.metadata.versionId != context.programmeVersionId) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.slotNotFound,
        coachMessage:
            'This programme changed while you were editing. Reopen the slot and try again.',
      );
    }

    if (_assignmentPort.programmeVersionId != context.programmeVersionId) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.slotNotFound,
        coachMessage:
            'This programme changed while you were editing. Reopen the slot and try again.',
      );
    }

    if (!_assignmentPort.slotExists(
      weekLocalId: context.weekLocalId,
      dayLocalId: context.dayLocalId,
      slotLocalId: context.slotLocalId,
    )) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.slotNotFound,
        coachMessage:
            'This programme slot is no longer available. Reopen the slot and try again.',
      );
    }

    return null;
  }

  ProtocolDraft _normalizeDraft({
    required ProtocolDraft draft,
    required ProgrammeSessionAuthoringContext context,
    required List<String> warnings,
  }) {
    if (draft.contentKind != TrainingContentKind.session) {
      warnings.add('Normalized content classification to programme Session.');
    }

    final isBlankCreate =
        context.authoringIntent == ProgrammeSessionAuthoringIntent.createBlank;
    final keepsProvenance =
        context.authoringIntent ==
            ProgrammeSessionAuthoringIntent.copyCohortProtocol ||
        context.authoringIntent == ProgrammeSessionAuthoringIntent.fromTemplate;

    return draft.copyWith(
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.programmeOnly,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      programmeVersionId: context.programmeVersionId,
      published: false,
      ownerId: _coachIdentity.coachId ?? draft.ownerId,
      sourceContentId: (isBlankCreate && !keepsProvenance)
          ? null
          : draft.sourceContentId,
      sourceContentKind: (isBlankCreate && !keepsProvenance)
          ? null
          : draft.sourceContentKind,
      sourceVersionId: (isBlankCreate && !keepsProvenance)
          ? null
          : draft.sourceVersionId,
    );
  }

  ProtocolDraft _assignDurableIdIfNeeded(
    ProtocolDraft draft, {
    required bool isEdit,
  }) {
    final currentId = draft.protocolId.trim();

    // Edit keeps verified durable IDs only after ownership/kind gate.
    if (isEdit && DatabaseUuid.isValidDatabaseUuid(currentId)) {
      return draft;
    }

    // Create always mints a new ID — never retain a caller UUID that could
    // collide with an existing Cohort Protocol row.
    return draft.copyWith(protocolId: _idGenerator.newSessionId());
  }

  Future<ProgrammeSessionAuthoringResult?>
  _assertExistingRowEditableForProgramme(
    ProtocolDraft draft, {
    required ProgrammeSessionAuthoringContext context,
  }) async {
    try {
      final existing = await _protocolBuilderService.loadProtocol(
        draft.protocolId.trim(),
      );
      if (_editPolicy.isReadOnlyCohortProtocol(existing) ||
          existing.contentKind == TrainingContentKind.cohortProtocol) {
        return ProgrammeSessionAuthoringResult.validationFailed(
          coachMessage: 'Official Cohort Protocols cannot be edited in place.',
        );
      }
      if (!_editPolicy.canEditInPlace(
        existing,
        coachId: _coachIdentity.coachId,
        programmeVersionId: context.programmeVersionId,
      )) {
        return ProgrammeSessionAuthoringResult.validationFailed(
          coachMessage: 'This Session cannot be edited here.',
        );
      }
      return null;
    } catch (_) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'This Session could not be verified for editing.',
      );
    }
  }

  Future<ProgrammeSessionAuthoringResult> _attachSavedContent({
    required ProgrammeSessionAuthoringContext context,
    required String savedContentId,
    required String displayTitle,
    required ProtocolDraft persistedDraft,
    required List<String> warnings,
  }) async {
    final key = _attachKey(context, savedContentId);
    if (_lastSuccessfulAttachKey == key) {
      return const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.duplicateAttachIgnored,
        coachMessage: 'This Session is already attached to the slot.',
      );
    }

    try {
      final editResult = await _assignmentPort.assignSession(
        weekLocalId: context.weekLocalId,
        dayLocalId: context.dayLocalId,
        slotLocalId: context.slotLocalId,
        contentId: savedContentId,
        displayTitle: displayTitle,
      );

      ProgrammeSessionAuthoringDiagnostics.log('attachSucceeded');
      _lastSuccessfulAttachKey = key;

      return ProgrammeSessionAuthoringResult.attached(
        contentId: savedContentId,
        persistedDraft: persistedDraft,
        updatedDocument: editResult.document,
        warnings: warnings,
      );
    } catch (error) {
      ProgrammeSessionAuthoringDiagnostics.log('attachFailed stage=attach');

      return ProgrammeSessionAuthoringResult.sessionSavedAttachFailed(
        savedContentId: savedContentId,
        partialState: ProgrammeSessionPartialState(
          savedContentId: savedContentId,
          programmeVersionId: context.programmeVersionId,
          dayLocalId: context.dayLocalId,
          slotLocalId: context.slotLocalId,
          failureStage: 'attach',
        ),
        error: error,
      );
    }
  }

  String _attachKey(
    ProgrammeSessionAuthoringContext context,
    String contentId,
  ) {
    return '${context.programmeVersionId}|'
        '${context.weekLocalId}|${context.dayLocalId}|'
        '${context.slotLocalId}|${contentId.trim()}';
  }
}
