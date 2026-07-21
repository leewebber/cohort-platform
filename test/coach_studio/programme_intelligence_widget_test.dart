import 'package:cohort_platform/features/coach_studio/programmes/controllers/programme_intelligence_controller.dart';
import 'package:cohort_platform/features/coach_studio/programmes/intelligence/programme_intelligence_copy.dart';
import 'package:cohort_platform/features/coach_studio/programmes/widgets/intelligence/migration_assignment_tile.dart';
import 'package:cohort_platform/features/coach_studio/programmes/widgets/intelligence/programme_intelligence_section.dart';
import 'package:cohort_platform/features/programme_comparison/services/programme_version_comparison_service.dart';
import 'package:cohort_platform/features/programme_impact/services/programme_version_impact_service.dart';
import 'package:cohort_platform/features/programme_migration/models/programme_migration_plan_models.dart';
import 'package:cohort_platform/features/programme_migration/services/programme_migration_planner_service.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter/material.dart';
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
  late ProgrammeIntelligenceController controller;

  const lineageId = 'lineage-intel';
  const versionV2Id = 'version-intel-2';
  const versionV3Id = 'version-intel-3';
  const protocolA = 'session-intel-a';

  ProgrammeIntelligenceController buildController() {
    final comparisonStore = InMemoryProgrammeVersionComparisonStore(
      programmeTables: programmeTables,
      lineageStore: lineageStore,
      exerciseTables: exerciseTables,
      protocolNames: {protocolA: 'Strength Foundation'},
    );
    final impactStore = InMemoryProgrammeVersionImpactStore(
      programmeTables: programmeTables,
      lineageStore: lineageStore,
      exerciseTables: exerciseTables,
      protocolNames: {protocolA: 'Strength Foundation'},
    );

    return ProgrammeIntelligenceController(
      versionId: versionV2Id,
      impactService: ProgrammeVersionImpactService(impactStore: impactStore),
      comparisonService: ProgrammeVersionComparisonService(
        comparisonStore: comparisonStore,
      ),
      migrationPlannerService: ProgrammeMigrationPlannerService(
        comparisonService: ProgrammeVersionComparisonService(
          comparisonStore: comparisonStore,
        ),
        impactService: ProgrammeVersionImpactService(impactStore: impactStore),
        plannerStore: InMemoryProgrammeMigrationPlannerStore(programmeTables),
        comparisonStore: comparisonStore,
      ),
      impactStore: impactStore,
    );
  }

  setUp(() {
    programmeTables = InMemoryProgrammeTables();
    lineageStore = InMemorySessionLineageStore();
    exerciseTables = InMemoryExerciseRelationshipTables();

    SessionRevisionUsageTestFixtures.seedLineage(
      programmeTables,
      id: lineageId,
      code: 'PROG-INTEL',
    );

    programmeTables.versions.addAll([
      ProgrammeVersion(
        id: versionV2Id,
        lineageId: lineageId,
        versionNumber: 2,
        lifecycleStatus: ProgrammeLifecycleStatus.published,
        libraryScope: ProgrammeLibraryScope.cohortGlobal,
        ownerType: ProgrammeOwnerType.global,
        name: 'HYROX Base',
      ),
      ProgrammeVersion(
        id: versionV3Id,
        lineageId: lineageId,
        versionNumber: 3,
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
        libraryScope: ProgrammeLibraryScope.cohortGlobal,
        ownerType: ProgrammeOwnerType.global,
        name: 'HYROX Base Pro',
      ),
    ]);

    SessionRevisionUsageTestFixtures.seedRevisionMetadata(
      lineageStore,
      protocolId: protocolA,
      sessionLineageId: 'session-lineage-a',
    );

    final week = SessionRevisionUsageTestFixtures.seedWeek(
      programmeTables,
      version: programmeTables.versions[0],
      id: 'week-intel-v2',
    );
    final day = SessionRevisionUsageTestFixtures.seedDay(
      programmeTables,
      week: week,
      id: 'day-intel-v2',
    );
    SessionRevisionUsageTestFixtures.seedSlot(
      programmeTables,
      day: day,
      protocolId: protocolA,
      id: 'slot-intel-v2',
    );

    final weekV3 = SessionRevisionUsageTestFixtures.seedWeek(
      programmeTables,
      version: programmeTables.versions[1],
      id: 'week-intel-v3',
    );
    final dayV3 = SessionRevisionUsageTestFixtures.seedDay(
      programmeTables,
      week: weekV3,
      id: 'day-intel-v3',
    );
    SessionRevisionUsageTestFixtures.seedSlot(
      programmeTables,
      day: dayV3,
      protocolId: protocolA,
      id: 'slot-intel-v3',
      displayTitle: 'Updated label',
    );

    programmeTables.assignments.add(
      ProgrammeAssignment(
        id: 'assignment-intel-1',
        athleteId: 'athlete-1',
        programmeVersionId: versionV2Id,
        lineageCode: 'PROG-INTEL',
        status: ProgrammeAssignmentStatus.active,
        startedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    controller = buildController();
  });

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProgrammeIntelligenceSection(controller: controller),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('loading and errors', () {
    testWidgets('shows loading then impact content', (tester) async {
      await pumpSection(tester);
      expect(find.text(ProgrammeIntelligenceCopy.sectionTitle), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('VERSION OVERVIEW'), findsOneWidget);
      expect(find.text('IMPACT'), findsOneWidget);
    });

    testWidgets('impact error shows retry', (tester) async {
      // Rebuild with a missing version so impact lookup fails deterministically.
      final comparisonStore = InMemoryProgrammeVersionComparisonStore(
        programmeTables: programmeTables,
        lineageStore: lineageStore,
        exerciseTables: exerciseTables,
        protocolNames: {protocolA: 'Strength Foundation'},
      );
      final impactStore = InMemoryProgrammeVersionImpactStore(
        programmeTables: programmeTables,
        lineageStore: lineageStore,
        exerciseTables: exerciseTables,
        protocolNames: {protocolA: 'Strength Foundation'},
      );
      controller = ProgrammeIntelligenceController(
        versionId: 'missing-version',
        impactService: ProgrammeVersionImpactService(impactStore: impactStore),
        comparisonService: ProgrammeVersionComparisonService(
          comparisonStore: comparisonStore,
        ),
        migrationPlannerService: ProgrammeMigrationPlannerService(
          comparisonService: ProgrammeVersionComparisonService(
            comparisonStore: comparisonStore,
          ),
          impactService: ProgrammeVersionImpactService(impactStore: impactStore),
          plannerStore: InMemoryProgrammeMigrationPlannerStore(programmeTables),
          comparisonStore: comparisonStore,
        ),
        impactStore: impactStore,
      );
      await pumpSection(tester);
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('impact rendering', () {
    testWidgets('impact card shows aggregate counts', (tester) async {
      await pumpSection(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('active assignment'), findsOneWidget);
      expect(find.textContaining('distinct session'), findsOneWidget);
    });

    testWidgets('version overview shows programme name', (tester) async {
      await pumpSection(tester);
      await tester.pumpAndSettle();
      expect(find.text('HYROX Base'), findsOneWidget);
      expect(find.text('Version 2'), findsOneWidget);
    });
  });

  group('comparison', () {
    testWidgets('comparison idle until version selected', (tester) async {
      await pumpSection(tester);
      await tester.pumpAndSettle();
      expect(find.text(ProgrammeIntelligenceCopy.selectComparisonPrompt), findsWidgets);
    });

    testWidgets('selecting comparison target loads summary', (tester) async {
      await pumpSection(tester);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Version 3').last);
      await tester.pumpAndSettle();

      expect(find.text('View changes'), findsOneWidget);
    });
  });

  group('migration planner', () {
    testWidgets('migration summary appears after comparison selected', (tester) async {
      await pumpSection(tester);
      await tester.pumpAndSettle();

      await controller.selectComparisonTarget(versionV3Id);
      await tester.pumpAndSettle();

      expect(find.text('Total assignments'), findsOneWidget);
      expect(find.text('Safe immediately'), findsOneWidget);
    });
  });

  group('privacy', () {
    testWidgets('rendered copy excludes raw UUIDs', (tester) async {
      await pumpSection(tester);
      await tester.pumpAndSettle();
      await controller.selectComparisonTarget(versionV3Id);
      await tester.pumpAndSettle();

      final text = tester.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '');
      final combined = text.join(' ');
      expect(ProgrammeIntelligenceCopy.containsRawUuid(combined), isFalse);
      expect(combined.contains('assignment-intel-1'), isFalse);
    });
  });

  group('unit widgets', () {
    testWidgets('migration assignment tile hides assignment id', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MigrationAssignmentTile(
              label: 'Assignment 1',
              plan: AssignmentMigrationPlan(
                assignmentId: 'secret-assignment-id',
                assignmentStatus: ProgrammeAssignmentStatus.active,
                currentWeek: 1,
                currentDayKey: 'day_1',
                currentSessionOrder: 1,
                completionPercent: 0,
                currentProgrammePosition: null,
                completedRequiredSlotCount: 0,
                totalRequiredSlotCount: 1,
                hasStarted: false,
                migrationClassification: MigrationClassification.safeImmediate,
                recommendation: 'Assignment has not begun.',
                reasoning: 'No programme differences were found.',
                warnings: const [],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Assignment 1'), findsOneWidget);
      expect(find.textContaining('secret-assignment-id'), findsNothing);
    });
  });
}
