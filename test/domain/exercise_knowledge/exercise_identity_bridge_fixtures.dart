import 'package:cohort_platform/domain/exercise_knowledge/exercise_knowledge_domain.dart';
import 'package:cohort_platform/knowledge/models/knowledge_ontology_models.dart';

/// Contract-test fixtures for Phase 3.1D identity bridge — not production seeds.
///
/// Canonical targets use Exercise Knowledge fixture ids (EX-900x). Mappings are
/// explicit authored records with provenance; none are derived from name match.
class ExerciseIdentityBridgeFixtures {
  ExerciseIdentityBridgeFixtures._();

  static final knownCanonicalIds = {
    'EX-9001',
    'EX-9002',
    'EX-9006',
    'EX-9008',
  };

  /// Explicit: transitionalAliasIds already authored on EX-9001 in 3.1B fixtures.
  static final backSquatMapping = ExerciseIdentityMapping(
    id: 'map.back_squat.ex9001',
    transitionalId: TransitionalExerciseId.parse('cohort.exercise.back_squat'),
    canonicalId: ExerciseId.parse('EX-9001'),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    provenance:
        'Authored ExerciseDefinition.transitionalAliasIds on EX-9001 (Phase 3.1B fixtures).',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  /// Second explicit transitional id → same canonical (compatible multi-map).
  static final bbBackSquatAltMapping = ExerciseIdentityMapping(
    id: 'map.bb_back_squat_alt.ex9001',
    transitionalId:
        TransitionalExerciseId.parse('cohort.exercise.bb_back_squat_alt'),
    canonicalId: ExerciseId.parse('EX-9001'),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    provenance:
        'Founder-authored fixture: alternate transitional label for same barbell back squat semantics.',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final gobletMapping = ExerciseIdentityMapping(
    id: 'map.goblet_squat.ex9002',
    transitionalId: TransitionalExerciseId.parse('cohort.exercise.goblet_squat'),
    canonicalId: ExerciseId.parse('EX-9002'),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    provenance:
        'Authored ExerciseDefinition.transitionalAliasIds on EX-9002 (Phase 3.1B fixtures).',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final skiErgMapping = ExerciseIdentityMapping(
    id: 'map.ski_erg.ex9006',
    transitionalId: TransitionalExerciseId.parse('cohort.exercise.ski_erg'),
    canonicalId: ExerciseId.parse('EX-9006'),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    provenance:
        'Founder-authored fixture linking SkiErg knowledge id to EX-9006; '
        'does not grant HYROX comparison compatibility.',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  static final wallBallMapping = ExerciseIdentityMapping(
    id: 'map.wall_ball.ex9008',
    transitionalId: TransitionalExerciseId.parse('cohort.exercise.wall_ball'),
    canonicalId: ExerciseId.parse('EX-9008'),
    lifecycleStatus: ExerciseLifecycleStatus.published,
    version: '1',
    provenance:
        'Founder-authored fixture linking wall-ball knowledge id to EX-9008; '
        'HYROX standard remains a sport reference, not a second identity.',
    publishedAt: DateTime.utc(2026, 8, 9),
  );

  /// Retired mapping of a superseded transitional label for the same back squat.
  /// Historically resolvable; not a false pull-up→squat identity.
  static final retiredBackSquatLegacyMapping = ExerciseIdentityMapping(
    id: 'map.back_squat_legacy.ex9001.retired',
    transitionalId:
        TransitionalExerciseId.parse('cohort.exercise.back_squat_legacy'),
    canonicalId: ExerciseId.parse('EX-9001'),
    lifecycleStatus: ExerciseLifecycleStatus.retired,
    version: '1',
    provenance:
        'Founder-authored prior transitional label for EX-9001 (Barbell Back '
        'Squat), retired after supersession by cohort.exercise.back_squat.',
    publishedAt: DateTime.utc(2026, 1, 1),
    retiredAt: DateTime.utc(2026, 8, 1),
  );

  /// Missing canonical target (for negative validation).
  static final missingTargetMapping = ExerciseIdentityMapping(
    id: 'map.bench_press.missing',
    transitionalId: TransitionalExerciseId.parse('cohort.exercise.bench_press'),
    canonicalId: ExerciseId.parse('EX-9999'),
    lifecycleStatus: ExerciseLifecycleStatus.draft,
    version: '1',
    provenance: 'Founder-authored fixture targeting absent catalogue id.',
  );

  /// Conflicting pair: same transitional → two targets.
  static ExerciseIdentityMapping conflictA() => ExerciseIdentityMapping(
        id: 'map.conflict.a',
        transitionalId:
            TransitionalExerciseId.parse('cohort.exercise.front_squat'),
        canonicalId: ExerciseId.parse('EX-9001'),
        lifecycleStatus: ExerciseLifecycleStatus.published,
        version: '1',
        provenance: 'Founder-authored conflict fixture A.',
        publishedAt: DateTime.utc(2026, 8, 9),
      );

  static ExerciseIdentityMapping conflictB() => ExerciseIdentityMapping(
        id: 'map.conflict.b',
        transitionalId:
            TransitionalExerciseId.parse('cohort.exercise.front_squat'),
        canonicalId: ExerciseId.parse('EX-9002'),
        lifecycleStatus: ExerciseLifecycleStatus.published,
        version: '1',
        provenance: 'Founder-authored conflict fixture B.',
        publishedAt: DateTime.utc(2026, 8, 9),
      );

  static List<ExerciseIdentityMapping> get validPublishedMappings => [
        backSquatMapping,
        bbBackSquatAltMapping,
        gobletMapping,
        skiErgMapping,
        wallBallMapping,
        retiredBackSquatLegacyMapping,
      ];

  static ExerciseKnowledge knowledgeStub(String transitionalId, {String? label}) {
    final short = transitionalId.replaceFirst('cohort.exercise.', '');
    return ExerciseKnowledge(
      meta: KnowledgeEntityMeta(
        id: transitionalId,
        canonicalName: short,
        label: label ?? short,
        ontologyVersion: '1.3.0',
        status: 'active',
      ),
      curationStatus: 'reference_only',
    );
  }
}
