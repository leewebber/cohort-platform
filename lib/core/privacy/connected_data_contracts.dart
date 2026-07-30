// Safe contracts for future connected performance / recovery metrics.
// Privacy: never include live location, GPS routes, geofencing, travel
// detection, home/work inference, or behavioural movement tracking.
// See docs/architecture/Connected_Data_Privacy_v1.md.

/// Explicitly allowed metric categories (integrations not implemented yet).
enum ConnectedPerformanceMetricKind {
  heartRate,
  hrv,
  recoveryReadiness,
  sleep,
  pace,
  cadence,
  power,
  trainingLoad,
  completedActivityDistance,
  completedActivityDuration,
  completedActivityElevation,
}

/// A single connected metric sample — no location fields by design.
class ConnectedPerformanceMetric {
  const ConnectedPerformanceMetric({
    required this.kind,
    required this.value,
    required this.recordedAt,
    this.unit,
    this.sourceConnectionId,
  });

  final ConnectedPerformanceMetricKind kind;
  final double value;
  final DateTime recordedAt;
  final String? unit;

  /// Id of an explicitly connected data source (never a location provider).
  final String? sourceConnectionId;
}

/// Marker interface documenting prohibited data categories.
///
/// Do not add fields for: liveLocation, gpsRoute, backgroundLocation,
/// homeLocation, workLocation, geofence, travelDetection, movementTracking.
abstract final class ProhibitedLocationData {
  // Intentionally empty — presence of this type documents the boundary.
}
