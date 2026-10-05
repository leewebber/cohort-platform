part of 'history_tracking_adapter.dart';

enum HistoryReadConsistency { unproven, singleStatementSnapshot }

/// A future authenticated reader must obtain the entire frame in one database
/// statement snapshot, without truncation or independently hydrated rows. C2
/// supplies no production implementation; marking a frame is a reader promise,
/// not a client-verifiable certificate. Existing getById does not qualify.
abstract interface class HistoryTrackingReadPort {
  String? get authenticatedAthleteId;
  Future<HistoryReadFrame> readCurrentRecord(
    String recordId, {
    HistoryProgrammeClaim? programmeClaim,
  });
}

/// Raw History rows are deliberately retained before permissive model parsers
/// can coerce malformed fields or supply default units/completion.
final class HistoryReadFrame {
  HistoryReadFrame({
    required this.athleteId,
    required this.consistency,
    required this.completeRecordTree,
    required this.completeAuditSet,
    required Map<String, Object?>? record,
    List<Map<String, Object?>> blocks = const [],
    List<Map<String, Object?>> exercises = const [],
    List<Map<String, Object?>> sets = const [],
    List<Map<String, Object?>> corrections = const [],
    this.programmeWitness,
  }) : record = record == null
           ? null
           : Map<String, Object?>.unmodifiable(_map(_freeze(record))),
       blocks = _rows(blocks),
       exercises = _rows(exercises),
       sets = _rows(sets),
       corrections = _rows(corrections);

  final String athleteId;
  final HistoryReadConsistency consistency;
  final bool completeRecordTree;
  final bool completeAuditSet;
  final Map<String, Object?>? record;
  final List<Map<String, Object?>> blocks;
  final List<Map<String, Object?>> exercises;
  final List<Map<String, Object?>> sets;
  final List<Map<String, Object?>> corrections;
  final HistoryProgrammeWitness? programmeWitness;

  static List<Map<String, Object?>> _rows(List<Map<String, Object?>> rows) =>
      List.unmodifiable(
        rows.map(
          (row) => Map<String, Object?>.unmodifiable(_map(_freeze(row))),
        ),
      );
}

/// Normalized output of a future coherent existing-authority join. Its reader
/// must verify assignment/version/hash/occurrence/outcome/session, immutable
/// authored slot/protocol/block and running mapping where declared. C2 only
/// checks the exact witness against the query and raw History parents; it does
/// not manufacture that authority from names, a snapshot label or a hash alone.
final class HistoryProgrammeWitness {
  const HistoryProgrammeWitness({
    required this.athleteId,
    required this.recordId,
    required this.assignmentId,
    required this.occurrenceId,
    required this.trainingSessionId,
    required this.scope,
  });
  final String athleteId;
  final String recordId;
  final String assignmentId;
  final String occurrenceId;
  final String trainingSessionId;
  final TrackingProgrammeScope scope;
}

final class HistoryProgrammeClaim {
  const HistoryProgrammeClaim({
    required this.assignmentId,
    required this.occurrenceId,
    required this.trainingSessionId,
    required this.scope,
  });
  final String assignmentId;
  final String occurrenceId;
  final String trainingSessionId;
  final TrackingProgrammeScope scope;
}

/// A first current read needs no guessed digest. A read from an existing C1
/// reference pins its input digest and optional audit ID and fails if stale.
final class HistoryFieldSelection {
  HistoryFieldSelection({
    required this.recordId,
    required this.blockResultId,
    required this.sourceBlockId,
    required List<String> fieldPath,
    this.exerciseResultId,
    this.setResultId,
    this.workoutId,
    this.stepId,
    this.repeatOrdinal,
    this.expectedInputDigest,
    this.expectedCorrectionId,
  }) : fieldPath = List.unmodifiable(fieldPath);

  factory HistoryFieldSelection.fromReference(TrackingHistorySource source) =>
      HistoryFieldSelection(
        recordId: source.recordId,
        blockResultId: source.blockResultId,
        sourceBlockId: source.sourceBlockId,
        fieldPath: source.fieldPath,
        exerciseResultId: source.exerciseResultId,
        setResultId: source.setResultId,
        workoutId: source.workoutId,
        stepId: source.stepId,
        repeatOrdinal: source.repeatOrdinal,
        expectedInputDigest: source.inputDigest,
        expectedCorrectionId: source.correctionId,
      );

  final String recordId;
  final String blockResultId;
  final String sourceBlockId;
  final List<String> fieldPath;
  final String? exerciseResultId;
  final String? setResultId;
  final String? workoutId;
  final String? stepId;
  final int? repeatOrdinal;
  final String? expectedInputDigest;
  final String? expectedCorrectionId;

  String get sourceIdentity => jsonEncode([
    recordId,
    blockResultId,
    sourceBlockId,
    exerciseResultId,
    setResultId,
    fieldPath,
    workoutId,
    stepId,
    repeatOrdinal,
  ]);
}

final class HistoryTrackingQuery {
  HistoryTrackingQuery({
    required this.athleteId,
    required this.metric,
    required this.field,
    this.programmeClaim,
    this.historical = false,
    Map<String, String> expectedContext = const {},
  }) : expectedContext = Map.unmodifiable(expectedContext);
  final String athleteId;
  final TrackingReference metric;
  final HistoryFieldSelection field;
  final HistoryProgrammeClaim? programmeClaim;
  final bool historical;
  final Map<String, String> expectedContext;
}

sealed class HistoryTrackingResult {
  const HistoryTrackingResult();
  bool get grantsPrescriptionEligibility => false;
  bool get canReconstructHistoricalInputs => false;
}

/// Query/identity/coherence errors are not successful empty observations.
final class HistoryTrackingFailure extends HistoryTrackingResult {
  const HistoryTrackingFailure(this.code);
  final String code;
}

final class HistoryTrackingAbsent extends HistoryTrackingResult {
  const HistoryTrackingAbsent(this.reason);
  final String reason;
  TrackingEvidence get evidence =>
      TrackingEvidence(state: TrackingEvidenceState.missing, reason: reason);
}

/// Ephemeral actual read projection, never a writable measurement artifact.
final class HistoryTrackingObservation extends HistoryTrackingResult {
  HistoryTrackingObservation({
    required this.source,
    required this.sourceIdentity,
    required this.evidence,
    required this.unit,
    required this.value,
    required Map<String, String> context,
    required Map<String, Object?> chronology,
    required List<String> correctionIds,
    required this.auditSetDigest,
  }) : context = Map.unmodifiable(context),
       chronology = Map.unmodifiable(chronology),
       correctionIds = List.unmodifiable(correctionIds);

  final TrackingHistorySource source;
  final String sourceIdentity;
  final TrackingEvidence evidence;
  final TrackingUnit? unit;
  final String? value;
  final Map<String, String> context;

  /// Original History event precision/date/time, with no invented civil zone,
  /// freshness grant or new entry time. Included in the selected-input digest.
  final Map<String, Object?> chronology;

  /// Complete audit membership in the coherent read, sorted by identity, not
  /// claimed commit order. source.correctionId is only the verified requested
  /// audit reference; no "latest" ID is inferred from corrected_at timestamps.
  final List<String> correctionIds;
  final String auditSetDigest;
  bool get trackingEligible =>
      evidence.state == TrackingEvidenceState.available && value != null;
}
