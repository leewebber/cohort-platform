part of 'performance_tracking.dart';

enum TrackingUnit {
  milliseconds,
  seconds,
  metres,
  kilometres,
  kilograms,
  count,
  secondsPerKilometre,
}

enum TrackingMethodKind { fieldExtraction, difference }

enum TrackingSourceKind { manualEntry, historyResult, assessmentAttempt }

enum TrackingProfileKind { curated, custom }

enum TrackingView { latest, history }

enum TrackingSelectionAction { select, revise, upgrade, deselect }

enum TrackingTimePrecision { timestamp, civilDate, unknown }

enum TrackingEvidenceState {
  available,
  missing,
  partial,
  skipped,
  unavailable,
  ineligible,
  incomparable,
}

/// A declaration of evidence quality, not a calculation or eligibility grant.
class TrackingEvidence {
  const TrackingEvidence({
    required this.state,
    this.reason,
    this.recordedCount,
    this.requiredCount,
  });

  final TrackingEvidenceState state;
  final String? reason;
  final int? recordedCount;
  final int? requiredCount;

  Map<String, Object?> toJson() => {
    'state': state.name,
    if (reason != null) 'reason': reason,
    if (recordedCount != null) 'recorded_count': recordedCount,
    if (requiredCount != null) 'required_count': requiredCount,
  };
}

/// An exact immutable content reference, never a request for "latest".
class TrackingReference {
  const TrackingReference({
    required this.id,
    required this.version,
    required this.digest,
  });

  final String id;
  final int version;
  final String digest;

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'digest': digest,
  };
}

/// Schema 1 refers to the tracking artifact format, not Plan Package schema.
sealed class TrackingArtifact {
  const TrackingArtifact({required this.id, required this.version});

  final String id;
  final int version;
  String get artifactKind;
  Map<String, Object?> get content;

  Map<String, Object?> toJson() => {
    'schema_version': 1,
    'artifact_kind': artifactKind,
    'id': id,
    'version': version,
    ...content,
  };

  String get canonicalJson => TrackingCodec.encode(this);
  String get digest => sha256.convert(utf8.encode(canonicalJson)).toString();
  TrackingReference get reference =>
      TrackingReference(id: id, version: version, digest: digest);
}

/// Supported method signature, not executable code or an arbitrary formula.
final class TrackingMethodDefinition extends TrackingArtifact {
  TrackingMethodDefinition({
    required super.id,
    required super.version,
    required this.kind,
    required List<TrackingUnit> inputUnits,
    required this.outputUnit,
  }) : inputUnits = List.unmodifiable(inputUnits);

  final TrackingMethodKind kind;
  final List<TrackingUnit> inputUnits;
  final TrackingUnit outputUnit;

  @override
  String get artifactKind => 'method';
  @override
  Map<String, Object?> get content => {
    'kind': kind.name,
    'input_units': inputUnits.map((unit) => unit.name).toList(),
    'output_unit': outputUnit.name,
  };
}

final class TrackingMetricDefinition extends TrackingArtifact {
  TrackingMetricDefinition({
    required super.id,
    required super.version,
    required this.label,
    required this.unit,
    required this.method,
    required List<TrackingSourceKind> allowedSources,
    required this.captureField,
    List<String> requiredContext = const [],
    this.requiresAssessment = false,
    this.allowPartial = false,
    this.freshnessCivilDays,
  }) : allowedSources = List.unmodifiable(allowedSources),
       requiredContext = List.unmodifiable(requiredContext);

  final String label;
  final TrackingUnit unit;
  final TrackingReference method;
  final List<TrackingSourceKind> allowedSources;
  final String captureField;
  final List<String> requiredContext;
  final bool requiresAssessment;
  final bool allowPartial;
  final int? freshnessCivilDays;

  @override
  String get artifactKind => 'metric';
  @override
  Map<String, Object?> get content => {
    'label': label,
    'unit': unit.name,
    'method': method.toJson(),
    'allowed_sources': allowedSources.map((s) => s.name).toList()..sort(),
    'capture_field': captureField,
    'required_context': [...requiredContext]..sort(),
    'requires_assessment': requiresAssessment,
    'allow_partial': allowPartial,
    // Null explicitly means no freshness limit; no default is inferred.
    'freshness_civil_days': freshnessCivilDays,
  };
}

final class TrackingProfile extends TrackingArtifact {
  TrackingProfile({
    required super.id,
    required super.version,
    required this.kind,
    required this.name,
    required List<TrackingReference> metrics,
    this.athleteId,
    this.previous,
    this.view = TrackingView.history,
  }) : metrics = List.unmodifiable(metrics);

  final TrackingProfileKind kind;
  final String name;
  final List<TrackingReference> metrics;
  final String? athleteId;
  final TrackingReference? previous;
  final TrackingView view;

