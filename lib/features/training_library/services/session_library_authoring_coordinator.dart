import '../../../core/services/current_coach_identity.dart';
import '../../../core/services/training_content_id_generator.dart';
import '../../../core/utils/database_uuid.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../../features/session_builder/services/programme_session_persistence_validation.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/training_content_vocabulary.dart';
import '../diagnostics/training_library_diagnostics.dart';
import '../models/session_library_authoring_result.dart';
import '../../session_builder/services/session_clone_service.dart';
import '../services/session_library_draft_factory.dart';

/// Orchestrates reusable coach Session persistence for Session Library.
class SessionLibraryAuthoringCoordinator {
  SessionLibraryAuthoringCoordinator({
    required ProtocolBuilderService protocolBuilderService,
    required TrainingContentIdGenerator idGenerator,
    required CurrentCoachIdentity coachIdentity,
  })  : _protocolBuilderService = protocolBuilderService,
        _idGenerator = idGenerator,
        _coachIdentity = coachIdentity;

  final ProtocolBuilderService _protocolBuilderService;
  final TrainingContentIdGenerator _idGenerator;
  final CurrentCoachIdentity _coachIdentity;

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

    try {
      final saveResult =
          await _protocolBuilderService.saveCoachLibrarySession(draftToSave);
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

    if (SessionLibraryDraftFactory.isLocalDraftId(currentId) ||
        SessionCloneService.isLocalCloneDraftId(currentId) ||
        currentId.isEmpty ||
        !DatabaseUuid.isValidDatabaseUuid(currentId)) {
      return draft.copyWith(protocolId: _idGenerator.newSessionId());
    }

    return draft;
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
    if (ownerId != null &&
        draft.ownerId != null &&
        draft.ownerId != ownerId) {
      throw const ProtocolBuilderException(
        'You can only access your own Sessions.',
      );
    }
  }
}
