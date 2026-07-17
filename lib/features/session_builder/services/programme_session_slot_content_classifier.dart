import '../../../features/admin/services/protocol_builder_service.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../programme_builder/models/programme_builder_constants.dart';
import '../services/programme_session_draft_factory.dart';

/// Classifies slot content for Programme Editor actions.
enum ProgrammeSlotContentKind {
  empty,
  cohortProtocol,
  programmeSession,
  reusableCoachSession,
  unknown,
}

class ProgrammeSessionSlotContentClassifier {
  const ProgrammeSessionSlotContentClassifier({
    required ProtocolBuilderService protocolBuilderService,
  }) : _protocolBuilderService = protocolBuilderService;

  final ProtocolBuilderService _protocolBuilderService;

  Future<ProgrammeSlotContentKind> classify({
    required String protocolId,
    required String programmeVersionId,
  }) async {
    if (ProgrammeBuilderConstants.isUnassignedProtocolId(protocolId)) {
      return ProgrammeSlotContentKind.empty;
    }

    if (ProgrammeSessionDraftFactory.isLocalDraftId(protocolId)) {
      return ProgrammeSlotContentKind.unknown;
    }

    try {
      final draft = await _protocolBuilderService.loadProtocol(protocolId);
      return _classifyDraft(draft, programmeVersionId: programmeVersionId);
    } catch (_) {
      return ProgrammeSlotContentKind.unknown;
    }
  }

  ProgrammeSlotContentKind classifyDraft(
    ProtocolDraft draft, {
    required String programmeVersionId,
  }) {
    return _classifyDraft(draft, programmeVersionId: programmeVersionId);
  }

  ProgrammeSlotContentKind _classifyDraft(
    ProtocolDraft draft, {
    required String programmeVersionId,
  }) {
    if (draft.contentKind == TrainingContentKind.session &&
        draft.authoringScope == TrainingAuthoringScope.programmeOnly &&
        draft.programmeVersionId == programmeVersionId) {
      return ProgrammeSlotContentKind.programmeSession;
    }

    if (draft.contentKind == TrainingContentKind.session &&
        draft.authoringScope == TrainingAuthoringScope.coachPrivate) {
      return ProgrammeSlotContentKind.reusableCoachSession;
    }

    if (draft.contentKind == TrainingContentKind.cohortProtocol &&
        draft.authoringScope == TrainingAuthoringScope.cohortGlobal) {
      return ProgrammeSlotContentKind.cohortProtocol;
    }

    return ProgrammeSlotContentKind.unknown;
  }
}
