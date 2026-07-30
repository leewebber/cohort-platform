import '../../models/programme_vocabulary.dart';
import '../adaptation/services/adaptation_policy_gate.dart';

/// Validated Authored Plan Package manifest (package schema v1).
///
/// Distinguishes:
/// - [packageSchemaVersion] — interchange schema
/// - [programme.lineageCode] — stable programme identity ([ProgrammeLineage.code])
/// - [programme.versionNumber] — immutable programme version descriptor
/// - session [PlanPackageSessionRevisionRef] — Session Revision identity
/// - schedule + progression — authored programme truth
///
/// Does **not** contain athlete enrolment, execution evidence, or builder state.
class PlanPackageManifest {
  const PlanPackageManifest({
    required this.packageSchemaVersion,
    required this.programme,
    required this.sessions,
    required this.phases,
    required this.weeks,
    required this.adaptationPermissions,
    required this.protectedInvariants,
    required this.assessments,
    required this.performanceEvidenceRequirements,
    required this.comparisonIdentities,
  });

  final int packageSchemaVersion;
  final PlanPackageProgrammeIdentity programme;
  final List<PlanPackageSessionRevisionRef> sessions;
  final List<PlanPackagePhase> phases;
  final List<PlanPackageWeek> weeks;
  final List<PlanPackageAdaptationPermission> adaptationPermissions;
  final List<PlanPackageProtectedInvariant> protectedInvariants;
  final List<PlanPackageAssessment> assessments;
  final List<PlanPackageEvidenceRequirement> performanceEvidenceRequirements;
  final List<PlanPackageComparisonIdentity> comparisonIdentities;
}

/// Stable + versioned programme identity and authored metadata.
class PlanPackageProgrammeIdentity {
  const PlanPackageProgrammeIdentity({
    required this.lineageCode,
    required this.versionNumber,
    required this.name,
    required this.libraryScope,
    required this.ownerType,
    required this.coachingIntent,
    this.description,
    this.durationWeeks,
    this.sessionsPerWeek,
    this.primaryGoal,
  });

  /// Stable programme identity — maps to [ProgrammeLineage.code].
  final String lineageCode;

  /// Immutable programme version number within the lineage.
  final int versionNumber;

  final String name;
  final String? description;
  final ProgrammeLibraryScope libraryScope;
  final ProgrammeOwnerType ownerType;
  final String coachingIntent;
  final int? durationWeeks;
  final int? sessionsPerWeek;
  final String? primaryGoal;
}

/// Immutable Session Revision reference declared in the package catalogue.
///
/// [protocolId] is the exact Session Revision row identity.
/// [sessionLineageId] + [revisionNumber] make versioning explicit.
class PlanPackageSessionRevisionRef {
  const PlanPackageSessionRevisionRef({
    required this.sessionKey,
    required this.protocolId,
    required this.sessionLineageId,
    required this.revisionNumber,
    required this.title,
  });

  /// Package-local stable key used by schedule slots.
  final String sessionKey;

  /// Exact Session Revision identity (`performance_protocols.protocol_id`).
  final String protocolId;

  /// Stable session lineage across revisions.
  final String sessionLineageId;

  /// Explicit revision number within the lineage.
  final int revisionNumber;

  final String title;
}

class PlanPackagePhase {
  const PlanPackagePhase({
    required this.phaseKey,
    required this.phaseOrder,
    required this.title,
    this.intent,
    this.coachNote,
  });

  final String phaseKey;
  final int phaseOrder;
  final String title;
  final ProgrammeIntent? intent;
  final String? coachNote;
}

class PlanPackageWeek {
  const PlanPackageWeek({
    required this.weekNumber,
    required this.days,
    this.phaseKey,
    this.title,
    this.intent,
    this.coachNote,
  });

  final int weekNumber;
  final String? phaseKey;
  final String? title;
  final ProgrammeIntent? intent;
  final String? coachNote;
  final List<PlanPackageDay> days;
}

class PlanPackageDay {
  const PlanPackageDay({
    required this.dayKey,
    required this.dayOrder,
    required this.dayType,
    required this.slots,
    this.title,
    this.intent,
    this.coachNote,
  });

