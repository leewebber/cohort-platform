import '../contracts/minimum_viable_prescription.dart';

/// Bounded prescription reduction supported by the planner (no movement changes).
enum PrescriptionReductionKind {
  setCount,
  roundCount,
  durationMinutes,
  repetitionCount,
  restSeconds,
}

class PrescriptionReductionProposal {
  const PrescriptionReductionProposal({
    required this.kind,
    required this.originalValue,
    required this.proposedValue,
    this.minimumViablePrescription,
  });

  final PrescriptionReductionKind kind;
  final int originalValue;
  final int proposedValue;
  final MinimumViablePrescription? minimumViablePrescription;

  bool get isValid =>
      originalValue > 0 &&
      proposedValue > 0 &&
      proposedValue < originalValue;

  Map<String, dynamic> toCanonicalMap() {
    return {
      'kind': kind.name,
      'original': originalValue,
      'proposed': proposedValue,
    };
  }
}
