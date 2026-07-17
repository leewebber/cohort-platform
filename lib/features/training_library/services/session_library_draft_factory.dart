import '../../../models/protocol_draft.dart';
import '../../../models/protocol_step_draft.dart';
import '../../../models/training_content_vocabulary.dart';

/// Creates in-memory reusable coach Session drafts for Session Library (M4).
class SessionLibraryDraftFactory {
  SessionLibraryDraftFactory._();

  static const localDraftIdPrefix = 'local-library-session-';

  static String localDraftProtocolId() {
    return '$localDraftIdPrefix${DateTime.now().microsecondsSinceEpoch}';
  }

  static bool isLocalDraftId(String protocolId) {
    return protocolId.trim().startsWith(localDraftIdPrefix);
  }

  static ProtocolDraft createBlankReusableSessionDraft({
    String? ownerId,
  }) {
    return ProtocolDraft(
      protocolId: localDraftProtocolId(),
      name: 'New Session',
      steps: const <ProtocolStepDraft>[],
      published: true,
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.coachPrivate,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      programmeVersionId: null,
      ownerId: ownerId,
    );
  }
}
