import 'package:cohort_platform/domain/adaptation/vocabulary/training_environment.dart';
import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_knowledge_fixtures.dart';
import 'exercise_relationship_graph_fixtures.dart';

void main() {
  group('ExerciseRelationshipGraph construction', () {
    test('builds operational graph from validated snapshot', () {
      final result = ExerciseRelationshipGraph.build(
        snapshot: ExerciseRelationshipGraphFixtures.operationalSnapshot(),
      );
      expect(result.isValid, isTrue);
      final graph = result.graph!;
      expect(graph.hasNode(ExerciseId.parse('EX-9001')), isTrue);
      expect(
        graph.outgoing(ExerciseId.parse('EX-9001')),
        isNotEmpty,
      );
    });

    test('nodes are EX-* only; transitional ids rejected', () {
      final bad = ExerciseCatalogueSnapshot(
        catalogueVersion: 'bad',
        definitions: [
          ExerciseDefinition(
            id: ExerciseId.parse('EX-9001'),
            canonicalName: 'X',
            modality: ExerciseModality.strength,
            lifecycleStatus: ExerciseLifecycleStatus.published,
            version: '1',
            publishedAt: DateTime.utc(2026, 8, 9),
          ),
        ],
        relationships: [
          ExerciseRelationship(
            id: 'rel.bad',
            sourceExerciseId: ExerciseId.parse('EX-9001'),
            targetExerciseId: ExerciseId.parse('EX-9001'),
            relationshipType: ExerciseRelationshipType.lateralAlternative,
            lifecycleStatus: ExerciseLifecycleStatus.published,
            version: '1',
            publishedAt: DateTime.utc(2026, 8, 9),
          ),
        ],
        comparisonProtocols: const [],
      );
      // Self-relationship fails closed.
      final result = ExerciseRelationshipGraph.build(snapshot: bad);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.code == 'self_relationship'),
        isTrue,
      );
    });

    test('missing unpublished target fails closed', () {
      final snapshot = ExerciseRelationshipGraphFixtures.operationalSnapshot()
          .copyWith(
        relationships: [
          ...ExerciseRelationshipGraphFixtures.operationalSnapshot()
              .relationships,
          ExerciseRelationshipGraphFixtures.edgeToMissingTarget,
        ],
      );
      final result = ExerciseRelationshipGraph.build(snapshot: snapshot);
      expect(result.isValid, isFalse);
      expect(
        result.issues.any((i) => i.code == 'missing_graph_endpoint'),
        isTrue,
      );
    });

    test('draft relationships excluded from operational graph', () {
      final draftEdge = ExerciseRelationship(
        id: 'rel.draft',
        sourceExerciseId: ExerciseId.parse('EX-9001'),
        targetExerciseId: ExerciseId.parse('EX-9002'),
        relationshipType: ExerciseRelationshipType.lateralAlternative,
        lifecycleStatus: ExerciseLifecycleStatus.draft,
        version: '1',
      );
      final snapshot = ExerciseRelationshipGraphFixtures.operationalSnapshot()
          .copyWith(
        relationships: [
          ...ExerciseRelationshipGraphFixtures.operationalSnapshot()
              .relationships,
          draftEdge,
        ],
      );
      final result = ExerciseRelationshipGraph.build(snapshot: snapshot);
      expect(result.isValid, isTrue);
      expect(
        result.graph!.edges.any((e) => e.id == 'rel.draft'),
        isFalse,
      );
    });
  });

  group('lookup and direction', () {
    late ExerciseRelationshipGraph graph;

    setUp(() {
      graph = ExerciseRelationshipGraph.build(
        snapshot: ExerciseRelationshipGraphFixtures.operationalSnapshot(),
      ).graph!;
    });

    test('preserves direction; does not invent reverse edges', () {
      final out = graph.outgoing(ExerciseId.parse('EX-9001'));
      expect(
        out.any((e) => e.targetExerciseId.value == 'EX-9002'),
        isTrue,
      );
      final reverseInvented = graph.outgoing(ExerciseId.parse('EX-9002')).any(
            (e) =>
                e.targetExerciseId.value == 'EX-9001' &&
                e.relationshipType ==
                    ExerciseRelationshipType.equipmentAlternative,
          );
      expect(reverseInvented, isFalse);
      final incoming = graph.incoming(ExerciseId.parse('EX-9002'));
      expect(
        incoming.any((e) => e.sourceExerciseId.value == 'EX-9001'),
        isTrue,
      );
    });

    test('filters by relationship type', () {
      final env = graph.outgoing(
        ExerciseId.parse('EX-9001'),
        types: {ExerciseRelationshipType.environmentAlternative},
      );
      expect(
        env.every(
          (e) =>
              e.relationshipType ==
              ExerciseRelationshipType.environmentAlternative,
        ),
        isTrue,
      );
    });

    test('back squat → goblet is authored potential limited-equipment link', () {
      final edge = graph
          .outgoing(ExerciseId.parse('EX-9001'))
          .firstWhere((e) => e.targetExerciseId.value == 'EX-9002');
      expect(
        edge.relationshipType,
        ExerciseRelationshipType.equipmentAlternative,
      );
      expect(edge.claimsDirectComparability, isFalse);
    });

    test('barbell RDL → dumbbell RDL with equipment constraints', () {
      final edge = graph
          .outgoing(ExerciseId.parse('EX-9011'))
          .firstWhere((e) => e.targetExerciseId.value == 'EX-9003');
      expect(
        edge.substitutionConstraint.requiredEquipmentTokens,
        contains('dumbbell'),
      );
    });

    test('SkiErg → banded ski is hotel alternative knowledge only', () {
      final edge = graph
          .outgoing(ExerciseId.parse('EX-9006'))
          .firstWhere((e) => e.targetExerciseId.value == 'EX-9007');
      expect(
        edge.relationshipType,
        ExerciseRelationshipType.environmentAlternative,
      );
      expect(edge.claimsDirectComparability, isFalse);
    });

    test('outdoor and treadmill remain distinct nodes', () {
      expect(graph.hasNode(ExerciseId.parse('EX-9004')), isTrue);
      expect(graph.hasNode(ExerciseId.parse('EX-9005')), isTrue);
      expect(ExerciseId.parse('EX-9004'), isNot(ExerciseId.parse('EX-9005')));
    });
  });

  group('eligibility', () {
    late ExerciseRelationshipGraph graph;

    setUp(() {
      graph = ExerciseRelationshipGraph.build(
        snapshot: ExerciseRelationshipGraphFixtures.operationalSnapshot(),
      ).graph!;
    });

    test('hotel bodyweight alternative eligible only in hotel room', () {
      final edge = ExerciseKnowledgeFixtures.backSquatToHotelBw;
      final hotel = graph.evaluateEligibility(
        edge: edge,
        context: const RelationshipEligibilityContext(
          environment: TrainingEnvironment.hotelRoom,
        ),
      );
      expect(hotel.mayBeConsidered, isTrue);
      expect(hotel.isSelected, isFalse);

      final fullGym = graph.evaluateEligibility(
        edge: edge,
        context: const RelationshipEligibilityContext(
          environment: TrainingEnvironment.fullGym,
        ),
      );
      expect(fullGym.status, RelationshipEligibilityStatus.ineligible);
    });

    test('structurally valid relationship ineligible without required equipment',
        () {
      final edge = ExerciseRelationshipGraphFixtures.gobletRequiresKettlebell;
      final missing = const RelationshipEligibilityEvaluator().evaluate(
        relationship: edge,
        context: RelationshipEligibilityContext(
          environment: TrainingEnvironment.hotelGym,
          availableEquipmentTokens: <String>{'dumbbell'},
        ),
      );
      expect(missing.status, RelationshipEligibilityStatus.ineligible);

      final present = const RelationshipEligibilityEvaluator().evaluate(
        relationship: edge,
        context: RelationshipEligibilityContext(
          environment: TrainingEnvironment.hotelGym,
          availableEquipmentTokens: <String>{'kettlebell'},
        ),
      );
      expect(present.mayBeConsidered, isTrue);
      expect(present.isSelected, isFalse);
    });

    test('incomplete context is indeterminate (fail closed for selection)', () {
      final edge = ExerciseKnowledgeFixtures.backSquatToGoblet;
      final result = graph.evaluateEligibility(
        edge: edge,
        context: const RelationshipEligibilityContext(),
      );
      // Requires hotelGym/home environments — environment missing.
      expect(result.status, RelationshipEligibilityStatus.indeterminate);
      expect(result.mayBeConsidered, isFalse);
    });

    test('eligible does not mean selected', () {
      final edge = ExerciseKnowledgeFixtures.backSquatToGoblet;
      final result = graph.evaluateEligibility(
        edge: edge,
        context: const RelationshipEligibilityContext(
          environment: TrainingEnvironment.hotelGym,
        ),
      );
      expect(result.mayBeConsidered, isTrue);
      expect(result.isSelected, isFalse);
    });
  });

  group('comparability firewall', () {
    late ExerciseRelationshipGraph graph;
    const firewall = ComparabilityFirewall();

    setUp(() {
      graph = ExerciseRelationshipGraph.build(
        snapshot: ExerciseRelationshipGraphFixtures.operationalSnapshot(),
      ).graph!;
    });

    test('adjacency and traversal do not imply comparability', () {
      final edge = ExerciseKnowledgeFixtures.backSquatToGoblet;
      expect(firewall.adjacencyImpliesComparability(edge), isFalse);
      final hops = graph.traverse(
        from: ExerciseId.parse('EX-9001'),
        maxDepth: 2,
      );
      expect(firewall.traversalImpliesComparability(hops), isFalse);
      expect(firewall.sharedModalityImpliesComparability(), isFalse);
      expect(firewall.sharedFamilyImpliesComparability(), isFalse);
      expect(firewall.substitutionEligibilityImpliesComparability(), isFalse);
      expect(firewall.bridgeMappingImpliesComparability(), isFalse);
    });

    test('same-exercise comparison does not require a graph edge', () {
      expect(firewall.sameExerciseComparisonRequiresGraphEdge(), isFalse);
      expect(
        firewall.hasAuthoredCrossExerciseComparableCandidate(
          graph: graph,
          source: ExerciseId.parse('EX-9001'),
          target: ExerciseId.parse('EX-9001'),
        ),
        isTrue, // graph does not block same-exercise comparison
      );
    });

    test('substitution / comparable-variant edge alone never grants comparability',
        () {
      final edge = ExerciseKnowledgeFixtures.backSquatToGoblet;
      expect(
        firewall.directlyComparableVariantEdgeAloneGrantsComparability(edge),
        isFalse,
      );
      expect(
        firewall.hasAuthoredCrossExerciseComparableCandidate(
          graph: graph,
          source: ExerciseId.parse('EX-9001'),
          target: ExerciseId.parse('EX-9002'),
        ),
        isFalse, // no directly_comparable_variant edge authored
      );
      expect(firewall.mayMergePerformanceHistories(), isFalse);
    });

    test('SkiErg adjacency does not share performance series with banded ski',
        () {
      final ski = ComparisonProtocol(
        id: 'cmp.ski',
        version: '1',
        exerciseId: ExerciseId.parse('EX-9006'),
        validDimensions: const [PerformanceDimension.distance],
      );
      final banded = ComparisonProtocol(
        id: 'cmp.banded',
        version: '1',
        exerciseId: ExerciseId.parse('EX-9007'),
        validDimensions: const [PerformanceDimension.repetitions],
      );
      expect(ski.comparisonSeriesKey, isNot(banded.comparisonSeriesKey));
      expect(firewall.adjacencyImpliesComparability(
        ExerciseKnowledgeFixtures.skiErgToBanded,
      ), isFalse);
      expect(
        firewall.hasAuthoredCrossExerciseComparableCandidate(
          graph: graph,
          source: ExerciseId.parse('EX-9006'),
          target: ExerciseId.parse('EX-9007'),
        ),
        isFalse,
      );
    });
  });

  group('lifecycle and traversal', () {
    test('retired edge excluded operationally; historically resolvable', () {
      final operational = ExerciseRelationshipGraph.build(
        snapshot: ExerciseRelationshipGraphFixtures.historicalSnapshot(),
      );
      expect(operational.isValid, isTrue);
      expect(
        operational.graph!.edges
            .any((e) => e.id == 'rel.ex9001.ex9002.equipment_alternative.retired'),
        isFalse,
      );

      final historical = ExerciseRelationshipGraph.buildHistorical(
        ExerciseRelationshipGraphFixtures.historicalSnapshot(),
      );
      expect(historical.isValid, isTrue);
      expect(
        historical.graph!.edges
            .any((e) => e.id == 'rel.ex9001.ex9002.equipment_alternative.retired'),
        isTrue,
      );
    });

    test('bounded traversal is deterministic, cycle-safe, non-ranking', () {
      final graph = ExerciseRelationshipGraph.build(
        snapshot: ExerciseRelationshipGraphFixtures.operationalSnapshot(),
      ).graph!;
      final hops = graph.traverse(
        from: ExerciseId.parse('EX-9001'),
        maxDepth: 1,
        types: {
          ExerciseRelationshipType.equipmentAlternative,
          ExerciseRelationshipType.environmentAlternative,
        },
      );
      expect(hops, isNotEmpty);
      expect(hops.every((h) => h.depth == 1), isTrue);
      expect(hops.every((h) => !h.isRecommendation), isTrue);
      final ids = hops.map((h) => h.edge.id).toList();
      final sorted = List<String>.of(ids)..sort();
      expect(ids, sorted);
    });

    test('relationship semantics never invent symmetry', () {
      for (final type in ExerciseRelationshipType.values) {
        expect(type.semantics.isDirectional, isTrue);
        expect(type.semantics.isExplicitlySymmetric, isFalse);
        expect(type.semantics.inverseMustBeAuthoredSeparately, isTrue);
        expect(type.impliesComparabilityByDefault, isFalse);
      }
    });

    test('graph serialization is deterministic', () {
      final graph = ExerciseRelationshipGraph.build(
        snapshot: ExerciseRelationshipGraphFixtures.operationalSnapshot(),
      ).graph!;
      final a = graph.toJson();
      final b = graph.toJson();
      expect(a, b);
      final nodeIds = (a['nodes'] as List).cast<String>();
      final sorted = List<String>.of(nodeIds)..sort();
      expect(nodeIds, sorted);
    });
  });
}
