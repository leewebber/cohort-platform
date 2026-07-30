import 'protocol_draft.dart';
import 'training_content_classification.dart';

/// Typed edit / attach permissions for training content.
///
/// Enforced by coordinators and pickers — not by UI labels alone.
class TrainingContentEditPolicy {
  const TrainingContentEditPolicy();

  /// Cohort Protocols are product-owned and never edited in place.
  bool canEditInPlace(
    ProtocolDraft draft, {
    required String? coachId,
    String? programmeVersionId,
  }) {
    if (TrainingContentClassification.isCohortProtocol(draft)) {
      return false;
    }
    if (TrainingContentClassification.isSessionTemplate(draft)) {
      return false;
    }
    if (TrainingContentClassification.isProgrammeOnlySession(draft)) {
      final boundVersion = draft.programmeVersionId?.trim();
      final expected = programmeVersionId?.trim();
      if (boundVersion == null || boundVersion.isEmpty) return false;
      if (expected != null && expected.isNotEmpty && boundVersion != expected) {
        return false;
      }
      return true;
    }
    if (TrainingContentClassification.isReusableCoachSession(draft)) {
      final owner = draft.ownerId?.trim();
      final actor = coachId?.trim();
      if (owner == null || owner.isEmpty) return false;
      if (actor == null || actor.isEmpty) return false;
      return owner == actor;
    }
    // Legacy / unclassified — never treat as editable Cohort content.
    return false;
  }

  /// Live reference attach is allowed only for the coach's published My Sessions.
  bool canAttachAsLiveReference(
    ProtocolDraft draft, {
    required String? coachId,
  }) {
    if (!TrainingContentClassification.isReusableCoachSession(draft)) {
      return false;
    }
    if (draft.published != true) return false;
    if (draft.programmeVersionId?.trim().isNotEmpty == true) return false;
    final owner = draft.ownerId?.trim();
    final actor = coachId?.trim();
    if (owner == null || owner.isEmpty) return false;
    if (actor != null && actor.isNotEmpty && owner != actor) return false;
    return true;
  }

  /// Templates are copy-on-use sources only.
  bool canUseAsTemplateSource(ProtocolDraft draft) {
    return TrainingContentClassification.isSessionTemplate(draft);
  }

  bool isReadOnlyCohortProtocol(ProtocolDraft draft) {
    return TrainingContentClassification.isCohortProtocol(draft);
  }

  /// Whether customising requires a coach-owned derivative (never in-place edit).
  bool requiresCoachOwnedCopy(ProtocolDraft draft) {
    return isReadOnlyCohortProtocol(draft) ||
        TrainingContentClassification.isSessionTemplate(draft);
  }

  /// Whether [draft] is an official Cohort catalogue template eligible for
  /// Preview / Use Template.
  bool isCanonicalTemplateSource(ProtocolDraft draft) {
    return TrainingContentClassification.isCanonicalSessionTemplate(draft);
  }
}
