import '../../../features/founder_acceptance/founder_acceptance_content.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/training_content_classification.dart';

/// Canonical and founder-protected Session Revision rules (M9.3).
class SessionRevisionContentProtection {
  const SessionRevisionContentProtection._();

  static bool isCanonicalProtected(ProtocolDraft draft) {
    if (draft.protocolId.trim() == FounderAcceptanceContent.protocolId) {
      return true;
    }

    return TrainingContentClassification.isCohortProtocol(draft);
  }

  static String copyAndCustomiseAlternative(ProtocolDraft draft) {
    if (TrainingContentClassification.isCohortProtocol(draft)) {
      return 'Copy and customise to create coach-owned content.';
    }

    return 'Duplicate this content under your coach library where permitted.';
  }
}