  @override
  String get artifactKind => 'profile';
  @override
  Map<String, Object?> get content => {
    'kind': kind.name,
    'name': name,
    // Authored display order is meaningful; never sort it by ID.
    'metrics': metrics.map((m) => m.toJson()).toList(),
    if (athleteId != null) 'athlete_id': athleteId,
    if (previous != null) 'previous': previous!.toJson(),
    'view': view.name,
  };
}

final class TrackingSelectionRevision extends TrackingArtifact {
  const TrackingSelectionRevision({
    required super.id,
    required super.version,
    required this.athleteId,
    required this.action,
    required this.profile,
    required this.recordedAt,
    this.previous,
    this.programmeBinding,
  });

  final String athleteId;
  final TrackingSelectionAction action;
  final TrackingReference profile;
  final DateTime recordedAt;
  final TrackingReference? previous;
  final TrackingReference? programmeBinding;

  @override
  String get artifactKind => 'selection';
  @override
  Map<String, Object?> get content => {
    'athlete_id': athleteId,
    'action': action.name,
    'profile': profile.toJson(),
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    if (previous != null) 'previous': previous!.toJson(),
    if (programmeBinding != null)
      'programme_binding': programmeBinding!.toJson(),
  };
}

/// Pure procedure reference contract. No exercise prescriptions or test engine.
final class TrackingAssessmentDefinition extends TrackingArtifact {
  TrackingAssessmentDefinition({
    required super.id,
    required super.version,
    required this.procedureDigest,
    required List<TrackingReference> metrics,
  }) : metrics = List.unmodifiable(metrics);

  final String procedureDigest;
  final List<TrackingReference> metrics;

  @override
  String get artifactKind => 'assessment';
  @override
  Map<String, Object?> get content => {
    'procedure_digest': procedureDigest,
    'metrics': metrics.map((m) => m.toJson()).toList(),
  };
}

/// Declared exact scope. C1 does not attest that hosted content exists.
class TrackingProgrammeScope {
  const TrackingProgrammeScope({
    required this.programmeVersionId,
    required this.packageHash,
    required this.slotKey,
    required this.protocolId,
    required this.protocolRevision,
    required this.blockId,
    this.workoutId,
    this.stepId,
    this.repeatOrdinal,
    this.mappingHash,
  });

  final String programmeVersionId;
  final String packageHash;
  final String slotKey;
  final String protocolId;
  final int protocolRevision;
  final String blockId;
  final String? workoutId;
  final String? stepId;
  final int? repeatOrdinal;
  final String? mappingHash;

  Map<String, Object?> toJson() => {
    'programme_version_id': programmeVersionId,
    'package_hash': packageHash,
    'slot_key': slotKey,
    'protocol_id': protocolId,
    'protocol_revision': protocolRevision,
    'block_id': blockId,
    if (workoutId != null) 'workout_id': workoutId,
    if (stepId != null) 'step_id': stepId,
    if (repeatOrdinal != null) 'repeat_ordinal': repeatOrdinal,
    if (mappingHash != null) 'mapping_hash': mappingHash,
  };
}

class TrackingAssessmentScope {
  const TrackingAssessmentScope({
    required this.assessment,
    required this.window,
    required this.scope,
  });

  final TrackingReference assessment;
  final String window;
  final TrackingProgrammeScope scope;

  Map<String, Object?> toJson() => {
    'assessment': assessment.toJson(),
    'window': window,
    'scope': scope.toJson(),
  };
}

/// Future optional authored binding, independent of all Plan Package code.
final class TrackingProgrammeBinding extends TrackingArtifact {
  TrackingProgrammeBinding({
    required super.id,
    required super.version,
    required this.programmeVersionId,
    required this.packageHash,
    required this.profile,
    List<TrackingAssessmentScope> assessmentScopes = const [],
  }) : assessmentScopes = List.unmodifiable(assessmentScopes);

  final String programmeVersionId;
  final String packageHash;
  final TrackingReference profile;
  final List<TrackingAssessmentScope> assessmentScopes;

  @override
  String get artifactKind => 'programme_binding';
  @override
  Map<String, Object?> get content => {
    'programme_version_id': programmeVersionId,
    'package_hash': packageHash,
    'profile': profile.toJson(),
    'assessment_scopes': assessmentScopes.map((s) => s.toJson()).toList(),
  };
}

/// Exact History field identity; positions/names are not result identity.
class TrackingHistorySource {
  TrackingHistorySource({
    required this.recordId,
    required this.blockResultId,
    required this.sourceBlockId,
    required List<String> fieldPath,
    required this.inputDigest,
    this.exerciseResultId,
    this.setResultId,
    this.correctionId,
    this.workoutId,
    this.stepId,
    this.repeatOrdinal,
  }) : fieldPath = List.unmodifiable(fieldPath);

