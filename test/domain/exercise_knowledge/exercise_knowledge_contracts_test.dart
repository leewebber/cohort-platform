import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'exercise_knowledge_fixtures.dart';
import 'exercise_movement_content_fixtures.dart';

void main() {
  const validator = ExerciseKnowledgeValidator();

  group('Exercise Knowledge catalogue fixtures', () {
    test('representative definitions validate', () {
      final issues = validator.validateCatalogue(
        definitions: ExerciseKnowledgeFixtures.allDefinitions,
        relationships: ExerciseKnowledgeFixtures.validRelationships,
        comparisonProtocols: ExerciseKnowledgeFixtures.allProtocols,
        movementStandards: [
          ExerciseMovementContentFixtures.movementStandard,
        ],
      );
      expect(issues, isEmpty);
    });

    test('back squat and goblet squat may relate without comparability', () {
      final rel = ExerciseKnowledgeFixtures.backSquatToGoblet;
      expect(rel.relationshipType, ExerciseRelationshipType.equipmentAlternative);
      expect(rel.claimsDirectComparability, isFalse);
      expect(rel.comparisonProtocolId, isNull);
      expect(
        rel.relationshipType.impliesComparabilityByDefault,
        isFalse,
      );
    });

    test('barbell and dumbbell variants do not share performance series', () {
      final back = ExerciseKnowledgeFixtures.backSquatComparison;
      final gobletProtocol = ComparisonProtocol(
        id: 'cmp.goblet.standard',
        version: '1',
        exerciseId: ExerciseKnowledgeFixtures.gobletSquat.id,
        validDimensions: const [
          PerformanceDimension.load,
          PerformanceDimension.repetitions,
        ],
      );
      expect(back.comparisonSeriesKey, isNot(gobletProtocol.comparisonSeriesKey));
      expect(back.exerciseId, isNot(gobletProtocol.exerciseId));
    });

    test('outdoor and treadmill running relate without pace equivalence', () {
      final rel = ExerciseKnowledgeFixtures.outdoorToTreadmill;
      expect(
        rel.relationshipType,
        ExerciseRelationshipType.environmentAlternative,
      );
      expect(rel.claimsDirectComparability, isFalse);
      final outdoor = ExerciseKnowledgeFixtures.outdoorRunComparison;
      final treadmill = ComparisonProtocol(
        id: 'cmp.treadmill_run',
        version: '1',
        exerciseId: ExerciseKnowledgeFixtures.treadmillRun.id,
        validDimensions: const [
          PerformanceDimension.distance,
          PerformanceDimension.pace,
        ],
        setupKey: 'treadmill',
      );
      expect(outdoor.comparisonSeriesKey, isNot(treadmill.comparisonSeriesKey));
    });

    test('SkiErg and banded ski preserve intent without SkiErg series', () {
      final rel = ExerciseKnowledgeFixtures.skiErgToBanded;
      expect(
        rel.relationshipType,
        ExerciseRelationshipType.environmentAlternative,
      );
      expect(rel.claimsDirectComparability, isFalse);
      expect(
        rel.substitutionConstraint.sportStandardRestrictionIds,
        contains('sport.hyrox.ski_erg'),
      );
    });

    test('modified wall balls cannot join standard HYROX protocol series', () {
      final standard = ExerciseKnowledgeFixtures.hyroxWallBallComparison;
      final modified = ComparisonProtocol(
        id: 'cmp.hyrox.wall_balls.modified',
        version: '1',
        exerciseId: ExerciseKnowledgeFixtures.hyroxWallBalls.id,
        validDimensions: const [PerformanceDimension.repetitions],
        setupKey: 'modified_non_standard',
      );
      expect(standard.comparisonSeriesKey, isNot(modified.comparisonSeriesKey));
    });

    test('environment alternative can be valid for continuity only', () {
      final rel = ExerciseKnowledgeFixtures.backSquatToHotelBw;
      expect(
        rel.relationshipType,
        ExerciseRelationshipType.environmentAlternative,
      );
      expect(rel.claimsDirectComparability, isFalse);
      expect(rel.substitutionConstraint.emergencyOrRegressionOnly, isTrue);
    });

    test('directly comparable variant rejected without protocol', () {
      final invalid =
          ExerciseKnowledgeFixtures.directlyComparableWithoutProtocol();
      final issues = validator.validateRelationship(
        invalid,
        knownExerciseIds: {
          ExerciseKnowledgeFixtures.backSquat.id.value,
          ExerciseKnowledgeFixtures.gobletSquat.id.value,
        },
        knownComparisonProtocolIds: {
          ExerciseKnowledgeFixtures.backSquatComparison.id,
        },
      );
      expect(
        issues.any((i) => i.code == 'missing_comparison_protocol'),
        isTrue,
      );
    });
  });

  group('ExerciseKnowledgeValidator', () {
    test('rejects blank canonical name', () {
      final bad = ExerciseDefinition(
        id: ExerciseId.parse('EX-9990'),
        canonicalName: '   ',
        modality: ExerciseModality.strength,
        lifecycleStatus: ExerciseLifecycleStatus.draft,
        version: '1',
      );
      final issues = validator.validateDefinition(bad);
      expect(issues.any((i) => i.code == 'blank_canonical_name'), isTrue);
    });

    test('rejects self-relationship', () {
      final rel = ExerciseRelationship(
        id: 'rel.self',
        sourceExerciseId: ExerciseId.parse('EX-9001'),
        targetExerciseId: ExerciseId.parse('EX-9001'),
        relationshipType: ExerciseRelationshipType.lateralAlternative,
        lifecycleStatus: ExerciseLifecycleStatus.draft,
        version: '1',
      );
      expect(
        validator.validateRelationship(rel).any((i) => i.code == 'self_relationship'),
        isTrue,
      );
    });

    test('rejects duplicate relationships in catalogue', () {
      final issues = validator.validateCatalogue(
        definitions: [
          ExerciseKnowledgeFixtures.backSquat,
          ExerciseKnowledgeFixtures.gobletSquat,
        ],
        relationships: [
          ExerciseKnowledgeFixtures.backSquatToGoblet,
          ExerciseKnowledgeFixtures.backSquatToGoblet,
        ],
        comparisonProtocols: const [],
      );
      expect(issues.any((i) => i.code == 'duplicate_relationship'), isTrue);
    });

    test('rejects contradictory environment suitability', () {
      final withOverlap = ExerciseDefinition.fromJson({
        'id': 'EX-9991',
        'canonical_name': 'Bad Env',
        'modality': 'strength',
        'lifecycle_status': 'draft',
        'version': '1',
        'environments': {
          'suitable': ['hotel_room'],
          'unsuitable': ['hotel_room'],
        },
      });
      final issues = validator.validateDefinition(withOverlap);
      expect(
        issues.any((i) => i.code == 'contradictory_environment_suitability'),
        isTrue,
      );
    });

    test('rejects invalid lifecycle transition published → draft', () {
      final issues = validator.validateLifecycleTransition(
        from: ExerciseLifecycleStatus.published,
        to: ExerciseLifecycleStatus.draft,
      );
      expect(issues.any((i) => i.code == 'invalid_lifecycle_transition'), isTrue);
    });

    test('definition JSON round-trip is stable', () {
      final original = ExerciseKnowledgeFixtures.backSquat;
      final again = ExerciseDefinition.fromJson(
        Map<String, Object?>.from(original.toJson()),
      );
      expect(again.toJson(), original.toJson());
    });

    test('relationship JSON round-trip is stable', () {
      final original = ExerciseKnowledgeFixtures.skiErgToBanded;
      final again = ExerciseRelationship.fromJson(
        Map<String, Object?>.from(original.toJson()),
      );
      expect(again.toJson(), original.toJson());
    });
  });

  group('Authority boundary', () {
    test('definitions do not embed prescription or completion values', () {
      for (final def in ExerciseKnowledgeFixtures.allDefinitions) {
        final json = def.toJson();
        for (final key in const [
          'sets',
          'reps',
          'load',
          'tempo',
          'rest',
          'completed_load',
          'athlete_result',
        ]) {
          expect(json.containsKey(key), isFalse, reason: def.id.value);
        }
      }
    });

    test('comparison identity contains no athlete results', () {
      final identity = ComparisonIdentity(
        exerciseId: ExerciseKnowledgeFixtures.backSquat.id,
        protocol: ExerciseKnowledgeFixtures.backSquatComparison,
      );
      final json = identity.toJson();
      expect(json.containsKey('results'), isFalse);
      expect(json.containsKey('completed_values'), isFalse);
      expect(identity.seriesKey, startsWith('cmp:EX-9001:'));
    });
  });
}
