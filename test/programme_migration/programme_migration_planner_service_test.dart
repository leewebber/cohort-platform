import 'package:cohort_platform/features/programme_comparison/services/programme_version_comparison_service.dart';
import 'package:cohort_platform/features/programme_impact/services/programme_version_impact_service.dart';
import 'package:cohort_platform/features/programme_migration/models/programme_migration_plan_models.dart';
import 'package:cohort_platform/features/programme_migration/services/programme_migration_planner_service.dart';
import 'package:cohort_platform/features/programme_migration/services/programme_migration_recommendation_builder.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_exercise_relationship_store.dart';
import '../support/in_memory_programme_migration_planner_store.dart';
import '../support/in_memory_programme_stores.dart';
import '../support/in_memory_programme_version_comparison_store.dart';
import '../support/in_memory_programme_version_impact_store.dart';
import '../support/in_memory_session_lineage_store.dart';
import '../support/session_revision_usage_test_fixtures.dart';

void main() {
  late InMemoryProgrammeTables programmeTables;
  late InMemorySessionLineageStore lineageStore;
  late InMemoryExerciseRelationshipTables exerciseTables;
  late InMemoryProgrammeVersionComparisonStore comparisonStore;
  late InMemoryProgrammeVersionImpactStore impactStore;
  late InMemoryProgrammeMigrationPlannerStore plannerStore;
  late ProgrammeMigrationPlannerService service;

  const lineageId = 'lineage-1';
  const versionV2Id = 'version-2';
  const versionV3Id = 'version-3';
  const versionIdenticalId = 'version-identical';
  const protocolA = 'session-a-rev-1';
  const protocolB = 'session-b-rev-1';
  const protocolC = 'session-c-rev-2';

  ProgrammeMigrationPlannerService buildService({
    InMemoryProgrammeVersionComparisonStore? comparison,
    InMemoryProgrammeVersionImpactStore? impact,
    InMemoryProgrammeMigrationPlannerStore? planner,
  }) {
    return ProgrammeMigrationPlannerService(
      comparisonService: ProgrammeVersionComparisonService(
        comparisonStore: comparison ?? comparisonStore,
      ),
      impactService: ProgrammeVersionImpactService(
        impactStore: impact ?? impactStore,
      ),
      plannerStore: planner ?? plannerStore,
      comparisonStore: comparison ?? comparisonStore,
    );
  }

  setUp(() {
    programmeTables = InMemoryProgrammeTables();
    lineageStore = InMemorySessionLineageStore();
    exerciseTables = InMemoryExerciseRelationshipTables();

    SessionRevisionUsageTestFixtures.seedLineage(
      programmeTables,
      id: lineageId,
      code: 'PROG-MIGRATE',
    );

    programmeTables.versions.addAll([
      _version(
        id: versionV2Id,
        lineageId: lineageId,
        versionNumber: 2,
        name: 'HYROX Base',
      ),
      _version(
        id: versionV3Id,
        lineageId: lineageId,
        versionNumber: 3,
        name: 'HYROX Base Pro',
      ),
      _version(
        id: versionIdenticalId,
        lineageId: lineageId,
        versionNumber: 4,
        name: 'HYROX Base',
      ),
    ]);

    for (final entry in [
      (protocolA, 1, 'session-lineage-a'),
      (protocolB, 1, 'session-lineage-b'),
      (protocolC, 2, 'session-lineage-a'),
    ]) {
      SessionRevisionUsageTestFixtures.seedRevisionMetadata(
        lineageStore,
        protocolId: entry.$1,
        sessionLineageId: entry.$3,
        revisionNumber: entry.$2,
      );
    }

    _seedFourWeekStructure(
      programmeTables: programmeTables,
      versionId: versionV2Id,
      weekPrefix: 'v2',
      slotProtocolByWeek: {
        1: protocolA,
        2: protocolA,
        3: protocolA,
        4: protocolA,
      },
    );

    _seedFourWeekStructure(
      programmeTables: programmeTables,
      versionId: versionV3Id,
      weekPrefix: 'v3',
      slotProtocolByWeek: {
        1: protocolA,
        2: protocolA,
        3: protocolC,
        4: protocolC,
      },
    );

    _seedFourWeekStructure(
      programmeTables: programmeTables,
      versionId: versionIdenticalId,
      weekPrefix: 'identical',
      slotProtocolByWeek: {
        1: protocolA,
        2: protocolA,
        3: protocolA,
        4: protocolA,
      },
    );

    comparisonStore = InMemoryProgrammeVersionComparisonStore(
      programmeTables: programmeTables,
      lineageStore: lineageStore,
      exerciseTables: exerciseTables,
      protocolNames: {
        protocolA: 'Strength Foundation',
        protocolB: 'Engine Builder',
        protocolC: 'Strength Foundation',
      },
    );
    impactStore = InMemoryProgrammeVersionImpactStore(
      programmeTables: programmeTables,
      lineageStore: lineageStore,
      exerciseTables: exerciseTables,
      protocolNames: {
        protocolA: 'Strength Foundation',
        protocolB: 'Engine Builder',
        protocolC: 'Strength Foundation',
      },
    );
    plannerStore = InMemoryProgrammeMigrationPlannerStore(programmeTables);
    service = buildService();
  });

  group('planning outcomes', () {
    test('programme identical yields safeImmediate for active assignment', () async {
      final assignment = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-identical',
        versionId: versionV2Id,
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionIdenticalId,
        assignmentIds: [assignment.id],
      );

      expect(
        plan.assignmentPlans.single.migrationClassification,
        MigrationClassification.safeImmediate,
      );
    });

    test('assignment not started is safeImmediate', () async {
      final assignment = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-not-started',
        versionId: versionV2Id,
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
        assignmentIds: [assignment.id],
      );

      expect(plan.assignmentPlans.single.hasStarted, isFalse);
      expect(
        plan.assignmentPlans.single.migrationClassification,
        MigrationClassification.safeImmediate,
      );
    });

    test('assignment at week 1 with progress can require review when current session changes',
        () async {
      final assignment = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-week-1',
        versionId: versionV2Id,
        currentWeek: 1,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: assignment,
        slotId: 'slot-v2-w1',
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
        assignmentIds: [assignment.id],
      );

      expect(plan.assignmentPlans.single.currentWeek, 1);
      expect(plan.assignmentPlans.single.hasStarted, isTrue);
      expect(plan.assignmentPlans.single.migrationClassification,
          isNot(MigrationClassification.safeImmediate));
    });

    test('assignment at week 2 with later-week changes is safeAfterCurrentWeek', () async {
      final assignment = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-week-2-future',
        versionId: versionV2Id,
        currentWeek: 2,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: assignment,
        slotId: 'slot-v2-w1',
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
        assignmentIds: [assignment.id],
      );

      expect(
        plan.assignmentPlans.single.migrationClassification,
        MigrationClassification.safeAfterCurrentWeek,
      );
    });

    test('completed assignment is alreadyCompleted', () async {
      final assignment = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-completed',
        versionId: versionV2Id,
        status: ProgrammeAssignmentStatus.completed,
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
        assignmentIds: [assignment.id],
      );

      expect(
        plan.assignmentPlans.single.migrationClassification,
        MigrationClassification.alreadyCompleted,
      );
      expect(plan.summary.completed, 1);
    });

    test('future-only changes before current week classify as safeAfterCurrentWeek',
        () async {
      final assignment = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-future-only',
        versionId: versionV2Id,
        currentWeek: 2,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: assignment,
        slotId: 'slot-v2-w1',
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
        assignmentIds: [assignment.id],
      );

      expect(
        plan.assignmentPlans.single.migrationClassification,
        MigrationClassification.safeAfterCurrentWeek,
      );
    });

    test('current session revision change is safeAfterCurrentSession', () async {
      final assignment = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-current-revision',
        versionId: versionV2Id,
        currentWeek: 3,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: assignment,
        slotId: 'slot-v2-w1',
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: assignment,
        slotId: 'slot-v2-w2',
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
        assignmentIds: [assignment.id],
      );

      expect(
        plan.assignmentPlans.single.migrationClassification,
        MigrationClassification.safeAfterCurrentSession,
      );
    });

    test('current session removed requires manualReview', () async {
      final removedTarget = _version(
        id: 'version-removed-current',
        lineageId: lineageId,
        versionNumber: 5,
        name: 'Removed current',
      );
      programmeTables.versions.add(removedTarget);

      _seedFourWeekStructure(
        programmeTables: programmeTables,
        versionId: removedTarget.id,
        weekPrefix: 'removed',
        slotProtocolByWeek: {
          1: protocolA,
          2: protocolA,
          4: protocolC,
        },
        skipWeek: 3,
      );

      final assignment = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-current-removed',
        versionId: versionV2Id,
        currentWeek: 3,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: assignment,
        slotId: 'slot-v2-w1',
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: assignment,
        slotId: 'slot-v2-w2',
      );

      final plan = await buildService().planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: removedTarget.id,
        assignmentIds: [assignment.id],
      );

      expect(
        plan.assignmentPlans.single.migrationClassification,
        MigrationClassification.manualReview,
      );
    });

    test('unknown progress yields cannotDetermine', () async {
      final assignment = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-unknown-progress',
        versionId: versionV2Id,
        currentWeek: 99,
        currentDayKey: 'day_missing',
        currentSessionOrder: 9,
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
        assignmentIds: [assignment.id],
      );

      expect(
        plan.assignmentPlans.single.migrationClassification,
        MigrationClassification.cannotDetermine,
      );
      expect(plan.summary.unknown, 1);
      expect(plan.isPartial, isTrue);
    });
  });

  group('lookup failures', () {
    test('comparison unavailable when source missing', () async {
      final lookup = await service.tryPlanMigration(
        sourceProgrammeVersionId: 'missing-source',
        targetProgrammeVersionId: versionV3Id,
      );
      expect(lookup.status, ProgrammeMigrationPlannerStatus.sourceNotFound);
    });

    test('impact unavailable when impact store fails', () async {
      final failingImpact = InMemoryProgrammeVersionImpactStore(
        programmeTables: programmeTables,
        lineageStore: lineageStore,
        historicalLookupFails: true,
      );

      final lookup = await buildService(impact: failingImpact).tryPlanMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );

      expect(lookup.isSuccess, isTrue);
    });

    test('comparison partial marks plan partial', () async {
      final partialComparison = InMemoryProgrammeVersionComparisonStore(
        programmeTables: programmeTables,
        lineageStore: lineageStore,
        exerciseTables: exerciseTables,
        exerciseEnrichmentAuthoritative: false,
      );
      _seedActiveAssignment(
        programmeTables,
        id: 'assignment-partial',
        versionId: versionV2Id,
      );

      final lookup = await buildService(comparison: partialComparison)
          .tryPlanMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );

      expect(lookup.status, ProgrammeMigrationPlannerStatus.partial);
    });
  });

  group('summary and ordering', () {
    test('mixed assignments produce accurate summary counts', () async {
      _seedActiveAssignment(
        programmeTables,
        id: 'assignment-a',
        versionId: versionV2Id,
      );
      _seedActiveAssignment(
        programmeTables,
        id: 'assignment-b',
        versionId: versionV2Id,
        currentWeek: 4,
        currentDayKey: 'day_1',
        currentSessionOrder: 1,
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: programmeTables.assignments.last,
        slotId: 'slot-v2-w1',
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: programmeTables.assignments.last,
        slotId: 'slot-v2-w2',
      );
      _seedCompletedOutcome(
        programmeTables,
        assignment: programmeTables.assignments.last,
        slotId: 'slot-v2-w3',
      );
      final completed = _seedActiveAssignment(
        programmeTables,
        id: 'assignment-c',
        versionId: versionV2Id,
        status: ProgrammeAssignmentStatus.completed,
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
        assignmentIds: [
          'assignment-a',
          'assignment-b',
          completed.id,
        ],
      );

      expect(plan.summary.totalAssignments, 3);
      expect(plan.summary.safeImmediate, 1);
      expect(plan.summary.completed, 1);
      expect(plan.summary.safeAfterCurrentWeek, 0);
      expect(
        plan.assignmentPlans.firstWhere((p) => p.assignmentId == 'assignment-b').migrationClassification,
        isIn([
          MigrationClassification.safeAfterCurrentSession,
          MigrationClassification.manualReview,
        ]),
      );
    });

    test('assignment plans are deterministically ordered', () async {
      _seedActiveAssignment(
        programmeTables,
        id: 'assignment-z',
        versionId: versionV2Id,
      );
      _seedActiveAssignment(
        programmeTables,
        id: 'assignment-a',
        versionId: versionV2Id,
      );

      final first = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      final second = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );

      expect(
        first.assignmentPlans.map((plan) => plan.assignmentId),
        second.assignmentPlans.map((plan) => plan.assignmentId),
      );
    });

    test('recommendations do not command automatic migration', () async {
      _seedActiveAssignment(
        programmeTables,
        id: 'assignment-rec',
        versionId: versionV2Id,
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );

      for (final assignmentPlan in plan.assignmentPlans) {
        expect(
          ProgrammeMigrationRecommendationBuilder
              .recommendationContainsMigrationCommand(
            assignmentPlan.recommendation,
          ),
          isFalse,
        );
      }
    });

    test('plans all active assignments when assignmentIds omitted', () async {
      _seedActiveAssignment(
        programmeTables,
        id: 'assignment-active-1',
        versionId: versionV2Id,
      );
      _seedActiveAssignment(
        programmeTables,
        id: 'assignment-active-2',
        versionId: versionV2Id,
      );
      programmeTables.assignments.add(
        ProgrammeAssignment(
          id: 'assignment-reassigned',
          athleteId: 'athlete-other',
          programmeVersionId: versionV2Id,
          lineageCode: 'PROG-MIGRATE',
          status: ProgrammeAssignmentStatus.reassigned,
          startedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      final plan = await service.planMigration(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );

      expect(plan.summary.totalAssignments, 2);
    });
  });
}

