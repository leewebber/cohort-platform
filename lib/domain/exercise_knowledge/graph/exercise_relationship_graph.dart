import '../models/exercise_catalogue_snapshot.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_definition_lookup.dart';
import '../models/exercise_relationship.dart';
import '../validation/exercise_knowledge_validation_issue.dart';
import '../validation/exercise_knowledge_validator.dart';
import '../value_objects/exercise_id.dart';
import '../value_objects/transitional_exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import '../vocabulary/exercise_relationship_type.dart';
import 'relationship_eligibility.dart';

/// Derived read-model graph over canonical Exercise Knowledge relationships.
///
/// Nodes are [ExerciseId] only. Edges are authored [ExerciseRelationship]
/// records. Not a second repository, adaptation engine, substitution selector,
/// comparison authority, or persistence mechanism.
class ExerciseRelationshipGraph {
  ExerciseRelationshipGraph._({
    required this.catalogueVersion,
    required Map<String, ExerciseDefinition> nodes,
    required List<ExerciseRelationship> edges,
    required this.visibility,
  })  : _nodes = Map.unmodifiable(nodes),
        _edges = List.unmodifiable(edges);

  final String catalogueVersion;
  final ExerciseKnowledgeVisibility visibility;
  final Map<String, ExerciseDefinition> _nodes;
  final List<ExerciseRelationship> _edges;

