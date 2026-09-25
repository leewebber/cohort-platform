import '../domain/programme_review_models.dart';
import 'programme_review_source.dart';

abstract final class ProgrammeReviewCatalogRegistry {
  static const apolloWeekSql = [
    'supabase/migrations/20260821120000_apollo_build_week1_executable_protocols.sql',
    'supabase/migrations/20260821121000_apollo_build_week2_executable_protocols.sql',
    'supabase/migrations/20260821122000_apollo_build_week3_executable_protocols.sql',
    'supabase/migrations/20260821123000_apollo_build_week4_executable_protocols.sql',
    'supabase/migrations/20260821124000_apollo_build_week5_executable_protocols.sql',
    'supabase/migrations/20260821125000_apollo_build_week6_executable_protocols.sql',
    'supabase/migrations/20260821130000_apollo_build_week7_executable_protocols.sql',
    'supabase/migrations/20260821131000_apollo_build_week8_executable_protocols.sql',
    'supabase/migrations/20260821132000_apollo_build_week9_executable_protocols.sql',
    'supabase/migrations/20260821133000_apollo_build_week10_executable_protocols.sql',
    'supabase/migrations/20260821134000_apollo_build_week11_executable_protocols.sql',
    'supabase/migrations/20260821135000_apollo_build_week12_executable_protocols.sql',
  ];

  static const apolloUnreplayedSql = [
    'supabase/migrations/20260823121000_structure_apollo_week1_monday_warmup_exercises.sql',
    'supabase/migrations/20260824121000_correct_apollo_structured_warmup_prescriptions.sql',
    'supabase/migrations/20260825120000_structure_all_apollo_warmups_and_athlete_details.sql',
    'supabase/migrations/20260906160000_apollo_w5_fixed_work_rounds_capture.sql',
  ];

  static const realSpecs = [
    ProgrammeReviewSourceSpec(
      catalogId: 'apollo-build-v2',
      classification: ProgrammeReviewClassification.internalPersonal,
      planPackagePath: 'tool/programmes/apollo_build_12_week_v1.plan-package.yaml',
      publicationJsonPath:
          'content/content_graph/v1/cohort_global/apollo/2ba018bd-7dc2-4dfd-8d8e-e35823158920.publication.json',
      executableProtocolSqlPaths: apolloWeekSql,
      unreplayedSqlPaths: apolloUnreplayedSql,
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
      ],
    ];
  }

  static const excludedFromRealInventory = [
    'packages/cohort_plan_package/test/fixtures/minimal_plan_package.yaml',
    'tool/examples/founder_example_programme.yaml',
    'lib/features/programme/presentation/programme_discovery_decision_preview_catalog.dart',
  ];
}