  final String recordId;
  final String blockResultId;
  final String sourceBlockId;
  final List<String> fieldPath;
  final String inputDigest;
  final String? exerciseResultId;
  final String? setResultId;

  /// Existing performance_result_corrections identity, not a replay guarantee.
  final String? correctionId;
  final String? workoutId;
  final String? stepId;
  final int? repeatOrdinal;

  /// C1 never claims an as-of reconstruction from a mutable source reference.
  bool get canReconstructHistoricalInputs => false;

  Map<String, Object?> toJson() => {
    'record_id': recordId,
    'block_result_id': blockResultId,
    'source_block_id': sourceBlockId,
    'field_path': fieldPath,
    'input_digest': inputDigest,
    'historical_inputs': 'unavailable',
    if (exerciseResultId != null) 'exercise_result_id': exerciseResultId,
    if (setResultId != null) 'set_result_id': setResultId,
    if (correctionId != null) 'correction_id': correctionId,
    if (workoutId != null) 'workout_id': workoutId,
    if (stepId != null) 'step_id': stepId,
    if (repeatOrdinal != null) 'repeat_ordinal': repeatOrdinal,
  };
}

class TrackingMeasurementSource {
  const TrackingMeasurementSource({
    required this.kind,
    required this.sourceId,
    this.history,
    this.assessment,
    this.attemptId,
    this.programmeScope,
    this.assignmentId,
    this.occurrenceId,
    this.trainingSessionId,
  });

  final TrackingSourceKind kind;
  final String sourceId;
  final TrackingHistorySource? history;
  final TrackingReference? assessment;
  final String? attemptId;
  final TrackingProgrammeScope? programmeScope;
  final String? assignmentId;
  final String? occurrenceId;
  final String? trainingSessionId;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'source_id': sourceId,
    if (history != null) 'history': history!.toJson(),
    if (assessment != null) 'assessment': assessment!.toJson(),
    if (attemptId != null) 'attempt_id': attemptId,
    if (programmeScope != null) 'programme_scope': programmeScope!.toJson(),
    if (assignmentId != null) 'assignment_id': assignmentId,
    if (occurrenceId != null) 'occurrence_id': occurrenceId,
    if (trainingSessionId != null) 'training_session_id': trainingSessionId,
  };
}

class TrackingChronology {
  const TrackingChronology({
    required this.precision,
    required this.recordedAt,
    this.performedAt,
    this.performedOn,
    this.timezone,
  });

  final TrackingTimePrecision precision;
  final DateTime recordedAt;
  final DateTime? performedAt;
  final String? performedOn;

  /// Civil-date records require an IANA zone, verified against caller zone IDs.
  final String? timezone;

  Map<String, Object?> toJson() => {
    'precision': precision.name,
    'recorded_at': recordedAt.toUtc().toIso8601String(),
    if (performedAt != null)
      'performed_at': performedAt!.toUtc().toIso8601String(),
    if (performedOn != null) 'performed_on': performedOn,
    if (timezone != null) 'timezone': timezone,
  };
}

final class TrackingMeasurementRevision extends TrackingArtifact {
  TrackingMeasurementRevision({
    required super.id,
    required super.version,
    required this.athleteId,
    required this.metric,
    required this.unit,
    required this.source,
    required this.chronology,
    required this.evidence,
    required this.provenance,
    Map<String, String> context = const {},
    this.canonicalValue,
    this.previous,
    this.correctionReason,
  }) : context = Map.unmodifiable(context);

  final String athleteId;
  final TrackingReference metric;
  final TrackingUnit unit;
  final TrackingMeasurementSource source;
  final TrackingChronology chronology;
  final TrackingEvidence evidence;
  final String provenance;
  final Map<String, String> context;

  /// Manual observation only: canonical decimal string, never a copied actual.
  final String? canonicalValue;
  final TrackingReference? previous;
  final String? correctionReason;

  /// Structural tracking validity can never become prescription eligibility.
  bool get grantsPrescriptionEligibility => false;

  @override
  String get artifactKind => 'measurement';
  @override
  Map<String, Object?> get content => {
    'athlete_id': athleteId,
    'metric': metric.toJson(),
    'unit': unit.name,
    'source': source.toJson(),
    'chronology': chronology.toJson(),
    'evidence': evidence.toJson(),
    'provenance': provenance,
    'context': context,
    if (canonicalValue != null) 'canonical_value': canonicalValue,
    if (previous != null) 'previous': previous!.toJson(),
    if (correctionReason != null) 'correction_reason': correctionReason,
  };
}
