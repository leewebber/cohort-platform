import '../../../core/services/current_coach_identity.dart';
import '../../../features/admin/services/protocol_builder_service.dart';
import '../../../features/session_builder/diagnostics/cohort_protocol_customisation_diagnostics.dart';
import '../../../features/session_builder/models/cohort_protocol_copy_destination.dart';
import '../../../features/session_builder/models/programme_session_authoring_context.dart';
import '../../../features/session_builder/services/session_clone_service.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../training_library/services/session_library_authoring_coordinator.dart';
import '../models/cohort_protocol_customisation_result.dart';
import '../models/programme_session_authoring_result.dart';
import '../ports/programme_session_assignment_port.dart';
import 'programme_session_authoring_coordinator.dart';

/// Orchestrates Cohort Protocol copy-and-customise (M5).
class CohortProtocolCustomisationCoordinator {
  CohortProtocolCustomisationCoordinator({
    required ProtocolBuilderService protocolBuilderService,
    required ProgrammeSessionAuthoringCoordinator programmeSessionCoordinator,
    required SessionLibraryAuthoringCoordinator librarySessionCoordinator,
    required SessionCloneService sessionCloneService,
    required CurrentCoachIdentity coachIdentity,
    ProgrammeSessionAssignmentPort? assignmentPort,
  })  : _protocolBuilderService = protocolBuilderService,
        _programmeSessionCoordinator = programmeSessionCoordinator,
        _librarySessionCoordinator = librarySessionCoordinator,
        _sessionCloneService = sessionCloneService,
        _coachIdentity = coachIdentity,
        _assignmentPort = assignmentPort;

  final ProtocolBuilderService _protocolBuilderService;
  final ProgrammeSessionAuthoringCoordinator _programmeSessionCoordinator;
  final SessionLibraryAuthoringCoordinator _librarySessionCoordinator;
  final SessionCloneService _sessionCloneService;
  final CurrentCoachIdentity _coachIdentity;
  final ProgrammeSessionAssignmentPort? _assignmentPort;

  Future<CohortProtocolCustomisationResult> prepareCopy({
    required String sourceProtocolId,
    required CohortProtocolCopyDestination destination,
    ProgrammeSessionAuthoringContext? programmeContext,
  }) async {
    CohortProtocolCustomisationDiagnostics.log('sourceLoadStart');

    final trimmedSourceId = sourceProtocolId.trim();
    if (trimmedSourceId.isEmpty) {
      return const CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.sourceNotFound,
        coachMessage: 'This Cohort Protocol could not be found.',
      );
    }

