/// Derived, non-authoritative Programme Studio review model.
///
/// Not a publication input. Canonical programme meaning remains Plan Package
/// compile output plus committed protocol artifacts.
library;

enum ProgrammeReviewClassification {
  productionPublished,
  internalPersonal,
  internalPrivate,
  legacyWithheld,
  fixtureTestExample,
  plannedFamily,
}

enum ProgrammeReviewFindingSeverity { error, warning, info }

enum ProgrammeReviewCheckStatus {
  passed,
  failed,
  notImplemented,
  notAssessed,
}

enum ProgrammeReviewCompileState { valid, invalid, notCompiled }

class ProgrammeReviewFinding {
  const ProgrammeReviewFinding({
    required this.code,
    required this.severity,
    required this.message,
    this.sourceContext,
  });

  final String code;
  final ProgrammeReviewFindingSeverity severity;
  final String message;
  final String? sourceContext;

  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity.name,
    'message': message,
    if (sourceContext != null) 'source_context': sourceContext,
  };
}

class ProgrammeReviewCheck {
  const ProgrammeReviewCheck({
    required this.id,
    required this.label,
    required this.status,
    required this.detail,
  });

  final String id;
  final String label;
  final ProgrammeReviewCheckStatus status;
  final String detail;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'status': status.name,
    'detail': detail,
  };
}

class ProgrammeReviewMovement {
  const ProgrammeReviewMovement({
    required this.position,
    required this.name,
    this.exerciseId,
    this.sets,
    this.reps,
    this.duration,
    this.distance,
    this.recovery,
    this.notes,
    this.rawPrescription,
    this.unsupportedReason,
  });

  final int position;
  final String name;
  final String? exerciseId;
  final String? sets;
  final String? reps;
  final String? duration;
  final String? distance;
  final String? recovery;
  final String? notes;
  final String? rawPrescription;
  final String? unsupportedReason;

  Map<String, Object?> toJson() => {
    'position': position,
    'name': name,
    if (exerciseId != null) 'exercise_id': exerciseId,
    if (sets != null) 'sets': sets,
    if (reps != null) 'reps': reps,
    if (duration != null) 'duration': duration,
    if (distance != null) 'distance': distance,
    if (recovery != null) 'recovery': recovery,
    if (notes != null) 'notes': notes,
    if (rawPrescription != null) 'raw_prescription': rawPrescription,
    if (unsupportedReason != null) 'unsupported_reason': unsupportedReason,
  };
}

class ProgrammeReviewBlock {
  const ProgrammeReviewBlock({
    required this.position,
    required this.title,
    required this.blockType,
    required this.sourceIdentity,
    this.trainingIntent,
    this.content,
    this.workoutFormat,
    this.timerConfiguration,
    this.coachNotes,
    this.movements = const [],
    this.unsupportedReason,
    this.omissionForbidden = true,
  });

  final int position;
  final String title;
  final String blockType;
  final String sourceIdentity;
  final String? trainingIntent;
  final String? content;
  final String? workoutFormat;
  final String? timerConfiguration;
  final String? coachNotes;
  final List<ProgrammeReviewMovement> movements;
  final String? unsupportedReason;
  final bool omissionForbidden;

  Map<String, Object?> toJson() => {
    'position': position,
    'title': title,
    'block_type': blockType,
    'source_identity': sourceIdentity,
    if (trainingIntent != null) 'training_intent': trainingIntent,
    if (content != null) 'content': content,
    if (workoutFormat != null) 'workout_format': workoutFormat,
    if (timerConfiguration != null) 'timer_configuration': timerConfiguration,
    if (coachNotes != null) 'coach_notes': coachNotes,
    'movements': movements.map((item) => item.toJson()).toList(growable: false),
    if (unsupportedReason != null) 'unsupported_reason': unsupportedReason,
    'omission_forbidden': omissionForbidden,
  };
}

class ProgrammeReviewSession {
  const ProgrammeReviewSession({
    required this.sessionKey,
    required this.protocolId,
    required this.sessionLineageId,
    required this.revisionNumber,
    required this.title,
    required this.bodiesResolved,
    this.displayTitle,
    this.coachNote,
    this.prescriptionSummary,
    this.slotKey,
    this.sessionOrder = 1,
    this.dayType,
    this.timeOfDay,
    this.isOptional = false,
    this.completionExpectation,
    this.blocks = const [],
    this.findings = const [],
  });

  final String sessionKey;
  final String protocolId;
  final String sessionLineageId;
  final int revisionNumber;
  final String title;
  final bool bodiesResolved;
  final String? displayTitle;
  final String? coachNote;
  final String? prescriptionSummary;
  final String? slotKey;
  final int sessionOrder;
  final String? dayType;
  final String? timeOfDay;
  final bool isOptional;
  final String? completionExpectation;
  final List<ProgrammeReviewBlock> blocks;
  final List<ProgrammeReviewFinding> findings;