  /// Build from a validated catalogue snapshot (fail closed on issues).
  static ExerciseRelationshipGraphBuildResult build({
    required ExerciseCatalogueSnapshot snapshot,
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
    ExerciseKnowledgeValidator validator = const ExerciseKnowledgeValidator(),
  }) {
    final issues = <ExerciseKnowledgeValidationIssue>[];

    issues.addAll(
      validator.validateCatalogue(
        definitions: snapshot.definitions,
        relationships: snapshot.relationships,
        comparisonProtocols: snapshot.comparisonProtocols,
        movementStandards: snapshot.movementStandards,
        coachingContents: snapshot.coachingContents,
        videoReferences: snapshot.videoReferences,
      ),
    );

    final knownIds = <String>{};
    final nodes = <String, ExerciseDefinition>{};

    for (final def in snapshot.definitions) {
      if (TransitionalExerciseId.isTransitional(def.id.value)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'definitions[${def.id.value}]',
            message: 'Transitional ids cannot be graph nodes.',
            code: 'transitional_graph_node',
          ),
        );
        continue;
      }
      if (!ExerciseId.isCanonical(def.id.value)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: 'definitions[${def.id.value}]',
            message: 'Graph nodes must use canonical EX-* ids.',
            code: 'noncanonical_graph_node',
          ),
        );
        continue;
      }
      if (!visibility.includes(def.lifecycleStatus)) continue;
      knownIds.add(def.id.value);
      nodes[def.id.value] = def;
    }

    final protocolIds = {
      for (final p in snapshot.comparisonProtocols) p.id,
    };

    final edges = <ExerciseRelationship>[];
    final seenKeys = <String>{};
    final seenIds = <String>{};

    for (final rel in snapshot.relationships) {
      final path = 'relationships[${rel.id}]';

      if (TransitionalExerciseId.isTransitional(rel.sourceExerciseId.value) ||
          TransitionalExerciseId.isTransitional(rel.targetExerciseId.value)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: path,
            message: 'Transitional ids cannot be relationship endpoints.',
            code: 'transitional_graph_endpoint',
          ),
        );
        continue;
      }

      if (!visibility.includes(rel.lifecycleStatus)) {
        // Draft excluded from operational; retired excluded from operational.
        continue;
      }

      if (visibility == ExerciseKnowledgeVisibility.operational &&
          rel.lifecycleStatus != ExerciseLifecycleStatus.published) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: path,
            message: 'Draft/unapproved relationships cannot enter operational graph.',
            code: 'draft_in_operational_graph',
          ),
        );
        continue;
      }

      if (rel.lifecycleStatus == ExerciseLifecycleStatus.published &&
          rel.owner.trim() != 'founder') {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.owner',
            message: 'Published relationships must be founder-owned.',
            code: 'non_founder_published_relationship',
          ),
        );
      }

      if (!knownIds.contains(rel.sourceExerciseId.value)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.source_exercise_id',
            message: 'Missing source node ${rel.sourceExerciseId.value}.',
            code: 'missing_graph_endpoint',
          ),
        );
      }
      if (!knownIds.contains(rel.targetExerciseId.value)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.target_exercise_id',
            message: 'Missing target node ${rel.targetExerciseId.value}.',
            code: 'missing_graph_endpoint',
          ),
        );
      }

      if (rel.sourceExerciseId == rel.targetExerciseId) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: path,
            message: 'Self-relationships are forbidden.',
            code: 'self_relationship',
          ),
        );
      }

      if (!seenIds.add(rel.id)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: path,
            message: 'Duplicate relationship id.',
            code: 'duplicate_relationship_id',
          ),
        );
      }
      if (!seenKeys.add(rel.uniquenessKey)) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: path,
            message: 'Duplicate edge for ${rel.uniquenessKey}.',
            code: 'duplicate_relationship',
          ),
        );
      }

      if (rel.claimsDirectComparability) {
        final protocolId = rel.comparisonProtocolId?.trim() ?? '';
        if (protocolId.isEmpty) {
          issues.add(
            ExerciseKnowledgeValidationIssue(
              path: '$path.comparison_protocol_id',
              message: 'directly_comparable_variant requires a protocol.',
              code: 'missing_comparison_protocol',
            ),
          );
        } else if (!protocolIds.contains(protocolId)) {
          issues.add(
            ExerciseKnowledgeValidationIssue(
              path: '$path.comparison_protocol_id',
              message: 'Unresolved comparison protocol $protocolId.',
              code: 'unknown_comparison_protocol',
            ),
          );
        }
      }

      // Prescription / evidence must not appear on relationship JSON.
      final json = rel.toJson();
      for (final forbidden in const [
        'sets',
        'reps',
        'load',
        'tempo',
        'completed_load',
        'athlete_result',
        'prescription_values',
        'completed_values',
      ]) {
        if (json.containsKey(forbidden)) {
          issues.add(
            ExerciseKnowledgeValidationIssue(
              path: '$path.$forbidden',
              message: 'Graph edges must not embed prescription or evidence.',
              code: 'forbidden_prescription_or_evidence_field',
            ),
          );
        }
      }

      if (ExerciseRelationshipTypeCodec.tryParse(rel.relationshipType.wireValue) ==
          null) {
        issues.add(
          ExerciseKnowledgeValidationIssue(
            path: '$path.relationship_type',
            message: 'Unsupported relationship type.',
            code: 'unsupported_relationship_type',
          ),
        );
      }

      edges.add(rel);
    }

    // Sort edges deterministically.
    edges.sort((a, b) => a.id.compareTo(b.id));

    final blocking = issues.where((i) => _isBlocking(i.code)).toList();
    if (blocking.isNotEmpty) {
      return ExerciseRelationshipGraphBuildResult.invalid(issues);
    }

    return ExerciseRelationshipGraphBuildResult.valid(
      ExerciseRelationshipGraph._(
        catalogueVersion: snapshot.catalogueVersion,
        nodes: nodes,
        edges: edges,
        visibility: visibility,
      ),
      warnings: issues,
    );
  }

  /// Historical graph: published + retired nodes/edges.
  static ExerciseRelationshipGraphBuildResult buildHistorical(
    ExerciseCatalogueSnapshot snapshot,
  ) {
    return build(
      snapshot: snapshot,
      visibility: ExerciseKnowledgeVisibility.historical,
    );
  }

  /// Authoring graph: all lifecycles present in the snapshot.
  static ExerciseRelationshipGraphBuildResult buildAuthoring(
    ExerciseCatalogueSnapshot snapshot,
  ) {
    return build(
      snapshot: snapshot,
      visibility: ExerciseKnowledgeVisibility.authoring,
    );
  }

  List<ExerciseId> get nodeIds {
    final ids = _nodes.keys.map(ExerciseId.parse).toList()..sort();
    return List.unmodifiable(ids);
  }

  List<ExerciseRelationship> get edges => _edges;

  ExerciseDefinition? node(ExerciseId id) => _nodes[id.value];

  bool hasNode(ExerciseId id) => _nodes.containsKey(id.value);

  List<ExerciseRelationship> outgoing(
    ExerciseId id, {
    Set<ExerciseRelationshipType>? types,
  }) {
    final out = _edges.where((e) {
      if (e.sourceExerciseId != id) return false;
      if (types != null && !types.contains(e.relationshipType)) return false;
      return true;
    }).toList(growable: true);
    out.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(out);
  }

  List<ExerciseRelationship> incoming(
    ExerciseId id, {
    Set<ExerciseRelationshipType>? types,
  }) {
    final out = _edges.where((e) {
      if (e.targetExerciseId != id) return false;
      if (types != null && !types.contains(e.relationshipType)) return false;
      return true;
    }).toList(growable: true);
    out.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(out);
  }

  /// Bounded, cycle-safe, non-ranking typed traversal (discovery only).
  List<ExerciseRelationshipTraversalHop> traverse({
    required ExerciseId from,
    required int maxDepth,
    Set<ExerciseRelationshipType>? types,
    bool outgoingDirection = true,
  }) {
    if (maxDepth < 1) return const [];
    if (!hasNode(from)) return const [];

    final results = <ExerciseRelationshipTraversalHop>[];
    final visitedEdges = <String>{};
    var frontier = <ExerciseId>[from];

    for (var depth = 1; depth <= maxDepth; depth++) {
      final nextFrontier = <ExerciseId>[];
      for (final nodeId in frontier) {
        final edges = outgoingDirection
            ? outgoing(nodeId, types: types)
            : incoming(nodeId, types: types);
        for (final edge in edges) {
          if (!visitedEdges.add(edge.id)) continue;
          final next = outgoingDirection
              ? edge.targetExerciseId
              : edge.sourceExerciseId;
          results.add(
            ExerciseRelationshipTraversalHop(
              depth: depth,
              edge: edge,
              from: edge.sourceExerciseId,
              to: edge.targetExerciseId,
            ),
          );
          if (hasNode(next)) nextFrontier.add(next);
        }
      }
      frontier = nextFrontier;
    }

    results.sort((a, b) {
      final byDepth = a.depth.compareTo(b.depth);
      if (byDepth != 0) return byDepth;
      return a.edge.id.compareTo(b.edge.id);
    });
    return List.unmodifiable(results);
  }

  /// Pure eligibility check — “may be considered”, never “should be selected”.
  RelationshipEligibilityResult evaluateEligibility({
    required ExerciseRelationship edge,
    required RelationshipEligibilityContext context,
  }) {
    return const RelationshipEligibilityEvaluator().evaluate(
      relationship: edge,
      context: context,
    );
  }

  Map<String, Object?> toJson() => {
        'catalogue_version': catalogueVersion,
        'visibility': visibility.name,
        'nodes': nodeIds.map((id) => id.value).toList(growable: false),
        'edges': _edges.map((e) => e.toJson()).toList(growable: false),
      };
}

