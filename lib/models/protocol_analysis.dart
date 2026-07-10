import 'movement_profile.dart';
import 'session_fingerprint.dart';

/// Analysis output from [ProtocolAnalyzer].
///
/// v0.1 exposes counts, simple derived summaries, and movement profile
/// occurrence counts. Future versions will populate the planned analysis
/// sections documented below.
class ProtocolAnalysis {
  const ProtocolAnalysis({
    required this.protocolId,
    required this.protocolName,
    required this.exerciseCount,
    required this.stepCount,
    required this.requiredEquipmentSummary,
    required this.bodyFocusSummary,
    required this.hasRunning,
    required this.hasErg,
    this.movementProfile,
    this.fingerprint,
  });

  final String protocolId;
  final String protocolName;
  final int exerciseCount;
  final int stepCount;
  final String requiredEquipmentSummary;
  final String bodyFocusSummary;
  final bool hasRunning;
  final bool hasErg;
  final MovementProfile? movementProfile;
  final SessionFingerprint? fingerprint;
}

// ---------------------------------------------------------------------------
// Planned analysis sections (not yet implemented)
// ---------------------------------------------------------------------------
//
// TODO(Movement Profile):
//   Weight occurrence counts by reps, time, and distance. Add percentage
//   views for adaptation similarity. See [MovementProfile].
//
// TODO(Fingerprint):
//   Weight fingerprint fields by reps, time, and distance from step
//   prescriptions. See [SessionFingerprint].
//
// TODO(Equipment Dependency):
//   Measure how tightly the session depends on specific equipment beyond
//   metadata `required_equipment`.
//
// TODO(Density):
//   Estimate work volume per minute from reps, distance, duration, and rest.
//
// TODO(Complexity):
//   Assess coordination and skill demand from exercise technical complexity
//   and step structure.
//
// TODO(Running Percentage):
//   Calculate the share of session volume attributable to running steps.
//
// TODO(Transition Density):
//   Measure how frequently the athlete changes movement, modality, or station.
//
// TODO(Substitution Difficulty):
//   Score how resistant the session is to movement swaps without changing
//   session identity.