  Map<String, Object?> toJson() => {
    'session_key': sessionKey,
    'protocol_id': protocolId,
    'session_lineage_id': sessionLineageId,
    'revision_number': revisionNumber,
    'title': title,
    'bodies_resolved': bodiesResolved,
    if (displayTitle != null) 'display_title': displayTitle,
    if (coachNote != null) 'coach_note': coachNote,
    if (prescriptionSummary != null) 'prescription_summary': prescriptionSummary,
    if (slotKey != null) 'slot_key': slotKey,
    'session_order': sessionOrder,
    if (dayType != null) 'day_type': dayType,
    if (timeOfDay != null) 'time_of_day': timeOfDay,
    'is_optional': isOptional,
    if (completionExpectation != null)
      'completion_expectation': completionExpectation,
    'blocks': blocks.map((item) => item.toJson()).toList(growable: false),
    'findings': findings.map((item) => item.toJson()).toList(growable: false),
  };
}

class ProgrammeReviewDay {
  const ProgrammeReviewDay({
    required this.dayKey,
    required this.dayOrder,
    required this.dayType,
    required this.sessions,
    this.title,
    this.intent,
    this.coachNote,
  });

  final String dayKey;
  final int dayOrder;
  final String dayType;
  final String? title;
  final String? intent;
  final String? coachNote;
  final List<ProgrammeReviewSession> sessions;

  Map<String, Object?> toJson() => {
    'day_key': dayKey,
    'day_order': dayOrder,
    'day_type': dayType,
    if (title != null) 'title': title,
    if (intent != null) 'intent': intent,
    if (coachNote != null) 'coach_note': coachNote,
    'sessions': sessions.map((item) => item.toJson()).toList(growable: false),
  };
}

class ProgrammeReviewWeek {
  const ProgrammeReviewWeek({
    required this.weekNumber,
    required this.days,
    this.title,
    this.phaseKey,
    this.intent,
    this.coachNote,
  });

  final int weekNumber;
  final String? title;
  final String? phaseKey;
  final String? intent;
  final String? coachNote;
  final List<ProgrammeReviewDay> days;

  Map<String, Object?> toJson() => {
    'week_number': weekNumber,
    if (title != null) 'title': title,
    if (phaseKey != null) 'phase_key': phaseKey,
    if (intent != null) 'intent': intent,
    if (coachNote != null) 'coach_note': coachNote,
    'days': days.map((item) => item.toJson()).toList(growable: false),
  };
}

class ProgrammeReviewCompileReport {
  const ProgrammeReviewCompileReport({
    required this.parseOk,
    required this.validationOk,
    required this.canonicalisationOk,
    required this.state,
    this.contentHashSha256,
    this.issues = const [],
  });

  final bool parseOk;
  final bool validationOk;
  final bool canonicalisationOk;
  final ProgrammeReviewCompileState state;
  final String? contentHashSha256;
  final List<ProgrammeReviewFinding> issues;

  Map<String, Object?> toJson() => {
    'parse_ok': parseOk,
    'validation_ok': validationOk,
    'canonicalisation_ok': canonicalisationOk,
    'state': state.name,
    if (contentHashSha256 != null) 'content_hash_sha256': contentHashSha256,
    'issues': issues.map((item) => item.toJson()).toList(growable: false),
  };
}

class ProgrammeReviewPublicationEvidence {
  const ProgrammeReviewPublicationEvidence({
    required this.establishedLocally,
    this.programmeVersionId,
    this.sourcePackageHash,
    this.artifactPath,
    this.detail,
  });

  final bool establishedLocally;
  final String? programmeVersionId;
  final String? sourcePackageHash;
  final String? artifactPath;
  final String? detail;

  Map<String, Object?> toJson() => {
    'established_locally': establishedLocally,
    if (programmeVersionId != null) 'programme_version_id': programmeVersionId,
    if (sourcePackageHash != null) 'source_package_hash': sourcePackageHash,
    if (artifactPath != null) 'artifact_path': artifactPath,
    if (detail != null) 'detail': detail,
  };
}

class ProgrammeReviewProgramme {
  const ProgrammeReviewProgramme({
    required this.catalogId,
    required this.classification,
    required this.title,
    required this.lineageCode,
    required this.versionNumber,
    required this.sourcePaths,
    required this.compile,
    required this.publication,
    required this.readiness,
    required this.findings,
    this.programmeVersionId,
    this.description,
    this.coachingIntent,
    this.primaryGoal,
    this.durationWeeks,
    this.sessionsPerWeek,
    this.intendedLevel,
    this.equipment,
    this.libraryScope,
    this.scheduledWeekCount,
    this.weeks = const [],
    this.assessments = const [],
    this.evidenceRequirements = const [],
    this.comparisonIdentities = const [],
    this.comparableVersionIds = const [],
  });