class ExerciseRelationshipTraversalHop {
  const ExerciseRelationshipTraversalHop({
    required this.depth,
    required this.edge,
    required this.from,
    required this.to,
  });

  final int depth;
  final ExerciseRelationship edge;
  final ExerciseId from;
  final ExerciseId to;

  /// Traversal hops are discovery only — never recommendations.
  bool get isRecommendation => false;
}

class ExerciseRelationshipGraphBuildResult {
  const ExerciseRelationshipGraphBuildResult._({
    required this.isValid,
    this.graph,
    this.issues = const [],
    this.warnings = const [],
  });

  factory ExerciseRelationshipGraphBuildResult.valid(
    ExerciseRelationshipGraph graph, {
    List<ExerciseKnowledgeValidationIssue> warnings = const [],
  }) =>
      ExerciseRelationshipGraphBuildResult._(
        isValid: true,
        graph: graph,
        warnings: warnings,
      );

  factory ExerciseRelationshipGraphBuildResult.invalid(
    List<ExerciseKnowledgeValidationIssue> issues,
  ) =>
      ExerciseRelationshipGraphBuildResult._(
        isValid: false,
        issues: issues,
      );

  final bool isValid;
  final ExerciseRelationshipGraph? graph;
  final List<ExerciseKnowledgeValidationIssue> issues;
  final List<ExerciseKnowledgeValidationIssue> warnings;
}

bool _isBlocking(String? code) {
  const warnings = <String>{
    // Reserved for future non-blocking codes.
  };
  if (code == null) return true;
  return !warnings.contains(code);
}
