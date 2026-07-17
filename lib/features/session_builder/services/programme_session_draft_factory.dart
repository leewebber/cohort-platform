import '../../../models/protocol_draft.dart';
import '../../../models/protocol_step_draft.dart';
import '../../../models/training_content_vocabulary.dart';
import '../models/programme_session_authoring_context.dart';

/// Creates in-memory coach Session drafts for embedded authoring (M2 — not persisted).
class ProgrammeSessionDraftFactory {
  ProgrammeSessionDraftFactory._();

  /// Temporary local protocol id for unsaved embedded drafts (not a Cohort code).
  static String localDraftProtocolId(ProgrammeSessionAuthoringContext context) {
    return 'local-session-${context.slotLocalId}';
  }

  static bool isLocalDraftId(String protocolId) {
    return protocolId.trim().startsWith('local-session-');
  }

  static ProtocolDraft createBlankProgrammeSessionDraft(
    ProgrammeSessionAuthoringContext context, {
    String? ownerId,
  }) {
    final resolvedOwnerId = ownerId;
    final defaultName = _defaultSessionName(context);

    return ProtocolDraft(
      protocolId: localDraftProtocolId(context),
      name: defaultName,
      steps: const <ProtocolStepDraft>[],
      published: false,
      contentKind: TrainingContentKind.session,
      authoringScope: TrainingAuthoringScope.programmeOnly,
      endorsementStatus: TrainingEndorsementStatus.coachAuthored,
      programmeVersionId: context.programmeVersionId,
      ownerId: resolvedOwnerId,
    );
  }

  static String _defaultSessionName(ProgrammeSessionAuthoringContext context) {
    if (context.weekNumber > 0) {
      return 'Week ${context.weekNumber} · ${context.slotDisplayLabel}';
    }

    return context.slotDisplayLabel;
  }
}
