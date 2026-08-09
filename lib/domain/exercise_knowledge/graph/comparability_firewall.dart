import '../models/exercise_relationship.dart';
import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_relationship_type.dart';
import 'exercise_relationship_graph.dart';

/// Negative firewall: graph structure never grants comparison compatibility.
///
/// **Not** a competing comparison authority. Protocol / identity resolution and
/// previous-performance look-up remain with the established comparison
/// contracts (`ComparisonProtocol`, `ComparisonIdentity`, previous-performance
/// services). This class only proves what the relationship graph must **not**
/// imply.
///
/// Same-exercise comparison against valid prior evidence does **not** require
/// a graph edge. A `directly_comparable_variant` edge alone is never sufficient
/// for cross-exercise comparability.
class ComparabilityFirewall {
  const ComparabilityFirewall();

  /// Adjacency never implies comparability.
  bool adjacencyImpliesComparability(ExerciseRelationship edge) => false;

  /// Transitive reachability never implies comparability.
  bool traversalImpliesComparability(
    List<ExerciseRelationshipTraversalHop> hops,
  ) =>
      false;

  bool sharedModalityImpliesComparability() => false;

  bool sharedFamilyImpliesComparability() => false;

  bool substitutionEligibilityImpliesComparability() => false;

  bool bridgeMappingImpliesComparability() => false;

  /// Ordinary same-exercise comparison must not require a graph edge.
  bool sameExerciseComparisonRequiresGraphEdge() => false;

  /// An authored comparable-variant edge alone never grants comparability;
  /// protocol/identity resolution remains outside the graph.
  bool directlyComparableVariantEdgeAloneGrantsComparability(
    ExerciseRelationship edge,
  ) {
    if (!edge.claimsDirectComparability) return false;
    return false;
  }

  /// Graph methods must never merge performance histories.
  bool mayMergePerformanceHistories() => false;

  /// Optional fail-closed authored constraint for **cross-exercise** claims:
  /// returns whether a published `directly_comparable_variant` edge exists.
  ///
  /// Never sufficient for comparability. Never consulted for same-exercise
  /// (`source == target`) comparison — always `true` (graph does not block).
  /// Does not evaluate protocols.
  bool hasAuthoredCrossExerciseComparableCandidate({
    required ExerciseRelationshipGraph graph,
    required ExerciseId source,
    required ExerciseId target,
  }) {
    if (source == target) return true;
    final edges = graph.outgoing(
      source,
      types: {ExerciseRelationshipType.directlyComparableVariant},
    );
    return edges.any((e) => e.targetExerciseId == target);
  }
}
