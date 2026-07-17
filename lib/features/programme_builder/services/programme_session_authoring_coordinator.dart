import '../../../core/services/current_coach_identity.dart';
import '../../../core/services/training_content_id_generator.dart';
import '../../../core/utils/database_uuid.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../../features/session_builder/models/programme_session_authoring_context.dart';
import '../../../features/session_builder/models/session_builder_host_mode.dart';
import '../../../features/session_builder/services/programme_session_draft_factory.dart';
import '../../../features/session_builder/services/session_clone_service.dart';
import '../../../features/session_builder/services/programme_session_persistence_validation.dart';
import '../../../models/protocol_draft.dart';
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
  })  : _protocolBuilderService = protocolBuilderService,
        _assignmentPort = assignmentPort,
        _idGenerator = idGenerator,
        _coachIdentity = coachIdentity;

  final ProtocolBuilderService _protocolBuilderService;
  final ProgrammeSessionAssignmentPort _assignmentPort;
  final TrainingContentIdGenerator _idGenerator;
  final CurrentCoachIdentity _coachIdentity;

  Future<ProgrammeSessionAuthoringResult> saveAndAttach({
    required ProgrammeSessionAuthoringContext context,
    required ProtocolDraft draft,
  }) async {
    final isEdit = context.authoringIntent ==
        ProgrammeSessionAuthoringIntent.editCoachSession;

    ProgrammeSessionAuthoringDiagnostics.log(
      'saveStart version=${context.programmeVersionId} '
      'slot=${context.slotLocalId} isEdit=$isEdit',
    );

    final preflight = _validatePreflight(context);
    if (preflight != null) return preflight;

    if (draft.contentKind == TrainingContentKind.cohortProtocol) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage:
            'Official Cohort Protocol content cannot be saved as a programme Session.',
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

    ProtocolDraft persistedDraft;
    try {
      final saveResult =
          await _protocolBuilderService.saveDraft(draftToSave);
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

    return _attachSavedContent(
      context: context,
      savedContentId: persistedDraft.protocolId,
      displayTitle: persistedDraft.name.trim(),
      persistedDraft: persistedDraft,
      warnings: warnings,
    );
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
      ProgrammeSessionAuthoringDiagnostics.log(
        'retryAttach result=loadFailed',
      );
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

    final preflight = _validatePreflight(context);
    if (preflight != null) return preflight;

    final trimmedId = contentId.trim();
    if (trimmedId.isEmpty) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'Session could not be added to the programme.',
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
    if (loaded.contentKind != TrainingContentKind.session ||
        loaded.authoringScope != TrainingAuthoringScope.coachPrivate) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'Only reusable Sessions can be added from Session Library.',
      );
    }

    if (loaded.programmeVersionId != null &&
        loaded.programmeVersionId!.trim().isNotEmpty) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'Programme sessions must be edited from Programme Builder.',
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

    if (loaded.published != true) {
      return ProgrammeSessionAuthoringResult.validationFailed(
        coachMessage: 'This Session is not available for use.',
      );
    }

    final title = displayTitle.trim().isEmpty
        ? loaded.name.trim()
        : displayTitle.trim();

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

    final isBlankCreate = context.authoringIntent ==
        ProgrammeSessionAuthoringIntent.createBlank;
    final isCopy = context.authoringIntent ==
        ProgrammeSessionAuthoringIntent.copyCohortProtocol;

    return draft.copyWith(
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.programmeOnly,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      programmeVersionId: context.programmeVersionId,
      published: false,
      ownerId: _coachIdentity.coachId ?? draft.ownerId,
      sourceContentId:
          (isBlankCreate && !isCopy) ? null : draft.sourceContentId,
      sourceContentKind:
          (isBlankCreate && !isCopy) ? null : draft.sourceContentKind,
      sourceVersionId:
          (isBlankCreate && !isCopy) ? null : draft.sourceVersionId,
    );
  }

  ProtocolDraft _assignDurableIdIfNeeded(
    ProtocolDraft draft, {
    required bool isEdit,
  }) {
    final currentId = draft.protocolId.trim();

    if (isEdit && DatabaseUuid.isValidDatabaseUuid(currentId)) {
      return draft;
    }

    if (ProgrammeSessionDraftFactory.isLocalDraftId(currentId) ||
        SessionCloneService.isLocalCloneDraftId(currentId) ||
        currentId.isEmpty ||
        !DatabaseUuid.isValidDatabaseUuid(currentId)) {
      return draft.copyWith(protocolId: _idGenerator.newSessionId());
    }

    return draft;
  }

  Future<ProgrammeSessionAuthoringResult> _attachSavedContent({
    required ProgrammeSessionAuthoringContext context,
    required String savedContentId,
    required String displayTitle,
    required ProtocolDraft persistedDraft,
    required List<String> warnings,
  }) async {
    try {
      final editResult = await _assignmentPort.assignSession(
        slotLocalId: context.slotLocalId,
        contentId: savedContentId,
        displayTitle: displayTitle,
      );

      ProgrammeSessionAuthoringDiagnostics.log('attachSucceeded');

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
}
