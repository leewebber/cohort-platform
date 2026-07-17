import '../../../models/protocol_draft.dart';
import '../../../models/protocol_step_draft.dart';
import '../../../models/training_content_classification.dart';
import '../../../models/training_content_vocabulary.dart';

/// Persistence validation for programme-only coach Sessions.
class ProgrammeSessionPersistenceValidation {
  ProgrammeSessionPersistenceValidation._();

  static List<String> validateForSave(ProtocolDraft draft) {
    final messages = <String>[];

    if (draft.name.trim().isEmpty) {
      messages.add('Add a session name before saving.');
    }

    if (draft.sessionFormat == null || draft.sessionFormat!.trim().isEmpty) {
      messages.add('Choose a session type before saving.');
    }

    if (draft.steps.isEmpty) {
      messages.add('Add at least one block or exercise before saving.');
    } else {
      messages.addAll(_stepMessages(draft.steps));
    }

    if (draft.contentKind == TrainingContentKind.cohortProtocol) {
      messages.add('Official Cohort Protocol content cannot be saved as a programme Session.');
    }

    return messages;
  }

  static bool isProgrammeOnlySession(ProtocolDraft draft) {
    return TrainingContentClassification.isProgrammeOnlySession(draft);
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