  final String dayKey;
  final int dayOrder;
  final ProgrammeDayType dayType;
  final String? title;
  final ProgrammeIntent? intent;
  final String? coachNote;
  final List<PlanPackageSessionSlot> slots;
}

class PlanPackageSessionSlot {
  const PlanPackageSessionSlot({
    required this.slotKey,
    required this.sessionOrder,
    required this.sessionKey,
    required this.progression,
    this.timeOfDay = ProgrammeSessionTimeOfDay.any,
    this.isOptional = false,
    this.completionExpectation = ProgrammeSessionCompletionExpectation.required,
    this.displayTitle,
    this.coachNote,
  });

  final String slotKey;
  final int sessionOrder;

  /// References [PlanPackageSessionRevisionRef.sessionKey].
  final String sessionKey;

  /// Authored progression for this scheduled occurrence (programme truth).
  final PlanPackageAuthoredProgression progression;

  final ProgrammeSessionTimeOfDay timeOfDay;
  final bool isOptional;
  final ProgrammeSessionCompletionExpectation completionExpectation;
  final String? displayTitle;
  final String? coachNote;
}

/// Authored progression already contained in the programme — not invented.
class PlanPackageAuthoredProgression {
  const PlanPackageAuthoredProgression({
    required this.prescriptionSummary,
    this.volumeNote,
    this.intensityNote,
    this.coachNote,
  });

  final String prescriptionSummary;
  final String? volumeNote;
  final String? intensityNote;
  final String? coachNote;
}

class PlanPackageAdaptationPermission {
  const PlanPackageAdaptationPermission({
    required this.id,
    required this.changeKind,
    required this.targetRef,
    required this.athleteAgreementRequired,
    this.scopeNote,
  });

  final String id;
  final AdaptationChangeKind changeKind;

  /// Slot key, assessment id, or `programme` for programme-wide permission.
  final String targetRef;

  /// Locked product rule: adaptations require athlete agreement.
  final bool athleteAgreementRequired;
  final String? scopeNote;
}

class PlanPackageProtectedInvariant {
  const PlanPackageProtectedInvariant({
    required this.id,
    required this.kind,
    required this.targetRef,
    required this.description,
  });

  final String id;
  final PlanPackageInvariantKind kind;
  final String targetRef;
  final String description;
}

enum PlanPackageInvariantKind {
  sessionSlotImmutable,
  assessmentImmutable,
  progressionLocked,
}

class PlanPackageAssessment {
  const PlanPackageAssessment({
    required this.id,
    required this.slotRef,
    required this.evidenceRequirement,
    required this.comparisonIdentityId,
    this.label,
  });

  final String id;
  final String slotRef;
  final String evidenceRequirement;
  final String comparisonIdentityId;
  final String? label;
}

class PlanPackageEvidenceRequirement {
  const PlanPackageEvidenceRequirement({
    required this.id,
    required this.comparisonIdentityId,
    required this.metric,
    required this.required,
  });

  final String id;
  final String comparisonIdentityId;
  final String metric;
  final bool required;
}

/// Like-for-like progress comparison identity (descriptive, not prescriptive).
class PlanPackageComparisonIdentity {
  const PlanPackageComparisonIdentity({
    required this.id,
    required this.sessionLineageId,
    required this.label,
  });

  final String id;

  /// Anchors comparison to a stable session lineage across weeks/versions.
  final String sessionLineageId;
  final String label;
}

extension PlanPackageInvariantKindYaml on PlanPackageInvariantKind {
  String get yamlValue {
    return switch (this) {
      PlanPackageInvariantKind.sessionSlotImmutable => 'session_slot_immutable',
      PlanPackageInvariantKind.assessmentImmutable => 'assessment_immutable',
      PlanPackageInvariantKind.progressionLocked => 'progression_locked',
    };
  }

  static PlanPackageInvariantKind? fromYaml(String? raw) {
    return switch (raw?.trim()) {
      'session_slot_immutable' => PlanPackageInvariantKind.sessionSlotImmutable,
      'assessment_immutable' => PlanPackageInvariantKind.assessmentImmutable,
      'progression_locked' => PlanPackageInvariantKind.progressionLocked,
      _ => null,
    };
  }
}