ProgrammeVersion _version({
  required String id,
  required String lineageId,
  required int versionNumber,
  String name = 'Test Programme',
}) {
  return ProgrammeVersion(
    id: id,
    lineageId: lineageId,
    versionNumber: versionNumber,
    lifecycleStatus: ProgrammeLifecycleStatus.published,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    name: name,
  );
}

ProgrammeAssignment _seedActiveAssignment(
  InMemoryProgrammeTables tables, {
  required String id,
  required String versionId,
  ProgrammeAssignmentStatus status = ProgrammeAssignmentStatus.active,
  int currentWeek = 1,
  String currentDayKey = 'day_1',
  int currentSessionOrder = 1,
}) {
  final assignment = ProgrammeAssignment(
    id: id,
    athleteId: 'athlete-$id',
    programmeVersionId: versionId,
    lineageCode: 'PROG-MIGRATE',
    status: status,
    startedAt: DateTime.utc(2026, 1, 1),
    currentWeek: currentWeek,
    currentDayKey: currentDayKey,
    currentSessionOrder: currentSessionOrder,
    completedAt: status == ProgrammeAssignmentStatus.completed
        ? DateTime.utc(2026, 2, 1)
        : null,
  );
  tables.assignments.add(assignment);
  return assignment;
}

void _seedCompletedOutcome(
  InMemoryProgrammeTables tables, {
  required ProgrammeAssignment assignment,
  required String slotId,
}) {
  tables.outcomes.add(
    ProgrammeSlotOutcome(
      id: 'outcome-$slotId-${assignment.id}',
      assignmentId: assignment.id,
      sessionSlotId: slotId,
      weekNumber: 1,
      dayKey: 'day_1',
      sessionOrder: 1,
      outcomeStatus: ProgrammeSlotOutcomeStatus.completed,
      resolvedAt: DateTime.utc(2026, 1, 10),
    ),
  );
}

void _seedFourWeekStructure({
  required InMemoryProgrammeTables programmeTables,
  required String versionId,
  required String weekPrefix,
  required Map<int, String> slotProtocolByWeek,
  int? skipWeek,
}) {
  final version = programmeTables.versions.firstWhere((v) => v.id == versionId);

  for (var weekNumber = 1; weekNumber <= 4; weekNumber++) {
    if (skipWeek == weekNumber) continue;

    final protocolId = slotProtocolByWeek[weekNumber];
    if (protocolId == null) continue;

    final week = SessionRevisionUsageTestFixtures.seedWeek(
      programmeTables,
      version: version,
      id: 'week-$weekPrefix-$weekNumber',
      weekNumber: weekNumber,
    );
    final day = SessionRevisionUsageTestFixtures.seedDay(
      programmeTables,
      week: week,
      id: 'day-$weekPrefix-$weekNumber',
      dayKey: 'day_1',
    );
    SessionRevisionUsageTestFixtures.seedSlot(
      programmeTables,
      day: day,
      protocolId: protocolId,
      id: 'slot-$weekPrefix-w$weekNumber',
      sessionOrder: 1,
    );
  }
}
