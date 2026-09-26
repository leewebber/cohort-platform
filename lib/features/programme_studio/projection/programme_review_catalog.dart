import '../domain/programme_review_models.dart';
import 'apollo_sql_artifact_chain.dart';
import 'programme_review_source.dart';

abstract final class ProgrammeReviewCatalogRegistry {
  static const apolloWeekSql = ApolloSqlArtifactChain.insertRelativePaths;

  static const apolloCorrectionSql =
      ApolloSqlArtifactChain.correctionRelativePaths;

  static const baliCatalogId = 'bali-hybrid-base-v1';

  static const realSpecs = [
    ProgrammeReviewSourceSpec(
      catalogId: 'apollo-build-v2',
      classification: ProgrammeReviewClassification.internalPersonal,
      planPackagePath:
          'tool/programmes/apollo_build_12_week_v1.plan-package.yaml',
      publicationJsonPath:
          'content/content_graph/v1/cohort_global/apollo/2ba018bd-7dc2-4dfd-8d8e-e35823158920.publication.json',
      executableProtocolSqlPaths: apolloWeekSql,
      correctionSqlPaths: apolloCorrectionSql,
    ),
    ProgrammeReviewSourceSpec(
      catalogId: baliCatalogId,
      classification: ProgrammeReviewClassification.internalPrivate,
      planPackagePath: 'tool/programmes/bali_hybrid_base_v1.plan-package.yaml',
      founderYamlPath: 'tool/programmes/bali_hybrid_base_v1.founder.yaml',
      publicationJsonPath:
          'content/programmes/bali_hybrid_base/v1/bali_hybrid_base.publication.json',
    ),
    ProgrammeReviewSourceSpec(
      catalogId: 'spartan-physique-v3',
      classification: ProgrammeReviewClassification.legacyWithheld,
      planPackagePath:
          'tool/programmes/spartan_physique_block1_week1.plan-package.yaml',
      founderYamlPath: 'tool/programmes/spartan_physique_block1_week1.yaml',
      publicationJsonPath:
          'content/content_graph/v1/cohort_global/spartan/32986922-47d1-46b0-b391-a7931d73033e.publication.json',
    ),
  ];

  static const plannedFamilies = [
    ProgrammeReviewPlannedFamily(
      id: 'hyrox-base',
      title: 'HYROX Base',
      durationWeeks: 8,
      intent:
          'Approved planned family only. No authored sessions, weeks, or metrics.',
      buildOrder: 1,
    ),
    ProgrammeReviewPlannedFamily(
      id: 'hyrox-pro-performance',
      title: 'HYROX Pro Performance',
      durationWeeks: 16,
      intent:
          'Approved planned family only. No authored sessions, weeks, or metrics.',
      buildOrder: 2,
    ),
    ProgrammeReviewPlannedFamily(
      id: 'hyrox-first-race',
      title: 'HYROX First Race',
      durationWeeks: 16,
      intent:
          'Approved planned family only. No authored sessions, weeks, or metrics.',
      buildOrder: 3,
    ),
    ProgrammeReviewPlannedFamily(
      id: 'hyrox-performance',
      title: 'HYROX Performance',
      durationWeeks: 16,
      intent:
          'Approved planned family only. No authored sessions, weeks, or metrics.',
      buildOrder: 4,
    ),
    ProgrammeReviewPlannedFamily(
      id: 'strength-for-endurance',
      title: 'Strength for Endurance',
      durationWeeks: 12,
      intent:
          'Approved planned family only. No authored sessions, weeks, or metrics.',
      buildOrder: 5,
    ),
    ProgrammeReviewPlannedFamily(
      id: 'tactical-athlete-365',
      title: 'Tactical Athlete 365',
      durationWeeks: 16,
      intent:
          'Approved planned family only. No authored sessions, weeks, or metrics.',
      buildOrder: 6,
    ),
    ProgrammeReviewPlannedFamily(
      id: 'strength-for-life-55',
      title: 'Strength for Life 55+',
      durationWeeks: 12,
      intent:
          'Approved planned family only. No authored sessions, weeks, or metrics.',
      buildOrder: 7,
    ),
  ];

  static List<String> get realReadablePaths {
    return [
      for (final spec in realSpecs) ...[
        spec.planPackagePath,
        if (spec.founderYamlPath != null) spec.founderYamlPath!,
        if (spec.publicationJsonPath != null) spec.publicationJsonPath!,
        ...spec.executableProtocolSqlPaths,
        ...spec.correctionSqlPaths,
      ],
    ];
  }

  static const excludedFromRealInventory = [
    'packages/cohort_plan_package/test/fixtures/minimal_plan_package.yaml',
    'tool/examples/founder_example_programme.yaml',
    'lib/features/programme/presentation/programme_discovery_decision_preview_catalog.dart',
  ];
}
