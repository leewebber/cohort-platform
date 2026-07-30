import '../../../core/services/current_coach_identity.dart';
import '../../../core/services/training_content_id_generator.dart';
import '../../../core/utils/database_uuid.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../../features/session_builder/models/cohort_protocol_copy_destination.dart';
import '../../../features/session_builder/services/programme_session_persistence_validation.dart';
import '../../../features/session_builder/services/session_clone_service.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/training_content_edit_policy.dart';
import '../../../models/training_content_vocabulary.dart';
import '../diagnostics/training_library_diagnostics.dart';
import '../models/session_library_authoring_result.dart';

/// Orchestrates reusable coach Session persistence for Session Library.
class SessionLibraryAuthoringCoordinator {
  SessionLibraryAuthoringCoordinator({
    required ProtocolBuilderService protocolBuilderService,
    required TrainingContentIdGenerator idGenerator,
    required CurrentCoachIdentity coachIdentity,
    SessionCloneService cloneService = const SessionCloneService(),
    TrainingContentEditPolicy editPolicy = const TrainingContentEditPolicy(),
  }) : _protocolBuilderService = protocolBuilderService,
       _idGenerator = idGenerator,
       _coachIdentity = coachIdentity,
       _cloneService = cloneService,
       _editPolicy = editPolicy;

  final ProtocolBuilderService _protocolBuilderService;
  final TrainingContentIdGenerator _idGenerator;
  final CurrentCoachIdentity _coachIdentity;
  final SessionCloneService _cloneService;
  final TrainingContentEditPolicy _editPolicy;

  Future<SessionLibraryAuthoringResult> createSession({
    required ProtocolDraft draft,
  }) async {
    SessionLibraryDiagnostics.log('createStart');
    return _saveReusableSession(draft: draft, isEdit: false);
  }

  Future<SessionLibraryAuthoringResult> updateSession({
    required ProtocolDraft draft,
  }) async {
    SessionLibraryDiagnostics.log('updateStart');
    return _saveReusableSession(draft: draft, isEdit: true);
  }

  Future<ProtocolDraft> loadSession(String contentId) async {
    final draft = await _protocolBuilderService.loadProtocol(contentId.trim());
    _assertEditableReusableSession(draft);
    return draft;
  }

  /// Read-only template load for preview. Does not create a derivative.
  Future<ProtocolDraft> loadTemplateForPreview(String contentId) async {
    final draft = await _protocolBuilderService.loadProtocol(contentId.trim());
    if (!_editPolicy.isCanonicalTemplateSource(draft)) {
      throw const ProtocolBuilderException(
        'Only official Cohort Templates can be previewed here.',
      );
    }
    return draft;
  }

  /// Copy-on-use: prepare a coach-owned My Sessions draft from a template.
  Future<ProtocolDraft> prepareDraftFromTemplate({
    required String templateContentId,
  }) async {
    final loaded = await _protocolBuilderService.loadProtocol(
      templateContentId.trim(),
    );
    if (!_editPolicy.isCanonicalTemplateSource(loaded)) {
      throw const ProtocolBuilderException(
        'Only official Cohort Templates can be used with Use Template.',
      );
    }

    final ownerId = _coachIdentity.coachId?.trim();
    if (ownerId == null || ownerId.isEmpty) {
      throw const ProtocolBuilderException(
        'A signed-in coach is required to use a template.',
      );
    }

    return _cloneService.cloneTemplateToSession(
      source: loaded,
      newContentId: SessionCloneService.newLocalCloneDraftId(),
      ownerId: ownerId,
      destination: CohortProtocolCopyDestination.sessionLibrary,
    );
  }

