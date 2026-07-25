import '../../../models/programme_vocabulary.dart';
import '../../../models/protocol_draft.dart';
import '../../session_builder/services/protocol_draft_block_resolver.dart';
import '../models/adaptation_metadata_completeness_models.dart';

AdaptationMetadataCompletenessInput completenessInputFromProtocolDraft(
  ProtocolDraft draft, {
  required ProtocolDraftBlockResolver blockResolver,
  AdaptationMetadataCompletenessScope scope =
      AdaptationMetadataCompletenessScope.standaloneProtocol,
  String? programmeVersionId,
  String? programmeName,
  String? slotLocationLabel,
  ProgrammeLibraryScope? programmeLibraryScope,
}) {
  return AdaptationMetadataCompletenessInput(
    protocolId: draft.protocolId,
    name: draft.name,
    blocks: blockResolver.resolveBlocks(draft),
    scope: scope,
    programmeVersionId: programmeVersionId,
    programmeName: programmeName,
    slotLocationLabel: slotLocationLabel,
    sessionType: draft.sessionType,
    sessionFormat: draft.sessionFormat,
    primaryCapability: draft.primaryCapability,
    primarySessionIntent: draft.primarySessionIntent,
    minimumViableDurationMin: draft.minimumViableDurationMin,
    contentKind: draft.contentKind,
    authoringScope: draft.authoringScope,
    endorsementStatus: draft.endorsementStatus,
    programmeLibraryScope: programmeLibraryScope,
  );
}
