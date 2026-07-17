import '../../../models/protocol_draft.dart';
import '../../../models/protocol_step_draft.dart';

/// Validation tiers for Session Builder — separate from publish persistence rules.
class SessionBuilderValidation {
  SessionBuilderValidation._();

  /// Minimum checks before opening in-memory preview.
  static List<String> previewReadinessMessages(ProtocolDraft draft) {
    final messages = <String>[];

    if (draft.name.trim().isEmpty) {
      messages.add('Add a session name before previewing.');
    }

    if (draft.sessionFormat == null || draft.sessionFormat!.trim().isEmpty) {
      messages.add('Choose a session type before previewing.');
    }

    if (draft.steps.isEmpty) {
      messages.add('Add at least one block or exercise before previewing.');
    } else {
      messages.addAll(_stepMessages(draft.steps));
    }

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

  static List<String> _stepMessages(List<ProtocolStepDraft> steps) {
    final messages = <String>[];
    final ordered = List<ProtocolStepDraft>.from(steps)
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    for (var index = 0; index < ordered.length; index++) {
      final step = ordered[index];
      if (step.title.trim().isEmpty) {
        messages.add('Block ${index + 1} needs a title.');
      }
    }

    return messages;
  }
}
