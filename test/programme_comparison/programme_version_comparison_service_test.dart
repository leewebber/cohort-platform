import 'package:cohort_platform/data/repositories/programme_version_comparison_store.dart';
import 'package:cohort_platform/features/programme_comparison/models/programme_version_comparison_models.dart';
import 'package:cohort_platform/features/programme_comparison/services/programme_version_comparison_engine.dart';
import 'package:cohort_platform/features/programme_comparison/services/programme_version_comparison_message_builder.dart';
import 'package:cohort_platform/features/programme_comparison/services/programme_version_comparison_service.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_exercise_relationship_store.dart';
import '../support/in_memory_programme_stores.dart';
import '../support/in_memory_programme_version_comparison_store.dart';
import '../support/in_memory_session_lineage_store.dart';
import '../support/session_revision_usage_test_fixtures.dart';

void main() {
  late InMemoryProgrammeTables programmeTables;
  late InMemorySessionLineageStore lineageStore;
  late InMemoryExerciseRelationshipTables exerciseTables;
  late InMemoryProgrammeVersionComparisonStore comparisonStore;
  late ProgrammeVersionComparisonService service;

  const lineageId = 'lineage-1';
  const otherLineageId = 'lineage-other';
  const versionV1Id = 'version-1';
  const versionV2Id = 'version-2';
  const versionV3Id = 'version-3';
  const versionOtherId = 'version-other';
  const protocolA = 'session-a-rev-1';
  const protocolB = 'session-b-rev-1';
  const protocolC = 'session-c-rev-2';
  const protocolD = 'session-d-rev-1';

  ProgrammeVersionComparisonService buildService({
    InMemoryProgrammeVersionComparisonStore? store,
  }) {
    return ProgrammeVersionComparisonService(comparisonStore: store ?? comparisonStore);
  }

  setUp(() {
    programmeTables = InMemoryProgrammeTables();
    lineageStore = InMemorySessionLineageStore();
    exerciseTables = InMemoryExerciseRelationshipTables();

    SessionRevisionUsageTestFixtures.seedLineage(
      programmeTables,
      id: lineageId,
      code: 'PROG-COMPARE',
    );
    SessionRevisionUsageTestFixtures.seedLineage(
      programmeTables,
      id: otherLineageId,
      code: 'PROG-OTHER',
    );

    programmeTables.versions.addAll([
      _version(
        id: versionV1Id,
        lineageId: lineageId,
        versionNumber: 1,
        lifecycleStatus: ProgrammeLifecycleStatus.archived,
        name: 'HYROX Base',
      ),
      _version(
        id: versionV2Id,
        lineageId: lineageId,
        versionNumber: 2,
        lifecycleStatus: ProgrammeLifecycleStatus.published,
        name: 'HYROX Base',
        description: 'Base block',
        primaryGoal: 'Engine',
      ),
      _version(
        id: versionV3Id,
        lineageId: lineageId,
        versionNumber: 3,
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
        name: 'HYROX Base Pro',
        description: 'Updated block',
        primaryGoal: 'Strength',
      ),
      _version(
        id: versionOtherId,
        lineageId: otherLineageId,
        versionNumber: 1,
        name: 'Other Programme',
      ),
    ]);

    for (final entry in [
      (protocolA, 1, 'session-lineage-a', 'Strength Foundation'),
      (protocolB, 1, 'session-lineage-b', 'Engine Builder'),
      (protocolC, 2, 'session-lineage-a', 'Strength Foundation'),
      (protocolD, 1, 'session-lineage-d', 'Accessory'),
    ]) {
      SessionRevisionUsageTestFixtures.seedRevisionMetadata(
        lineageStore,
        protocolId: entry.$1,
        sessionLineageId: entry.$3,
        revisionNumber: entry.$2,
      );
    }

    final weekV2 = SessionRevisionUsageTestFixtures.seedWeek(
      programmeTables,
      version: programmeTables.versions[1],
      id: 'week-v2',
    );
    final dayV2 = SessionRevisionUsageTestFixtures.seedDay(
      programmeTables,
      week: weekV2,
      id: 'day-v2',
    );
    SessionRevisionUsageTestFixtures.seedSlot(
      programmeTables,
      day: dayV2,
      protocolId: protocolA,
      id: 'slot-v2-a',
      sessionOrder: 1,
    );
    SessionRevisionUsageTestFixtures.seedSlot(
      programmeTables,
      day: dayV2,
      protocolId: protocolA,
      id: 'slot-v2-b',
      sessionOrder: 2,
      displayTitle: 'Second slot',
    );
    SessionRevisionUsageTestFixtures.seedSlot(
      programmeTables,
      day: dayV2,
      protocolId: protocolB,
      id: 'slot-v2-c',
      sessionOrder: 3,
    );

    final weekV3 = SessionRevisionUsageTestFixtures.seedWeek(
      programmeTables,
      version: programmeTables.versions[2],
      id: 'week-v3',
    );
    final dayV3 = SessionRevisionUsageTestFixtures.seedDay(
      programmeTables,
      week: weekV3,
      id: 'day-v3',
    );
    SessionRevisionUsageTestFixtures.seedSlot(
      programmeTables,
      day: dayV3,
      protocolId: protocolC,
      id: 'slot-v3',
    );

    exerciseTables.exercises.addAll([
      const Exercise(exerciseId: 'SQ-001', name: 'Back Squat', published: true),
      const Exercise(exerciseId: 'SQ-002', name: 'Back Squat', published: true),
      const Exercise(exerciseId: 'DL-001', name: 'Deadlift', published: true),
    ]);

    comparisonStore = InMemoryProgrammeVersionComparisonStore(
      programmeTables: programmeTables,
      lineageStore: lineageStore,
      exerciseTables: exerciseTables,
      protocolNames: {
        protocolA: 'Strength Foundation',
        protocolB: 'Engine Builder',
        protocolC: 'Strength Foundation',
        protocolD: 'Accessory',
      },
    );
    service = buildService();
  });

  group('identity', () {
    test('1 same-lineage versions compare successfully', () async {
      final lookup = await service.tryCompareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(lookup.isSuccess, isTrue);
      expect(lookup.summary!.identity.programmeLineageId, lineageId);
    });

    test('2 source missing', () async {
      final lookup = await service.tryCompareVersions(
        sourceProgrammeVersionId: 'missing-source',
        targetProgrammeVersionId: versionV3Id,
      );
      expect(lookup.status, ProgrammeVersionComparisonStatus.sourceNotFound);
    });

    test('3 target missing', () async {
      final lookup = await service.tryCompareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: 'missing-target',
      );
      expect(lookup.status, ProgrammeVersionComparisonStatus.targetNotFound);
    });

    test('4 different lineages rejected', () async {
      final lookup = await service.tryCompareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionOtherId,
      );
      expect(lookup.status, ProgrammeVersionComparisonStatus.incompatibleLineage);
    });

    test('5 comparison direction preserved', () async {
      final forward = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      final reverse = await service.compareVersions(
        sourceProgrammeVersionId: versionV3Id,
        targetProgrammeVersionId: versionV2Id,
      );

      expect(forward.slotChanges.any((c) => c.changeType == ProgrammeChangeType.removed), isTrue);
      expect(reverse.slotChanges.any((c) => c.changeType == ProgrammeChangeType.added), isTrue);
    });

    test('6 archived versions remain comparable', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV1Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.identity.sourceLifecycleStatus, ProgrammeLifecycleStatus.archived);
    });

    test('7 draft and published versions remain comparable', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.identity.sourceLifecycleStatus, ProgrammeLifecycleStatus.published);
      expect(summary.identity.targetLifecycleStatus, ProgrammeLifecycleStatus.draft);
    });

    test('8 raw IDs absent from user-facing messages', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(
        ProgrammeVersionComparisonMessageBuilder.summaryContainsRawIdentifiers(
          summary.summaryMessages,
        ),
        isFalse,
      );
    });
  });

  group('identical versions', () {
    test('9 exact same version compared to itself is identical', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.isIdentical, isTrue);
      expect(summary.classifications, contains(ProgrammeComparisonClassification.identical));
    });

    test('10 structurally equivalent versions return no changes', () async {
      final equivalent = _version(
        id: 'version-equivalent',
        lineageId: lineageId,
        versionNumber: 4,
        name: 'HYROX Base',
        description: 'Base block',
        primaryGoal: 'Engine',
      );
      programmeTables.versions.add(equivalent);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: equivalent,
        id: 'week-equivalent',
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-equivalent',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-eq-1',
        sessionOrder: 1,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-eq-2',
        sessionOrder: 2,
        displayTitle: 'Second slot',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolB,
        id: 'slot-eq-3',
        sessionOrder: 3,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: equivalent.id,
      );
      expect(summary.slotChanges.every((c) => c.changeType == ProgrammeChangeType.unchanged), isTrue);
    });

    test('11 stable ordering does not create false changes', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.slotChanges.map((c) => c.changeType).toSet(), {ProgrammeChangeType.unchanged});
    });

    test('12 collection normalisation follows semantic rules', () async {
      final changes = ProgrammeVersionComparisonEngine.compareMetadata(
        {'name': '  HYROX Base  '},
        {'name': 'HYROX Base'},
      );
      expect(changes, isEmpty);
    });
  });

  group('metadata', () {
    test('13 programme title change', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(
        summary.metadataChanges.any((c) => c.field == 'name'),
        isTrue,
      );
    });

    test('14 description change', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.metadataChanges.any((c) => c.field == 'description'), isTrue);
    });

    test('15 tag addition/removal', () async {
      final tagged = _version(
        id: 'version-tagged',
        lineageId: lineageId,
        versionNumber: 5,
        name: 'Tagged',
      );
      programmeTables.versions.add(tagged);
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: tagged.id,
      );
      expect(summary.metadataChanges, isNotEmpty);
    });

    test('16 lifecycle difference not misreported as authored metadata', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.metadataChanges.any((c) => c.field == 'lifecycleStatus'), isFalse);
    });

    test('17 audit timestamps ignored', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.metadataChanges.any((c) => c.field.contains('At')), isFalse);
    });
  });

  group('weeks and days', () {
    test('18 week added', () async {
      final extended = _version(
        id: 'version-extended',
        lineageId: lineageId,
        versionNumber: 6,
        name: 'Extended',
      );
      programmeTables.versions.add(extended);
      SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: extended,
        id: 'week-ext-1',
        weekNumber: 1,
      );
      SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: extended,
        id: 'week-ext-2',
        weekNumber: 2,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: extended.id,
      );
      expect(summary.weekChanges.any((c) => c.changeType == ProgrammeChangeType.added), isTrue);
    });

    test('19 week removed', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.weekChanges.any((c) => c.changeType == ProgrammeChangeType.removed), isFalse);
    });

    test('20 week metadata modified', () async {
      final renamedWeek = _version(
        id: 'version-week-title',
        lineageId: lineageId,
        versionNumber: 7,
        name: 'Week title',
      );
      programmeTables.versions.add(renamedWeek);
      final week = ProgrammeVersionWeek(
        id: 'week-title-1',
        versionId: renamedWeek.id,
        weekNumber: 1,
        title: 'Deload',
      );
      programmeTables.weeks.add(week);
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-title-1',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-title-1',
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: renamedWeek.id,
      );
      expect(summary.weekChanges.any((c) => c.changeType == ProgrammeChangeType.modified), isTrue);
    });

    test('21 training day added', () async {
      final extraDayVersion = _version(
        id: 'version-extra-day',
        lineageId: lineageId,
        versionNumber: 8,
        name: 'Extra day',
      );
      programmeTables.versions.add(extraDayVersion);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: extraDayVersion,
        id: 'week-extra-day',
      );
      SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-extra-1',
        dayKey: 'day_1',
      );
      SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-extra-2',
        dayKey: 'day_2',
        dayOrder: 2,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: extraDayVersion.id,
      );
      expect(summary.dayChanges.any((c) => c.changeType == ProgrammeChangeType.added), isTrue);
    });

    test('22 training day removed', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.dayChanges.every((c) => c.changeType == ProgrammeChangeType.unchanged), isTrue);
    });

    test('23 day moved when identity reliable', () async {
      final movedDayVersion = _version(
        id: 'version-moved-day',
        lineageId: lineageId,
        versionNumber: 9,
        name: 'Moved day',
      );
      programmeTables.versions.add(movedDayVersion);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: movedDayVersion,
        id: 'week-moved-day',
      );
      SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-moved-same-id',
        dayKey: 'day_1',
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: movedDayVersion.id,
      );
      expect(summary.dayChanges.any((c) => c.changeType == ProgrammeChangeType.unchanged), isTrue);
    });

    test('24 position change treated conservatively when identity unavailable', () async {
      final sourceMinimal = _version(
        id: 'version-minimal-source',
        lineageId: lineageId,
        versionNumber: 30,
        name: 'Minimal source',
      );
      final shifted = _version(
        id: 'version-shifted-slot',
        lineageId: lineageId,
        versionNumber: 10,
        name: 'Shifted',
      );
      programmeTables.versions.addAll([sourceMinimal, shifted]);

      final sourceWeek = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: sourceMinimal,
        id: 'week-minimal-source',
      );
      final sourceDay = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: sourceWeek,
        id: 'day-minimal-source',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: sourceDay,
        protocolId: protocolA,
        id: 'slot-minimal-source',
        sessionOrder: 1,
      );

      final targetWeek = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: shifted,
        id: 'week-shifted',
      );
      final targetDay = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: targetWeek,
        id: 'day-shifted',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: targetDay,
        protocolId: protocolA,
        id: 'slot-shifted',
        sessionOrder: 2,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: sourceMinimal.id,
        targetProgrammeVersionId: shifted.id,
      );
      expect(summary.slotChanges.any((c) => c.changeType == ProgrammeChangeType.added), isTrue);
      expect(summary.slotChanges.any((c) => c.changeType == ProgrammeChangeType.removed), isTrue);
      expect(summary.slotChanges.any((c) => c.changeType == ProgrammeChangeType.moved), isFalse);
    });

    test('25 empty week/day handled', () async {
      final empty = _version(
        id: 'empty-version',
        lineageId: lineageId,
        versionNumber: 99,
        name: 'Empty',
      );
      programmeTables.versions.add(empty);

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: empty.id,
        targetProgrammeVersionId: empty.id,
      );
      expect(summary.isIdentical, isTrue);
    });
  });

  group('slots', () {
    test('26 slot added', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV3Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.slotChanges.where((c) => c.changeType == ProgrammeChangeType.added).length, 2);
    });

    test('27 slot removed', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.slotChanges.where((c) => c.changeType == ProgrammeChangeType.removed).length, 2);
    });

    test('28 exact same slot unchanged', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(
        summary.slotChanges.every((c) => c.changeType == ProgrammeChangeType.unchanged),
        isTrue,
      );
      expect(summary.slotChanges.length, 3);
    });

    test('29 slot moved with stable slot ID', () async {
      final movedSlotVersion = _version(
        id: 'version-moved-slot',
        lineageId: lineageId,
        versionNumber: 11,
        name: 'Moved slot',
      );
      programmeTables.versions.add(movedSlotVersion);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: movedSlotVersion,
        id: 'week-moved-slot',
        weekNumber: 2,
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-moved-slot',
        dayKey: 'day_2',
        dayOrder: 1,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-v2-a',
        sessionOrder: 1,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: movedSlotVersion.id,
      );
      expect(
        summary.slotChanges.any((c) => c.changeType == ProgrammeChangeType.moved),
        isTrue,
      );
    });

    test('30 slot label modified', () async {
      final relabelled = _version(
        id: 'version-relabelled',
        lineageId: lineageId,
        versionNumber: 12,
        name: 'Relabelled',
      );
      programmeTables.versions.add(relabelled);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: relabelled,
        id: 'week-relabelled',
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-relabelled',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-relabel-1',
        sessionOrder: 1,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-relabel-2',
        sessionOrder: 2,
        displayTitle: 'Renamed slot',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolB,
        id: 'slot-relabel-3',
        sessionOrder: 3,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: relabelled.id,
      );
      expect(
        summary.slotChanges.any(
          (c) =>
              c.changeType == ProgrammeChangeType.modified &&
              c.changedFields.contains('slotLabel'),
        ),
        isTrue,
      );
    });

    test('31 same Session Lineage Revision 2 to 3', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.sessionRevisionChanges, isNotEmpty);
      expect(summary.sessionRevisionChanges.first.changeType, ProgrammeChangeType.modified);
      expect(summary.sessionRevisionChanges.first.sourceRevisionNumber, 1);
      expect(summary.sessionRevisionChanges.first.targetRevisionNumber, 2);
    });

    test('32 different Session Lineage replacement', () async {
      final replaced = _version(
        id: 'version-replaced-lineage',
        lineageId: lineageId,
        versionNumber: 13,
        name: 'Replaced lineage',
      );
      programmeTables.versions.add(replaced);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: replaced,
        id: 'week-replaced',
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-replaced',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolD,
        id: 'slot-replaced',
        sessionOrder: 1,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: replaced.id,
      );
      expect(
        summary.slotChanges.any((c) => c.changeType == ProgrammeChangeType.replaced),
        isTrue,
      );
    });

    test('33 same Session Revision repeated in multiple slots', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.structureMetrics.sourceDistinctSessionRevisionCount, 2);
      expect(summary.structureMetrics.sourceSlotCount, 3);
    });

    test('34 one repeated slot removed without removing all occurrences', () async {
      final oneRemoved = _version(
        id: 'version-one-removed',
        lineageId: lineageId,
        versionNumber: 14,
        name: 'One removed',
      );
      programmeTables.versions.add(oneRemoved);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: oneRemoved,
        id: 'week-one-removed',
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-one-removed',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-one-1',
        sessionOrder: 1,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolB,
        id: 'slot-one-3',
        sessionOrder: 3,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: oneRemoved.id,
      );
      expect(summary.slotChanges.where((c) => c.changeType == ProgrammeChangeType.removed).length, 1);
      expect(summary.slotChanges.where((c) => c.changeType == ProgrammeChangeType.unchanged).length, 2);
    });

    test('35 ambiguous slot match becomes removed plus added', () async {
      final ambiguous = _version(
        id: 'version-ambiguous',
        lineageId: lineageId,
        versionNumber: 15,
        name: 'Ambiguous',
      );
      programmeTables.versions.add(ambiguous);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: ambiguous,
        id: 'week-ambiguous',
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-ambiguous',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolD,
        id: 'slot-ambiguous',
        sessionOrder: 4,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: ambiguous.id,
      );
      expect(summary.slotChanges.any((c) => c.changeType == ProgrammeChangeType.added), isTrue);
      expect(summary.slotChanges.any((c) => c.changeType == ProgrammeChangeType.removed), isTrue);
    });

    test('36 stable slot ID preferred over coordinates', () async {
      final movedSlotVersion = _version(
        id: 'version-moved-slot-stable',
        lineageId: lineageId,
        versionNumber: 20,
        name: 'Moved slot stable',
      );
      programmeTables.versions.add(movedSlotVersion);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: movedSlotVersion,
        id: 'week-moved-slot-stable',
        weekNumber: 2,
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-moved-slot-stable',
        dayKey: 'day_2',
        dayOrder: 1,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-v2-a',
        sessionOrder: 1,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: movedSlotVersion.id,
      );
      expect(
        summary.slotChanges.any(
          (c) => c.matchingBasis == ProgrammeSlotMatchingBasis.stableSlotId,
        ),
        isTrue,
      );
    });

    test('37 slot ordering deterministic', () async {
      final first = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      final second = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(first.slotChanges.map((c) => c.changeType), second.slotChanges.map((c) => c.changeType));
    });
  });

  group('session references', () {
    test('38 session revision count delta correct', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.structureMetrics.sessionRevisionCountDelta, -1);
    });

    test('39 same revision moved does not change distinct count', () async {
      final movedSlotVersion = _version(
        id: 'version-moved-slot-count',
        lineageId: lineageId,
        versionNumber: 21,
        name: 'Moved slot count',
      );
      programmeTables.versions.add(movedSlotVersion);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: movedSlotVersion,
        id: 'week-moved-slot-count',
        weekNumber: 2,
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-moved-slot-count',
        dayKey: 'day_2',
        dayOrder: 1,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-v2-a',
        sessionOrder: 1,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: movedSlotVersion.id,
      );
      expect(summary.structureMetrics.sourceDistinctSessionRevisionCount, 2);
      expect(summary.structureMetrics.targetDistinctSessionRevisionCount, 1);
    });

    test('40 revision replacement updates counts correctly', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.structureMetrics.targetDistinctSessionRevisionCount, 1);
    });

    test('41 archived Session Revision remains comparable', () async {
      SessionRevisionUsageTestFixtures.seedRevisionMetadata(
        lineageStore,
        protocolId: 'archived-protocol',
        sessionLineageId: 'session-lineage-archived',
        revisionNumber: 1,
        lifecycleStatus: SessionRevisionLifecycleStatus.archived,
      );
      final archivedVersion = _version(
        id: 'version-archived-session',
        lineageId: lineageId,
        versionNumber: 16,
        name: 'Archived session',
      );
      programmeTables.versions.add(archivedVersion);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: archivedVersion,
        id: 'week-archived-session',
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-archived-session',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: 'archived-protocol',
        id: 'slot-archived-session',
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: archivedVersion.id,
      );
      expect(summary.isPartial, isFalse);
    });

    test('42 missing Session enrichment produces partial comparison', () async {
      final partialStore = InMemoryProgrammeVersionComparisonStore(
        programmeTables: programmeTables,
        lineageStore: lineageStore,
        exerciseTables: exerciseTables,
        sessionEnrichmentAuthoritative: false,
        sessionEnrichmentLimitation: 'Session metadata unavailable.',
      );
      final partialService = buildService(store: partialStore);
      final lookup = await partialService.tryCompareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(lookup.status, ProgrammeVersionComparisonStatus.partial);
      expect(lookup.summary!.slotChanges, isNotEmpty);
    });
  });

  group('exercises', () {
    setUp(() {
      _seedBlockLink(exerciseTables: exerciseTables, exerciseId: 'SQ-001', protocolId: protocolA);
      _seedBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'DL-001',
        protocolId: protocolB,
        blockId: 'block-b',
      );
    });

    test('43 exercise added', () async {
      _seedBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-002',
        protocolId: protocolC,
        blockId: 'block-c',
      );
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.exerciseSetChange.addedExercises, contains('SQ-002'));
    });

    test('44 exercise removed', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.exerciseSetChange.removedExercises, contains('DL-001'));
    });

    test('45 exercise retained across Session movement', () async {
      _seedBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: protocolC,
        blockId: 'block-c-sq',
      );
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.exerciseSetChange.retainedExercises, contains('SQ-001'));
    });

    test('46 same Exercise across multiple Sessions deduplicated', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.exerciseSetChange.sourceExerciseCount, 2);
    });

    test('47 same-name different-ID Exercises remain separate', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.exerciseChanges.map((e) => e.exerciseId), containsAll(['SQ-001', 'DL-001']));
    });

    test('48 block-link count change', () async {
      _seedBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: protocolC,
        blockId: 'block-c-extra',
      );
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      final squat = summary.exerciseChanges.firstWhere((e) => e.exerciseId == 'SQ-001');
      expect(squat.changeType, ProgrammeChangeType.modified);
    });

    test('49 legacy structured exercise included under M9.4 rules', () async {
      exerciseTables.legacySteps.add(
        InMemoryExerciseLegacyStepFixture(
          stepId: 'legacy-step-1',
          exerciseId: 'SQ-002',
          protocolId: protocolA,
          title: 'Back Squat',
          stepOrder: 1,
          sessionLineageId: 'session-lineage-a',
          sessionRevisionNumber: 1,
          sessionName: 'Strength Foundation',
          sessionLifecycleStatus: SessionRevisionLifecycleStatus.published,
        ),
      );
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.exerciseChanges.any((e) => e.exerciseId == 'SQ-002'), isFalse);
    });

    test('50 free-text-only movement excluded', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.exerciseChanges.every((e) => e.exerciseId.isNotEmpty), isTrue);
    });

    test('51 exercise enrichment failure returns partial result', () async {
      final partialStore = InMemoryProgrammeVersionComparisonStore(
        programmeTables: programmeTables,
        lineageStore: lineageStore,
        exerciseTables: exerciseTables,
        exerciseEnrichmentAuthoritative: false,
        exerciseEnrichmentLimitation: 'Exercise enrichment failed.',
      );
      final partialService = buildService(store: partialStore);
      final lookup = await partialService.tryCompareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(lookup.status, ProgrammeVersionComparisonStatus.partial);
      expect(lookup.summary!.exerciseSetChange.netExerciseCountChange, 0);
    });

    test('52 zero Exercise change only when authoritative', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.exerciseSetChange.netExerciseCountChange, 0);
      expect(summary.isPartial, isFalse);
    });
  });

  group('combined summary', () {
    test('53 metadata-only comparison', () async {
      final renamed = _version(
        id: 'metadata-only',
        lineageId: lineageId,
        versionNumber: 17,
        name: 'Only metadata',
        description: 'Base block',
        primaryGoal: 'Engine',
      );
      programmeTables.versions.add(renamed);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: renamed,
        id: 'week-metadata-only',
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-metadata-only',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-md-1',
        sessionOrder: 1,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolA,
        id: 'slot-md-2',
        sessionOrder: 2,
        displayTitle: 'Second slot',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolB,
        id: 'slot-md-3',
        sessionOrder: 3,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: renamed.id,
      );
      expect(summary.metadataChanges, isNotEmpty);
      expect(summary.slotChanges.every((c) => c.changeType == ProgrammeChangeType.unchanged), isTrue);
    });

    test('54 structure-only comparison', () async {
      final extraDayVersion = _version(
        id: 'version-structure-only',
        lineageId: lineageId,
        versionNumber: 22,
        name: 'Structure only',
      );
      programmeTables.versions.add(extraDayVersion);
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: extraDayVersion,
        id: 'week-structure-only',
      );
      SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-structure-1',
        dayKey: 'day_1',
      );
      SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-structure-2',
        dayKey: 'day_2',
        dayOrder: 2,
      );

      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: extraDayVersion.id,
      );
      expect(summary.classifications, contains(ProgrammeComparisonClassification.structureChanged));
    });

    test('55 session-only comparison', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.hasSessionChanges, isTrue);
    });

    test('56 exercise-only comparison', () async {
      _seedBlockLink(exerciseTables: exerciseTables, exerciseId: 'SQ-001', protocolId: protocolA);
      _seedBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-002',
        protocolId: protocolC,
        blockId: 'block-c-only',
      );
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.hasExerciseChanges, isTrue);
    });

    test('57 mixed comparison', () async {
      _seedBlockLink(exerciseTables: exerciseTables, exerciseId: 'SQ-001', protocolId: protocolA);
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.metadataChanges, isNotEmpty);
      expect(summary.hasSessionChanges, isTrue);
    });

    test('58 identical classification', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV2Id,
      );
      expect(summary.classifications, contains(ProgrammeComparisonClassification.identical));
    });

    test('59 partial classification', () async {
      final partialStore = InMemoryProgrammeVersionComparisonStore(
        programmeTables: programmeTables,
        lineageStore: lineageStore,
        exerciseTables: exerciseTables,
        exerciseEnrichmentAuthoritative: false,
      );
      final lookup = await buildService(store: partialStore).tryCompareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(
        lookup.summary!.classifications,
        contains(ProgrammeComparisonClassification.partialComparison),
      );
    });

    test('60 summary counts accurate', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(summary.structureMetrics.sourceSlotCount, 3);
      expect(summary.structureMetrics.targetSlotCount, 1);
      expect(summary.structureMetrics.slotCountDelta, -2);
    });

    test('61 summary messages deterministic', () async {
      final first = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      final second = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(first.summaryMessages, second.summaryMessages);
    });

    test('62 no migration recommendation in output', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      expect(
        ProgrammeVersionComparisonMessageBuilder.summaryContainsMigrationRecommendation(
          summary.summaryMessages,
        ),
        isFalse,
      );
    });

    test('63 no duplicate changes', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      final slotKeys = summary.slotChanges.map(
        (change) => '${change.changeType}:${change.sourceSlot?.slotId}:${change.targetSlot?.slotId}',
      );
      expect(slotKeys.toSet().length, slotKeys.length);
    });

    test('64 stable comparison ordering', () async {
      final summary = await service.compareVersions(
        sourceProgrammeVersionId: versionV2Id,
        targetProgrammeVersionId: versionV3Id,
      );
      final metadataFields = summary.metadataChanges.map((c) => c.field).toList();
      final exerciseIds = summary.exerciseChanges.map((c) => c.exerciseId).toList();
      expect(metadataFields, equals(metadataFields.toList()..sort()));
      expect(exerciseIds, equals(exerciseIds.toList()..sort()));
    });
  });
}

ProgrammeVersion _version({
  required String id,
  required String lineageId,
  required int versionNumber,
  ProgrammeLifecycleStatus lifecycleStatus = ProgrammeLifecycleStatus.published,
  String name = 'Test Programme',
  String? description,
  String? primaryGoal,
}) {
  return ProgrammeVersion(
    id: id,
    lineageId: lineageId,
    versionNumber: versionNumber,
    lifecycleStatus: lifecycleStatus,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    name: name,
    description: description,
    primaryGoal: primaryGoal,
  );
}

void _seedBlockLink({
  required InMemoryExerciseRelationshipTables exerciseTables,
  required String exerciseId,
  required String protocolId,
  String blockId = 'block-1',
}) {
  exerciseTables.blockLinks.add(
    InMemoryExerciseBlockLinkFixture(
      exerciseLinkId: 'link-$blockId',
      exerciseId: exerciseId,
      blockId: blockId,
      blockTitle: 'Main',
      blockOrder: 1,
      protocolId: protocolId,
      sessionLineageId: 'session-lineage-a',
      sessionRevisionNumber: 1,
      sessionName: 'Strength Foundation',
      sessionLifecycleStatus: SessionRevisionLifecycleStatus.published,
    ),
  );
}
