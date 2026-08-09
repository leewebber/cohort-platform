import '../value_objects/exercise_id.dart';
import 'comparison_protocol.dart';

/// Outcome of an explicit comparison-protocol compatibility check.
///
/// Never inferred from relationship type, family, modality, or substitution.
enum ComparisonCompatibilityStatus {
  compatible,
  incompatible,
  protocolNotFound,
}

class ComparisonCompatibilityResult {
  const ComparisonCompatibilityResult({
    required this.status,
    this.protocol,
    this.message,
  });

  final ComparisonCompatibilityStatus status;
  final ComparisonProtocol? protocol;
  final String? message;

  bool get isCompatible =>
      status == ComparisonCompatibilityStatus.compatible;
}

/// Pure helper: compatibility only through declared protocol identity/version.
class ComparisonProtocolCompatibility {
  const ComparisonProtocolCompatibility();

  /// Two exercises share a series only when the same protocol id+version
  /// applies to [exerciseId] and the caller supplies that protocol explicitly.
  ///
  /// A protocol is bound to one exercise; cross-exercise like-for-like requires
  /// an authored [directlyComparableVariant] relationship that references a
  /// protocol — this helper does **not** inspect relationships or families.
  ComparisonCompatibilityResult protocolAppliesTo({
    required ComparisonProtocol? protocol,
    required ExerciseId exerciseId,
    String? expectedProtocolId,
    String? expectedVersion,
  }) {
    if (protocol == null) {
      return const ComparisonCompatibilityResult(
        status: ComparisonCompatibilityStatus.protocolNotFound,
        message: 'Comparison protocol not found.',
      );
    }
    if (expectedProtocolId != null && protocol.id != expectedProtocolId) {
      return ComparisonCompatibilityResult(
        status: ComparisonCompatibilityStatus.incompatible,
        protocol: protocol,
        message: 'Protocol id mismatch.',
      );
    }
    if (expectedVersion != null && protocol.version != expectedVersion) {
      return ComparisonCompatibilityResult(
        status: ComparisonCompatibilityStatus.incompatible,
        protocol: protocol,
        message: 'Protocol version mismatch.',
      );
    }
    if (protocol.exerciseId != exerciseId) {
      return ComparisonCompatibilityResult(
        status: ComparisonCompatibilityStatus.incompatible,
        protocol: protocol,
        message:
            'Protocol ${protocol.id} does not apply to ${exerciseId.value}.',
      );
    }
    return ComparisonCompatibilityResult(
      status: ComparisonCompatibilityStatus.compatible,
      protocol: protocol,
    );
  }
}
