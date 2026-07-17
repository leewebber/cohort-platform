import 'protocol_draft.dart';
import 'training_content_vocabulary.dart';

/// Domain validation for training content metadata invariants.
///
/// Database cross-field constraints are deferred until auth identity flows
/// stabilise (dev coach id is TEXT, not UUID). See M1 docs for future DB rules.
class TrainingContentClassification {
  TrainingContentClassification._();

  static bool isCohortProtocol(ProtocolDraft draft) {
    return draft.contentKind == TrainingContentKind.cohortProtocol &&
        draft.authoringScope == TrainingAuthoringScope.cohortGlobal &&
        draft.endorsementStatus == TrainingEndorsementStatus.cohortEndorsed;
  }

  static bool isProgrammeOnlySession(ProtocolDraft draft) {
    return draft.contentKind == TrainingContentKind.session &&
        draft.authoringScope == TrainingAuthoringScope.programmeOnly &&
        _hasValue(draft.programmeVersionId);
  }

  static bool isReusableCoachSession(ProtocolDraft draft) {
    return draft.contentKind == TrainingContentKind.session &&
        draft.authoringScope == TrainingAuthoringScope.coachPrivate &&
        _hasValue(draft.ownerId);
  }

  static bool isSessionTemplate(ProtocolDraft draft) {
    return draft.contentKind == TrainingContentKind.sessionTemplate;
  }

  /// Whether content may be attached via normal Programme Builder protocol picker.
  static bool isProgrammeBuilderAttachable(ProtocolDraft draft) {
    return isCohortProtocol(draft);
  }

  static void validateCohortProtocol(ProtocolDraft draft) {
    if (!isCohortProtocol(draft)) {
      throw TrainingContentInvariantException(
        'Cohort Protocol requires contentKind=cohortProtocol, '
        'authoringScope=cohortGlobal, endorsementStatus=cohortEndorsed.',
      );
    }
  }

  static void validateProgrammeOnlySession(ProtocolDraft draft) {
    if (!isProgrammeOnlySession(draft)) {
      throw TrainingContentInvariantException(
        'Programme-only Session requires contentKind=session, '
        'authoringScope=programmeOnly, and programmeVersionId.',
      );
    }
  }

  static void validateReusableCoachSession(ProtocolDraft draft) {
    if (!isReusableCoachSession(draft)) {
      throw TrainingContentInvariantException(
        'Reusable Coach Session requires contentKind=session, '
        'authoringScope=coachPrivate, and ownerId.',
      );
    }
  }

  static void validateSessionTemplate(ProtocolDraft draft) {
    if (!isSessionTemplate(draft)) {
      throw TrainingContentInvariantException(
        'Session Template requires contentKind=sessionTemplate.',
      );
    }
  }

  static bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class TrainingContentInvariantException implements Exception {
  const TrainingContentInvariantException(this.message);

  final String message;

  @override
  String toString() => message;
}
