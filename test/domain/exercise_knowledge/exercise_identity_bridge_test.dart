import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_identity_bridge_fixtures.dart';

void main() {
  late InMemoryTransitionalExerciseIdBridge bridge;

  setUp(() {
    bridge = InMemoryTransitionalExerciseIdBridge(
      initial: ExerciseIdentityBridgeFixtures.validPublishedMappings,
    );
  });

  group('TransitionalExerciseId', () {
    test('parses cohort.exercise.* and rejects EX-* / names', () {
      expect(
        TransitionalExerciseId.parse('cohort.exercise.back_squat').value,
        'cohort.exercise.back_squat',
      );
      expect(
        () => TransitionalExerciseId.parse('EX-9001'),
        throwsFormatException,
      );
      expect(
        () => TransitionalExerciseId.parse('Back Squat'),
        throwsFormatException,
      );
    });
  });

  group('TransitionalExerciseIdBridge', () {
    test('one transitional id maps to one canonical EX-*', () {
      expect(
        bridge.toCanonical('cohort.exercise.back_squat')?.value,
        'EX-9001',
      );
      final resolved = bridge.resolve('cohort.exercise.goblet_squat');
      expect(resolved, isA<TransitionalIdentityResolved>());
      expect(
        (resolved as TransitionalIdentityResolved).canonicalId.value,
        'EX-9002',
      );
    });

    test('multiple transitional ids may map to one canonical when explicit', () {
      expect(bridge.toCanonical('cohort.exercise.back_squat')?.value, 'EX-9001');
      expect(
        bridge.toCanonical('cohort.exercise.bb_back_squat_alt')?.value,
        'EX-9001',
      );
    });

    test('unmapped transitional id fails explicitly', () {
      final result = bridge.resolve('cohort.exercise.running');
      expect(result, isA<TransitionalIdentityUnmapped>());
      expect(bridge.toCanonical('cohort.exercise.running'), isNull);
    });

    test('malformed transitional id fails explicitly', () {
      final result = bridge.resolve('Back Squat');
      expect(result, isA<TransitionalIdentityInvalid>());
      expect(bridge.toCanonical('not-an-id'), isNull);
    });

    test('mapping to missing canonical fails validation', () {
      final issues = InMemoryTransitionalExerciseIdBridge(
        initial: [ExerciseIdentityBridgeFixtures.missingTargetMapping],
      ).validate(
        knownCanonicalIds: ExerciseIdentityBridgeFixtures.knownCanonicalIds,
      );
      expect(
        issues.any((i) => i.code == 'missing_canonical_target'),
        isTrue,
      );
    });

    test('conflicting source mapping fails closed', () {
      final conflicted = InMemoryTransitionalExerciseIdBridge(
        initial: [
          ExerciseIdentityBridgeFixtures.conflictA(),
          ExerciseIdentityBridgeFixtures.conflictB(),
        ],
      );
      final result = conflicted.resolve('cohort.exercise.front_squat');
      expect(result, isA<TransitionalIdentityConflict>());
      expect(conflicted.toCanonical('cohort.exercise.front_squat'), isNull);
      final issues = conflicted.validate(
        knownCanonicalIds: ExerciseIdentityBridgeFixtures.knownCanonicalIds,
      );
      expect(
        issues.any((i) => i.code == 'conflicting_active_mapping'),
        isTrue,
      );
    });

    test('retired mapping remains historically interpretable', () {
      expect(bridge.toCanonical('cohort.exercise.back_squat_legacy'), isNull);
      final historical = bridge.resolve(
        'cohort.exercise.back_squat_legacy',
        includeHistorical: true,
      );
      expect(historical, isA<TransitionalIdentityResolved>());
      expect(
        (historical as TransitionalIdentityResolved).canonicalId.value,
        'EX-9001',
      );
      expect(
        historical.mapping.lifecycleStatus,
        ExerciseLifecycleStatus.retired,
      );
      // Still the same barbell back squat — not a false pull-up mapping.
      expect(
        historical.mapping.transitionalId.value,
        'cohort.exercise.back_squat_legacy',
      );
    });

    test('name match is deliberately not treated as identity', () {
      expect(bridge.toCanonical('back squat'), isNull);
      expect(bridge.toCanonical('Back Squat'), isNull);
      expect(bridge.resolve('back squat'), isA<TransitionalIdentityInvalid>());
      final heuristic = ExerciseIdentityMapping(
        id: 'map.heuristic.bad',
        transitionalId:
            TransitionalExerciseId.parse('cohort.exercise.box_jump'),
        canonicalId: ExerciseId.parse('EX-9001'),
        lifecycleStatus: ExerciseLifecycleStatus.draft,
        version: '1',
        provenance: 'name_match from label similarity',
      );
      final issues = const ExerciseIdentityMappingValidator().validateMapping(
        heuristic,
        knownCanonicalIds: ExerciseIdentityBridgeFixtures.knownCanonicalIds,
      );
      expect(
        issues.any((i) => i.code == 'heuristic_mapping_provenance'),
        isTrue,
      );
    });

    test('mapping preserves knowledge access without comparison grant', () {
      final adapter = CanonicalisedExerciseKnowledgeAdapter(bridge: bridge);
      final view = adapter.canonicalise(
        ExerciseIdentityBridgeFixtures.knowledgeStub(
          'cohort.exercise.ski_erg',
          label: 'SkiErg',
        ),
      );
      expect(view, isA<CanonicalisedExerciseKnowledgeResolved>());
      final resolved = view as CanonicalisedExerciseKnowledgeResolved;
      expect(resolved.view.canonicalId.value, 'EX-9006');
      expect(resolved.view.grantsComparability, isFalse);
      expect(resolved.view.grantsSubstitutionPermission, isFalse);

      // Distinct comparison series still required (HYROX / erg standards).
      final skiProtocol = ComparisonProtocol(
        id: 'cmp.ski_erg',
        version: '1',
        exerciseId: ExerciseId.parse('EX-9006'),
        validDimensions: const [PerformanceDimension.distance],
        setupKey: 'ski_erg_standard',
      );
      final bandedProtocol = ComparisonProtocol(
        id: 'cmp.banded_ski',
        version: '1',
        exerciseId: ExerciseId.parse('EX-9007'),
        validDimensions: const [PerformanceDimension.repetitions],
      );
      expect(
        skiProtocol.comparisonSeriesKey,
        isNot(bandedProtocol.comparisonSeriesKey),
      );
    });

    test('draft mappings are not operational', () {
      bridge.upsertMapping(
        ExerciseIdentityMapping(
          id: 'map.draft.running',
          transitionalId:
              TransitionalExerciseId.parse('cohort.exercise.running'),
          canonicalId: ExerciseId.parse('EX-9001'),
          lifecycleStatus: ExerciseLifecycleStatus.draft,
          version: '1',
          provenance: 'Founder draft fixture — not operational.',
        ),
      );
      expect(bridge.toCanonical('cohort.exercise.running'), isNull);
    });

    test('founder publication authority enforced; invalid catalogue rejected', () {
      const publication = ExerciseIdentityMappingPublicationService();
      final rejected = publication.publishMappings(
        bridge: InMemoryTransitionalExerciseIdBridge(),
        draftMappings: [ExerciseIdentityBridgeFixtures.missingTargetMapping],
        knownCanonicalIds: ExerciseIdentityBridgeFixtures.knownCanonicalIds,
        actingOwner: 'coach',
      );
      expect(rejected.isAccepted, isFalse);
      expect(
        rejected.issues.any((i) => i.code == 'founder_authority_required'),
        isTrue,
      );

      final failClosed = publication.publishMappings(
        bridge: InMemoryTransitionalExerciseIdBridge(),
        draftMappings: [ExerciseIdentityBridgeFixtures.missingTargetMapping],
        knownCanonicalIds: ExerciseIdentityBridgeFixtures.knownCanonicalIds,
        actingOwner: 'founder',
      );
      expect(failClosed.isAccepted, isFalse);

      final ok = publication.publishMappings(
        bridge: InMemoryTransitionalExerciseIdBridge(),
        draftMappings: [
          ExerciseIdentityMapping(
            id: 'map.publish.goblet',
            transitionalId:
                TransitionalExerciseId.parse('cohort.exercise.goblet_squat'),
            canonicalId: ExerciseId.parse('EX-9002'),
            lifecycleStatus: ExerciseLifecycleStatus.draft,
            version: '1',
            provenance: 'Founder-authored publish fixture.',
          ),
        ],
        knownCanonicalIds: ExerciseIdentityBridgeFixtures.knownCanonicalIds,
        actingOwner: 'founder',
        publishedAt: DateTime.utc(2026, 8, 9),
      );
      expect(ok.isAccepted, isTrue);
    });

    test('toCanonical never returns transitional id as canonical', () {
      final id = bridge.toCanonical('cohort.exercise.wall_ball');
      expect(id, isNotNull);
      expect(ExerciseId.isCanonical(id!.value), isTrue);
      expect(TransitionalExerciseId.isTransitional(id.value), isFalse);
    });

    test('serialization of mappings is deterministic', () {
      final list = bridge.listMappings();
      final json = list.map((m) => m.toJson()).toList();
      final again = json
          .map(
            (j) => ExerciseIdentityMapping.fromJson(
              Map<String, Object?>.from(j),
            ),
          )
          .toList();
      expect(
        again.map((m) => m.toJson()).toList(),
        json,
      );
      final ids = list.map((m) => m.id).toList();
      final sorted = List<String>.of(ids)..sort();
      expect(ids, sorted);
    });
  });

  group('CanonicalisedExerciseKnowledgeAdapter', () {
    test('resolves mapped knowledge and quarantines unmapped', () {
      final adapter = CanonicalisedExerciseKnowledgeAdapter(bridge: bridge);
      final batch = adapter.canonicaliseAll([
        ExerciseIdentityBridgeFixtures.knowledgeStub(
          'cohort.exercise.back_squat',
        ),
        ExerciseIdentityBridgeFixtures.knowledgeStub(
          'cohort.exercise.running',
        ),
        ExerciseIdentityBridgeFixtures.knowledgeStub(
          'cohort.exercise.wall_ball',
        ),
      ]);
      expect(batch.resolved.length, 2);
      expect(batch.quarantined.length, 1);
      expect(batch.quarantined.first.transitionalId, 'cohort.exercise.running');
      expect(
        batch.quarantined.first.issues.any(
          (i) => i.code == 'unmapped_transitional_exercise',
        ),
        isTrue,
      );
      // Original transitional definition retained on quarantine.
      expect(
        batch.quarantined.first.knowledge.id,
        'cohort.exercise.running',
      );
    });
  });
}
