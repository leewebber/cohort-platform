import 'package:cohort_platform/domain/performance_tracking/performance_tracking.dart';

/// Synthetic contract evidence only: no real profile, athlete or test content.
class TrackingFixtures {
  static final time = DateTime.utc(2026, 1, 2, 12);
  static final earlier = DateTime.utc(2026, 1, 1, 12);
  static final digestA = List.filled(64, 'a').join();
  static final digestB = List.filled(64, 'b').join();

  static TrackingMethodDefinition method({int version = 1}) =>
      TrackingMethodDefinition(
        id: 'synthetic.field',
        version: version,
        kind: TrackingMethodKind.fieldExtraction,
        inputUnits: [TrackingUnit.seconds],
        outputUnit: TrackingUnit.seconds,
      );

  static TrackingMetricDefinition metric({int version = 1}) =>
      TrackingMetricDefinition(
        id: 'synthetic.duration',
        version: version,
        label: 'Synthetic observation $version',
        unit: TrackingUnit.seconds,
        method: method().reference,
        allowedSources: TrackingSourceKind.values,
        captureField: 'duration_seconds',
        requiredContext: ['setting'],
      );

  static TrackingProfile curated({int version = 1}) => TrackingProfile(
    id: 'synthetic.curated',
    version: version,
    kind: TrackingProfileKind.curated,
    name: 'SYNTHETIC ONLY $version',
    metrics: [metric().reference],
  );

  static TrackingProfile custom({
    int version = 1,
    TrackingReference? previous,
  }) => TrackingProfile(
    id: 'synthetic.custom',
    version: version,
    kind: TrackingProfileKind.custom,
    name: 'Synthetic composition $version',
    athleteId: 'synthetic.athlete',
    metrics: [metric().reference],
    previous: previous,
  );

  static TrackingAssessmentDefinition assessment() =>
      TrackingAssessmentDefinition(
        id: 'synthetic.assessment',
        version: 1,
        procedureDigest: digestA,
        metrics: [metric().reference],
      );

  static TrackingProgrammeScope scope() => TrackingProgrammeScope(
    programmeVersionId: 'synthetic.programme-version',
    packageHash: digestA,
    slotKey: 'synthetic.slot',
    protocolId: 'synthetic.protocol',
    protocolRevision: 1,
    blockId: 'synthetic.block',
  );

  static TrackingProgrammeBinding binding() => TrackingProgrammeBinding(
    id: 'synthetic.binding',
    version: 1,
    programmeVersionId: scope().programmeVersionId,
    packageHash: digestA,
    profile: curated().reference,
    assessmentScopes: [
      TrackingAssessmentScope(
        assessment: assessment().reference,
        window: 'synthetic.baseline',
        scope: scope(),
      ),
    ],
  );

  static TrackingSelectionRevision selection({
    int version = 1,
    TrackingReference? previous,
    TrackingReference? profile,
    TrackingSelectionAction action = TrackingSelectionAction.select,
  }) => TrackingSelectionRevision(
    id: 'synthetic.selection',
    version: version,
    athleteId: 'synthetic.athlete',
    action: action,
    profile: profile ?? curated().reference,
    recordedAt: time.add(Duration(seconds: version)),
    previous: previous,
  );

  static TrackingHistorySource history({
    String? correctionId,
    String? inputDigest,
  }) => TrackingHistorySource(
    recordId: 'synthetic.record',
    blockResultId: 'synthetic.block-result',
    sourceBlockId: 'synthetic.block',
    fieldPath: ['result_data', 'duration_seconds'],
    inputDigest: inputDigest ?? digestA,
    correctionId: correctionId,
  );

  static TrackingMeasurementRevision measurement({
    int version = 1,
    TrackingReference? previous,
    bool fromHistory = false,
    String? correctionId,
    String? inputDigest,
  }) => TrackingMeasurementRevision(
    id: fromHistory
        ? 'synthetic.history-observation'
        : 'synthetic.manual-observation',
    version: version,
    athleteId: 'synthetic.athlete',
    metric: metric().reference,
    unit: TrackingUnit.seconds,
    source: TrackingMeasurementSource(
      kind: fromHistory
          ? TrackingSourceKind.historyResult
          : TrackingSourceKind.manualEntry,
      sourceId: fromHistory
          ? 'synthetic.record-field'
          : 'synthetic.manual-entry',
      history: fromHistory
          ? history(correctionId: correctionId, inputDigest: inputDigest)
          : null,
    ),
    chronology: TrackingChronology(
      precision: TrackingTimePrecision.timestamp,
      performedAt: earlier,
      recordedAt: time.add(Duration(seconds: version)),
    ),
    evidence: const TrackingEvidence(state: TrackingEvidenceState.available),
    provenance: fromHistory
        ? 'Synthetic source reference'
        : 'Synthetic athlete declaration',
    context: const {'setting': 'synthetic'},
    canonicalValue: fromHistory ? null : '12',
    previous: previous,
    correctionReason: version == 1 ? null : 'Synthetic correction',
  );

  static List<TrackingArtifact> get definitions => [method(), metric()];
  static List<TrackingArtifact> get all => [
    ...definitions,
    curated(),
    custom(),
    assessment(),
    binding(),
    selection(),
    measurement(),
    measurement(fromHistory: true),
  ];
}
