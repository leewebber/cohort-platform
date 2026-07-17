import '../../../models/protocol_draft.dart';
import 'programme_builder_document.dart';

/// Outcome status for programme Session authoring operations.
enum ProgrammeSessionAuthoringStatus {
  attached,
  validationFailed,
  sessionSaveFailed,
  sessionSavedAttachFailed,
  ownershipInvalid,
  programmeNotEditable,
  slotNotFound,
  cancelled,
}

/// Tracks a saved Session that could not be attached to the programme slot.
class ProgrammeSessionPartialState {
  const ProgrammeSessionPartialState({
    required this.savedContentId,
    required this.programmeVersionId,
    required this.dayLocalId,
    required this.slotLocalId,
    required this.failureStage,
  });

  final String savedContentId;
  final String programmeVersionId;
  final String dayLocalId;
  final String slotLocalId;
  final String failureStage;
}

/// Typed result for Save & Attach and retry attach flows.
class ProgrammeSessionAuthoringResult {
  const ProgrammeSessionAuthoringResult({
    required this.status,
    this.contentId,
    this.persistedDraft,
    this.updatedDocument,
    this.partialState,
    this.warnings = const [],
    this.error,
    this.coachMessage,
  });

  final ProgrammeSessionAuthoringStatus status;
  final String? contentId;
  final ProtocolDraft? persistedDraft;
  final ProgrammeBuilderDocument? updatedDocument;
  final ProgrammeSessionPartialState? partialState;
  final List<String> warnings;
  final Object? error;
  final String? coachMessage;

  bool get isAttached => status == ProgrammeSessionAuthoringStatus.attached;

  bool get isPartialAttachFailure =>
      status == ProgrammeSessionAuthoringStatus.sessionSavedAttachFailed;

  factory ProgrammeSessionAuthoringResult.attached({
    required String contentId,
    required ProtocolDraft persistedDraft,
    required ProgrammeBuilderDocument updatedDocument,
    List<String> warnings = const [],
  }) {
    return ProgrammeSessionAuthoringResult(
      status: ProgrammeSessionAuthoringStatus.attached,
      contentId: contentId,
      persistedDraft: persistedDraft,
      updatedDocument: updatedDocument,
      warnings: warnings,
      coachMessage: 'Session added to programme',
    );
  }

  factory ProgrammeSessionAuthoringResult.validationFailed({
    required String coachMessage,
    List<String> warnings = const [],
  }) {
    return ProgrammeSessionAuthoringResult(
      status: ProgrammeSessionAuthoringStatus.validationFailed,
      warnings: warnings,
      coachMessage: coachMessage,
    );
  }

  factory ProgrammeSessionAuthoringResult.sessionSaveFailed({
    required String coachMessage,
    Object? error,
  }) {
    return ProgrammeSessionAuthoringResult(
      status: ProgrammeSessionAuthoringStatus.sessionSaveFailed,
      coachMessage: coachMessage,
      error: error,
    );
  }

  factory ProgrammeSessionAuthoringResult.sessionSavedAttachFailed({
    required String savedContentId,
    required ProgrammeSessionPartialState partialState,
    Object? error,
  }) {
    return ProgrammeSessionAuthoringResult(
      status: ProgrammeSessionAuthoringStatus.sessionSavedAttachFailed,
      contentId: savedContentId,
      partialState: partialState,
      error: error,
      coachMessage: 'Session saved, but could not be added to the programme.',
    );
  }
}
