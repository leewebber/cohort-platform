import '../../domain/performance_tracking/performance_tracking.dart';

/// Founder approved 2026-10-07, exactly the v1 metric decision content.
/// The proposed namespace is retained to preserve the approved IDs.
abstract final class DistanceObservationsProfile {
  static final method = TrackingMethodDefinition(
    id: 'proposed.history.block_distance.km.extract',
    version: 1,
    kind: TrackingMethodKind.fieldExtraction,
    inputUnits: const [TrackingUnit.kilometres],
    outputUnit: TrackingUnit.kilometres,
  );
  static final metric = TrackingMetricDefinition(
    id: 'proposed.history.block_distance.km',
    version: 1,
    label: 'Recorded block distance',
    unit: TrackingUnit.kilometres,
    method: method.reference,
    allowedSources: const [TrackingSourceKind.historyResult],
    captureField: 'distance',
    requiredContext: const [],
    requiresAssessment: false,
    allowPartial: false,
    freshnessCivilDays: null,
  );
  static final profile = TrackingProfile(
    id: 'proposed.history.distance_observations',
    version: 1,
    kind: TrackingProfileKind.curated,
    name: 'Distance observations',
    metrics: [metric.reference],
    view: TrackingView.history,
  );
  static final List<TrackingArtifact> definitions = List.unmodifiable([
    method,
    metric,
    profile,
  ]);
  static const description =
      'The distance recorded for a selected completed History block, in kilometres. '
      'This is an observation of what was recorded, not a fitness score. '
      'Comparison may be unavailable when evidence or context is missing.';
}
