import '../../../models/protocol_draft.dart';

/// Outcome status for Session Library authoring operations.
enum SessionLibraryAuthoringStatus {
  created,
  updated,
  validationFailed,
  saveFailed,
  notFound,
  ownershipInvalid,
  wrongContentKind,
}

/// Typed result for reusable Session create/update flows.
class SessionLibraryAuthoringResult {
  const SessionLibraryAuthoringResult({
    required this.status,
    this.contentId,
    this.persistedDraft,
    this.warnings = const [],
    this.error,
    this.coachMessage,
  });

  final SessionLibraryAuthoringStatus status;
  final String? contentId;
  final ProtocolDraft? persistedDraft;
  final List<String> warnings;
  final Object? error;
  final String? coachMessage;

  bool get isSuccess =>
      status == SessionLibraryAuthoringStatus.created ||
      status == SessionLibraryAuthoringStatus.updated;

  factory SessionLibraryAuthoringResult.created({
    required String contentId,
    required ProtocolDraft persistedDraft,
    List<String> warnings = const [],
  }) {
    return SessionLibraryAuthoringResult(
      status: SessionLibraryAuthoringStatus.created,
      contentId: contentId,
      persistedDraft: persistedDraft,
      warnings: warnings,
      coachMessage: 'Session saved',
    );
  }

  factory SessionLibraryAuthoringResult.updated({
    required String contentId,
    required ProtocolDraft persistedDraft,
    List<String> warnings = const [],
  }) {
    return SessionLibraryAuthoringResult(
      status: SessionLibraryAuthoringStatus.updated,
      contentId: contentId,
      persistedDraft: persistedDraft,
      warnings: warnings,
      coachMessage: 'Session updated',
    );
  }

  factory SessionLibraryAuthoringResult.validationFailed({
    required String coachMessage,
    List<String> warnings = const [],
  }) {
    return SessionLibraryAuthoringResult(
      status: SessionLibraryAuthoringStatus.validationFailed,
      warnings: warnings,
      coachMessage: coachMessage,
    );
  }

  factory SessionLibraryAuthoringResult.saveFailed({
    required String coachMessage,
    Object? error,
  }) {
    return SessionLibraryAuthoringResult(
      status: SessionLibraryAuthoringStatus.saveFailed,
      coachMessage: coachMessage,
      error: error,
    );
  }
}
