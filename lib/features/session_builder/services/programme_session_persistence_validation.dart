import '../../../models/protocol_draft.dart';
import '../../../models/training_content_classification.dart';
import '../../../models/training_content_vocabulary.dart';
import 'protocol_draft_block_resolver.dart';
import 'session_block_validation.dart';

/// Persistence validation for programme-only coach Sessions.
class ProgrammeSessionPersistenceValidation {
  ProgrammeSessionPersistenceValidation._();

  static const _blockResolver = ProtocolDraftBlockResolver();
  static const _blockValidation = SessionBlockValidation();

  static List<String> validateForSave(ProtocolDraft draft) {
    final messages = <String>[];

    if (draft.name.trim().isEmpty) {
      messages.add('Add a session name before saving.');
    }

    if (draft.sessionFormat == null || draft.sessionFormat!.trim().isEmpty) {
      messages.add('Choose a session type before saving.');
    }

    messages.addAll(
      _blockValidation.validateSession(
        name: draft.name,
        blocks: _blockResolver.resolveBlocks(draft),
      ),
    );

    if (draft.contentKind == TrainingContentKind.cohortProtocol) {
      messages.add('Official Cohort Protocol content cannot be saved as a programme Session.');
    }

    return messages;
  }

  static bool isProgrammeOnlySession(ProtocolDraft draft) {
    return TrainingContentClassification.isProgrammeOnlySession(draft);
  }
}
