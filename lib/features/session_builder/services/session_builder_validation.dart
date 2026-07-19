import '../../../models/protocol_draft.dart';
import '../services/protocol_draft_block_resolver.dart';
import 'session_block_validation.dart';

/// Validation tiers for Session Builder — separate from publish persistence rules.
class SessionBuilderValidation {
  SessionBuilderValidation._();

  static const _blockResolver = ProtocolDraftBlockResolver();
  static const _blockValidation = SessionBlockValidation();

  /// Minimum checks before opening in-memory preview.
  static List<String> previewReadinessMessages(ProtocolDraft draft) {
    final messages = <String>[];

    if (draft.name.trim().isEmpty) {
      messages.add('Add a session name before previewing.');
    }

    if (draft.sessionFormat == null || draft.sessionFormat!.trim().isEmpty) {
      messages.add('Choose a session type before previewing.');
    }

    messages.addAll(
      _blockValidation.validateSession(
        name: draft.name,
        blocks: _blockResolver.resolveBlocks(draft),
      ),
    );

    return messages;
  }

  /// Basic field validation while editing (non-blocking for M2 embedded mode).
  static List<String> editingMessages(ProtocolDraft draft) {
    final messages = <String>[];

    if (draft.name.trim().isEmpty) {
      messages.add('Session name is recommended.');
    }

    return messages;
  }

  static bool canPreview(ProtocolDraft draft) {
    return previewReadinessMessages(draft).isEmpty;
  }
}