    ProtocolDraft source;
    try {
      source =
          await _protocolBuilderService.loadCohortProtocolForCopy(trimmedSourceId);
    } on ProtocolBuilderException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('could not be found') ||
          message.contains('not found')) {
        return CohortProtocolCustomisationResult(
          status: CohortProtocolCustomisationStatus.sourceNotFound,
          coachMessage: 'This Cohort Protocol could not be found.',
          error: error,
        );
      }

      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.sourceNotEligible,
        coachMessage:
            'Only published official Cohort Protocols can be copied.',
        error: error,
      );
    } catch (error) {
      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.validationFailed,
        coachMessage:
            'This Cohort Protocol could not be loaded right now. Please try again.',
        error: error,
      );
    }

    CohortProtocolCustomisationDiagnostics.log('sourceEligible');

    final ownerId = _coachIdentity.coachId?.trim();
    if (ownerId == null || ownerId.isEmpty) {
      return const CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.ownershipInvalid,
        coachMessage: 'Your coach identity is not available.',
      );
    }

    try {
      final copied = _sessionCloneService.cloneCohortProtocolToSession(
        source: source,
        newContentId: SessionCloneService.newLocalCloneDraftId(),
        ownerId: ownerId,
        destination: destination,
        programmeVersionId: programmeContext?.programmeVersionId,
      );

      CohortProtocolCustomisationDiagnostics.log(
        'clonePrepared destination=${destination.name}',
      );

      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.prepared,
        copiedDraft: copied,
        sourceContentId: source.protocolId,
      );
    } catch (error) {
      CohortProtocolCustomisationDiagnostics.log('cloneFailed');
      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.cloneFailed,
        coachMessage:
            'This Cohort Protocol could not be copied right now. Please try again.',
        error: error,
      );
    }
  }

  Future<CohortProtocolCustomisationResult> saveProgrammeCopy({
    required ProgrammeSessionAuthoringContext context,
    required ProtocolDraft draft,
  }) async {
    final guard = _assertCloneDraftSafe(draft);
    if (guard != null) return guard;

    final slotConflict = _checkSlotSourceConflict(context);
    if (slotConflict != null) return slotConflict;

    final result = await _programmeSessionCoordinator.saveAndAttach(
      context: context,
      draft: draft,
    );

    return _mapProgrammeResult(result, draft: draft);
  }

  Future<CohortProtocolCustomisationResult> saveLibraryCopy({
    ProgrammeSessionAuthoringContext? context,
    required ProtocolDraft draft,
  }) async {
    final guard = _assertCloneDraftSafe(draft);
    if (guard != null) return guard;

    if (context != null) {
      final slotConflict = _checkSlotSourceConflict(context);
      if (slotConflict != null) return slotConflict;
    }

    final libraryResult =
        await _librarySessionCoordinator.createSession(draft: draft);

    if (!libraryResult.isSuccess) {
      CohortProtocolCustomisationDiagnostics.log('saveFailed destination=library');
      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.saveFailed,
        coachMessage: libraryResult.coachMessage ?? 'Session could not be saved.',
        error: libraryResult.error,
        warnings: libraryResult.warnings,
      );
    }

    final persisted = libraryResult.persistedDraft!;
    final contentId = libraryResult.contentId!;

    CohortProtocolCustomisationDiagnostics.log('saveSucceeded destination=library');

    if (context == null) {
      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.savedToLibrary,
        persistedDraft: persisted,
        contentId: contentId,
        sourceContentId: draft.sourceContentId,
      );
    }

    final attachResult = await _programmeSessionCoordinator.attachExistingSession(
      context: context,
      contentId: contentId,
      displayTitle: persisted.name.trim(),
    );

    if (attachResult.isAttached) {
      CohortProtocolCustomisationDiagnostics.log('attachSucceeded');
      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.savedToLibraryAttached,
        persistedDraft: persisted,
        contentId: contentId,
        sourceContentId: draft.sourceContentId,
        updatedDocument: attachResult.updatedDocument,
      );
    }

    CohortProtocolCustomisationDiagnostics.log('attachFailed stage=attach');
    return CohortProtocolCustomisationResult(
      status: CohortProtocolCustomisationStatus.savedAttachFailed,
      persistedDraft: persisted,
      contentId: contentId,
      sourceContentId: draft.sourceContentId,
      partialState: attachResult.partialState,
      error: attachResult.error,
      coachMessage:
          'Session saved to your library, but it could not be added to the programme.',
    );
  }

  Future<CohortProtocolCustomisationResult> retryLibraryAttach({
    required ProgrammeSessionAuthoringContext context,
    required String savedContentId,
    required String displayTitle,
  }) async {
    final slotConflict = _checkSlotSourceConflict(context);
    if (slotConflict != null) return slotConflict;

    final attachResult = await _programmeSessionCoordinator.attachExistingSession(
      context: context,
      contentId: savedContentId,
      displayTitle: displayTitle,
    );

    if (attachResult.isAttached) {
      CohortProtocolCustomisationDiagnostics.log('attachSucceeded');
      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.savedToLibraryAttached,
        contentId: savedContentId,
        updatedDocument: attachResult.updatedDocument,
      );
    }

    CohortProtocolCustomisationDiagnostics.log('attachFailed stage=retry');
    return CohortProtocolCustomisationResult(
      status: CohortProtocolCustomisationStatus.savedAttachFailed,
      contentId: savedContentId,
      partialState: attachResult.partialState,
      error: attachResult.error,
      coachMessage:
          'Session saved to your library, but it could not be added to the programme.',
    );
  }

  CohortProtocolCustomisationResult _mapProgrammeResult(
    ProgrammeSessionAuthoringResult result, {
    required ProtocolDraft draft,
  }) {
    if (result.isAttached) {
      CohortProtocolCustomisationDiagnostics.log(
        'saveSucceeded destination=programmeOnly',
      );
      CohortProtocolCustomisationDiagnostics.log('attachSucceeded');
      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.savedProgrammeOnly,
        persistedDraft: result.persistedDraft,
        contentId: result.contentId,
        sourceContentId: draft.sourceContentId,
        updatedDocument: result.updatedDocument,
        warnings: result.warnings,
        coachMessage: result.coachMessage,
      );
    }

    if (result.isPartialAttachFailure) {
      CohortProtocolCustomisationDiagnostics.log(
        'saveSucceeded destination=programmeOnly',
      );
      CohortProtocolCustomisationDiagnostics.log('attachFailed stage=attach');
      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.savedAttachFailed,
        persistedDraft: result.persistedDraft,
        contentId: result.contentId,
        sourceContentId: draft.sourceContentId,
        partialState: result.partialState,
        error: result.error,
        coachMessage: result.coachMessage,
      );
    }

    if (result.status == ProgrammeSessionAuthoringStatus.sessionSaveFailed) {
      CohortProtocolCustomisationDiagnostics.log('saveFailed destination=programmeOnly');
      return CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.saveFailed,
        coachMessage: result.coachMessage ?? 'Session could not be saved.',
        error: result.error,
        warnings: result.warnings,
      );
    }

    return CohortProtocolCustomisationResult(
      status: CohortProtocolCustomisationStatus.validationFailed,
      coachMessage: result.coachMessage ?? 'Session could not be saved.',
      error: result.error,
      warnings: result.warnings,
    );
  }

  CohortProtocolCustomisationResult? _assertCloneDraftSafe(ProtocolDraft draft) {
    if (draft.contentKind == TrainingContentKind.cohortProtocol) {
      return const CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.validationFailed,
        coachMessage: 'Official Cohort Protocol content cannot be saved here.',
      );
    }

    if (draft.authoringScope == TrainingAuthoringScope.cohortGlobal) {
      return const CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.validationFailed,
        coachMessage: 'Official Cohort Protocol content cannot be saved here.',
      );
    }

    if (draft.endorsementStatus == TrainingEndorsementStatus.cohortEndorsed) {
      return const CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.validationFailed,
        coachMessage: 'Official Cohort Protocol content cannot be saved here.',
      );
    }

    final contentId = draft.protocolId.trim();
    final sourceId = draft.sourceContentId?.trim();
    if (sourceId != null &&
        sourceId.isNotEmpty &&
        contentId == sourceId) {
      return const CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.validationFailed,
        coachMessage: 'Copied Sessions must use a new content identity.',
      );
    }

    return null;
  }

  CohortProtocolCustomisationResult? _checkSlotSourceConflict(
    ProgrammeSessionAuthoringContext context,
  ) {
    final expectedSource = context.sourceProtocolId?.trim();
    if (expectedSource == null || expectedSource.isEmpty) {
      return null;
    }

    final port = _assignmentPort;
    if (port == null) {
      return null;
    }

    final currentProtocolId = _readSlotProtocolId(context, port);
    if (currentProtocolId == null) {
      return const CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.slotConflict,
        coachMessage:
            'This programme slot changed while you were editing. Reopen the slot and try again.',
      );
    }

    if (currentProtocolId != expectedSource) {
      return const CohortProtocolCustomisationResult(
        status: CohortProtocolCustomisationStatus.slotConflict,
        coachMessage:
            'This programme slot changed while you were editing. Reopen the slot and try again.',
      );
    }

    return null;
  }

  String? _readSlotProtocolId(
    ProgrammeSessionAuthoringContext context,
    ProgrammeSessionAssignmentPort port,
  ) {
    final document = port.document;
    if (document == null) return null;

    for (final week in document.template.allWeeks) {
      if (week.localId != context.weekLocalId) continue;
      for (final day in week.days) {
        if (day.localId != context.dayLocalId) continue;
        for (final slot in day.slots) {
          if (slot.localId == context.slotLocalId) {
            return slot.protocolId.trim();
          }
        }
      }
    }

    return null;
  }
}