  final String catalogId;
  final ProgrammeReviewClassification classification;
  final String title;
  final String lineageCode;
  final int versionNumber;
  final String? programmeVersionId;
  final List<String> sourcePaths;
  final String? description;
  final String? coachingIntent;
  final String? primaryGoal;
  final int? durationWeeks;
  final int? sessionsPerWeek;
  final String? intendedLevel;
  final String? equipment;
  final String? libraryScope;
  final int? scheduledWeekCount;
  final ProgrammeReviewCompileReport compile;
  final ProgrammeReviewPublicationEvidence publication;
  final List<ProgrammeReviewWeek> weeks;
  final List<Map<String, Object?>> assessments;
  final List<Map<String, Object?>> evidenceRequirements;
  final List<Map<String, Object?>> comparisonIdentities;
  final List<String> comparableVersionIds;
  final List<ProgrammeReviewCheck> readiness;
  final List<ProgrammeReviewFinding> findings;

  bool get isRealInventoryItem =>
      classification == ProgrammeReviewClassification.internalPersonal ||
      classification == ProgrammeReviewClassification.internalPrivate ||
      classification == ProgrammeReviewClassification.legacyWithheld ||
      classification == ProgrammeReviewClassification.productionPublished;

  Map<String, Object?> toJson() => {
    'catalog_id': catalogId,
    'classification': classification.name,
    'title': title,
    'lineage_code': lineageCode,
    'version_number': versionNumber,
    if (programmeVersionId != null) 'programme_version_id': programmeVersionId,
    'source_paths': sourcePaths,
    if (description != null) 'description': description,
    if (coachingIntent != null) 'coaching_intent': coachingIntent,
    if (primaryGoal != null) 'primary_goal': primaryGoal,
    if (durationWeeks != null) 'duration_weeks': durationWeeks,
    if (sessionsPerWeek != null) 'sessions_per_week': sessionsPerWeek,
    if (intendedLevel != null) 'intended_level': intendedLevel,
    if (equipment != null) 'equipment': equipment,
    if (libraryScope != null) 'library_scope': libraryScope,
    if (scheduledWeekCount != null) 'scheduled_week_count': scheduledWeekCount,
    'compile': compile.toJson(),
    'publication': publication.toJson(),
    'weeks': weeks.map((item) => item.toJson()).toList(growable: false),
    'assessments': assessments,
    'evidence_requirements': evidenceRequirements,
    'comparison_identities': comparisonIdentities,
    'comparable_version_ids': comparableVersionIds,
    'readiness': readiness.map((item) => item.toJson()).toList(growable: false),
    'findings': findings.map((item) => item.toJson()).toList(growable: false),
  };
}

class ProgrammeReviewPlannedFamily {
  const ProgrammeReviewPlannedFamily({
    required this.id,
    required this.title,
    required this.durationWeeks,
    required this.intent,
    required this.buildOrder,
  });

  final String id;
  final String title;
  final int durationWeeks;
  final String intent;
  final int buildOrder;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'duration_weeks': durationWeeks,
    'intent': intent,
    'build_order': buildOrder,
    'sessions': const <Never>[],
    'weeks': const <Never>[],
    'metrics': const <Never>[],
  };
}

class ProgrammeReviewCatalog {
  const ProgrammeReviewCatalog({
    required this.authority,
    required this.sourceInputs,
    required this.programmes,
    required this.plannedFamilies,
    this.developerFixtures = const [],
  });

  final String authority;
  final List<String> sourceInputs;
  final List<ProgrammeReviewProgramme> programmes;
  final List<ProgrammeReviewPlannedFamily> plannedFamilies;
  final List<ProgrammeReviewProgramme> developerFixtures;

  static const derivedAuthority =
      'derived_non_authoritative_review_projection';

  List<ProgrammeReviewProgramme> realInventory({
    required bool includeFixtures,
  }) {
    final real = programmes.where((item) => item.isRealInventoryItem).toList()
      ..sort(_byTitle);
    if (!includeFixtures) {
      return List<ProgrammeReviewProgramme>.unmodifiable(real);
    }
    final fixtures = developerFixtures.toList()..sort(_byTitle);
    return List<ProgrammeReviewProgramme>.unmodifiable([...real, ...fixtures]);
  }

  Map<String, Object?> toJson() => {
    'authority': authority,
    'publication_input': false,
    'source_inputs': sourceInputs,
    'programmes': programmes.map((item) => item.toJson()).toList(growable: false),
    'planned_families': plannedFamilies
        .map((item) => item.toJson())
        .toList(growable: false),
    'developer_fixtures': developerFixtures
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  static int _byTitle(ProgrammeReviewProgramme a, ProgrammeReviewProgramme b) {
    final title = a.title.compareTo(b.title);
    if (title != 0) {
      return title;
    }
    return a.catalogId.compareTo(b.catalogId);
  }
}
