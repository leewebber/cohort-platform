import '../../../models/protocol_draft.dart';
import 'programme_builder_document.dart';
import 'programme_session_authoring_result.dart';

/// Outcome status for Cohort Protocol copy-and-customise operations.
enum CohortProtocolCustomisationStatus {
  prepared,
  savedProgrammeOnly,
  savedToLibrary,
  savedToLibraryAttached,
  validationFailed,
  sourceNotFound,
  sourceNotEligible,
  cloneFailed,
  saveFailed,
  savedAttachFailed,
  ownershipInvalid,
  programmeNotEditable,
  slotConflict,
}

/// Typed result for copy-and-customise flows (M5).
class CohortProtocolCustomisationResult {
  const CohortProtocolCustomisationResult({
    required this.status,
    this.copiedDraft,
    this.persistedDraft,
    this.contentId,
    this.sourceContentId,
    this.partialState,
    this.updatedDocument,
    this.warnings = const [],
    this.error,
    this.coachMessage,
  });

  final CohortProtocolCustomisationStatus status;
  final ProtocolDraft? copiedDraft;
  final ProtocolDraft? persistedDraft;
  final String? contentId;
  final String? sourceContentId;
  final ProgrammeSessionPartialState? partialState;
  final ProgrammeBuilderDocument? updatedDocument;
  final List<String> warnings;
  final Object? error;
  final String? coachMessage;

  bool get isAttached =>
      status == CohortProtocolCustomisationStatus.savedProgrammeOnly ||
      status == CohortProtocolCustomisationStatus.savedToLibraryAttached;

  bool get isPartialAttachFailure =>
      status == CohortProtocolCustomisationStatus.savedAttachFailed;

  ProgrammeSessionAuthoringResult? toProgrammeAuthoringResult() {
    if (isAttached &&
        persistedDraft != null &&
        contentId != null &&
        updatedDocument != null) {
      return ProgrammeSessionAuthoringResult.attached(
        contentId: contentId!,
        persistedDraft: persistedDraft!,
        updatedDocument: updatedDocument!,
        warnings: warnings,
      );
    }

    if (isPartialAttachFailure && partialState != null) {
      return ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.sessionSavedAttachFailed,
        contentId: partialState!.savedContentId,
        partialState: partialState,
        error: error,
        coachMessage: coachMessage ??
            'Session saved, but could not be added to the programme.',
      );
    }

    if (status == CohortProtocolCustomisationStatus.saveFailed) {
      return ProgrammeSessionAuthoringResult.sessionSaveFailed(
        coachMessage: coachMessage ?? 'Session could not be saved.',
        error: error,
      );
    }

    return null;
  }
}