  Future<SessionLibraryAuthoringResult> _saveReusableSession({
    required ProtocolDraft draft,
    required bool isEdit,
  }) async {
    final ownerId = _coachIdentity.coachId;
    if (ownerId == null || ownerId.trim().isEmpty) {
      return const SessionLibraryAuthoringResult(
        status: SessionLibraryAuthoringStatus.ownershipInvalid,
        coachMessage: 'Your coach identity is not available.',
      );
    }

    if (isEdit) {
      final ownershipError = _validateEditOwnership(draft, ownerId);
      if (ownershipError != null) return ownershipError;
    }

    if (draft.contentKind == TrainingContentKind.cohortProtocol) {
      return const SessionLibraryAuthoringResult(
        status: SessionLibraryAuthoringStatus.wrongContentKind,
        coachMessage: 'Official Cohort Protocols cannot be edited here.',
      );
    }

    if (draft.contentKind == TrainingContentKind.sessionTemplate) {
      return const SessionLibraryAuthoringResult(
        status: SessionLibraryAuthoringStatus.wrongContentKind,
        coachMessage:
            'Templates cannot be edited. Use Template creates your own Session.',
      );
    }

    if (draft.authoringScope == TrainingAuthoringScope.programmeOnly) {
      return const SessionLibraryAuthoringResult(
        status: SessionLibraryAuthoringStatus.wrongContentKind,
        coachMessage: 'Programme sessions are edited from Programme Builder.',
      );
    }

    final normalized = _normalizeReusableDraft(draft, ownerId: ownerId);
    final validationMessages =
        ProgrammeSessionPersistenceValidation.validateForSave(normalized);
    if (validationMessages.isNotEmpty) {
      return SessionLibraryAuthoringResult.validationFailed(
        coachMessage: validationMessages.first,
        warnings: validationMessages,
      );
    }

    final draftToSave = _assignDurableIdIfNeeded(normalized, isEdit: isEdit);

    if (isEdit) {
      try {
        final existing = await _protocolBuilderService.loadProtocol(
          draftToSave.protocolId.trim(),
        );
        if (_editPolicy.isReadOnlyCohortProtocol(existing) ||
            existing.contentKind == TrainingContentKind.cohortProtocol) {
          return const SessionLibraryAuthoringResult(
            status: SessionLibraryAuthoringStatus.wrongContentKind,
            coachMessage: 'Official Cohort Protocols cannot be edited here.',
          );
        }
        if (existing.contentKind == TrainingContentKind.sessionTemplate ||
            _editPolicy.requiresCoachOwnedCopy(existing)) {
          return const SessionLibraryAuthoringResult(
            status: SessionLibraryAuthoringStatus.wrongContentKind,
            coachMessage:
                'Templates cannot be edited. Use Template creates your own Session.',
          );
        }
        if (!_editPolicy.canEditInPlace(existing, coachId: ownerId)) {
          return const SessionLibraryAuthoringResult(
            status: SessionLibraryAuthoringStatus.ownershipInvalid,
            coachMessage: 'You can only edit your own Sessions.',
          );
        }
      } catch (_) {
        return const SessionLibraryAuthoringResult(
          status: SessionLibraryAuthoringStatus.validationFailed,
          coachMessage: 'This Session could not be verified for editing.',
        );
      }
    }

    try {
      final saveResult = await _protocolBuilderService.saveCoachLibrarySession(
        draftToSave,
      );
      final persisted = draftToSave.copyWith(
        protocolId: saveResult.protocolId,
        published: true,
      );

      if (isEdit) {
        SessionLibraryDiagnostics.log('updateSucceeded');
        return SessionLibraryAuthoringResult.updated(
          contentId: persisted.protocolId,
          persistedDraft: persisted,
        );
      }

      SessionLibraryDiagnostics.log('createSucceeded');
      return SessionLibraryAuthoringResult.created(
        contentId: persisted.protocolId,
        persistedDraft: persisted,
      );
    } on ProtocolBuilderException catch (error) {
      return SessionLibraryAuthoringResult.saveFailed(
        coachMessage: 'Session could not be saved.',
        error: error,
      );
    } catch (error) {
      return SessionLibraryAuthoringResult.saveFailed(
        coachMessage: 'Session could not be saved.',
        error: error,
      );
    }
  }

  ProtocolDraft _normalizeReusableDraft(
    ProtocolDraft draft, {
    required String ownerId,
  }) {
    return draft.copyWith(
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.coachPrivate,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      programmeVersionId: null,
      published: true,
      ownerId: ownerId,
      sourceContentId: draft.sourceContentId,
      sourceContentKind: draft.sourceContentKind,
      sourceVersionId: draft.sourceVersionId,
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

    // Create always mints a new ID to avoid UUID collisions with Cohort rows.
    return draft.copyWith(protocolId: _idGenerator.newSessionId());
  }

  SessionLibraryAuthoringResult? _validateEditOwnership(
    ProtocolDraft draft,
    String ownerId,
  ) {
    if (draft.ownerId != null && draft.ownerId != ownerId) {
      return const SessionLibraryAuthoringResult(
        status: SessionLibraryAuthoringStatus.ownershipInvalid,
        coachMessage: 'You can only edit your own Sessions.',
      );
    }

    if (draft.authoringScope == TrainingAuthoringScope.programmeOnly) {
      return const SessionLibraryAuthoringResult(
        status: SessionLibraryAuthoringStatus.wrongContentKind,
        coachMessage: 'Programme sessions are edited from Programme Builder.',
      );
    }

    return null;
  }

  void _assertEditableReusableSession(ProtocolDraft draft) {
    if (draft.contentKind != TrainingContentKind.session ||
        draft.authoringScope != TrainingAuthoringScope.coachPrivate) {
      throw const ProtocolBuilderException(
        'This content is not available in Session Library.',
      );
    }

    final ownerId = _coachIdentity.coachId;
    if (ownerId != null && draft.ownerId != null && draft.ownerId != ownerId) {
      throw const ProtocolBuilderException(
        'You can only access your own Sessions.',
      );
    }
  }
}
