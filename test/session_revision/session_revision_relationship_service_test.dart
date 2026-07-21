import 'package:cohort_platform/features/session_revision/models/content_usage_vocabulary.dart';
import 'package:cohort_platform/features/session_revision/services/session_revision_relationship_service.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';
import '../support/in_memory_session_lineage_store.dart';
import '../support/in_memory_session_revision_relationship_store.dart';
import '../support/session_revision_usage_test_fixtures.dart';

void main() {
  late InMemoryProgrammeTables programmeTables;
  late InMemorySessionLineageStore lineageStore;
  late InMemorySessionRevisionRelationshipStore relationshipStore;
  late SessionRevisionRelationshipService service;

  const sessionLineageId = 'session-lineage-1';
  const protocolV1 = 'BW-001';
  const protocolV2 = 'BW-001-rev-2';

  setUp(() {
    programmeTables = InMemoryProgrammeTables();
    lineageStore = InMemorySessionLineageStore();
    relationshipStore = InMemorySessionRevisionRelationshipStore(
      programmeTables: programmeTables,
    );
    service = SessionRevisionRelationshipService(
      relationshipStore: relationshipStore,
      lineageStore: lineageStore,
    );

    SessionRevisionUsageTestFixtures.seedRevisionMetadata(
      lineageStore,
      protocolId: protocolV1,
      sessionLineageId: sessionLineageId,
      revisionNumber: 1,
    );
    SessionRevisionUsageTestFixtures.seedRevisionMetadata(
      lineageStore,
      protocolId: protocolV2,
      sessionLineageId: sessionLineageId,
      revisionNumber: 2,
    );
  });

  group('direct programme references', () {
    test('revision referenced by one programme version', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: version,
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolV1,
      );

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.programmeReferenceCount, 1);
      expect(summary.slotReferenceCount, 1);
      expect(summary.programmeReferences, hasLength(1));
      expect(summary.programmeReferences.first.programmeVersionId, version.id);
      expect(summary.hasDirectAuthoredUsage, isTrue);
    });

    test('same revision used in multiple slots in one programme version', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: version,
      );
      final dayOne = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-1',
        dayKey: 'day_1',
        dayOrder: 1,
      );
      final dayTwo = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-2',
        dayKey: 'day_2',
        dayOrder: 2,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: dayOne,
        protocolId: protocolV1,
        id: 'slot-1',
        sessionOrder: 1,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: dayTwo,
        protocolId: protocolV1,
        id: 'slot-2',
        sessionOrder: 1,
      );

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.programmeReferenceCount, 1);
      expect(summary.slotReferenceCount, 2);
      expect(summary.programmeReferences, hasLength(2));
    });

    test('same revision used across multiple programme versions', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final versionOne = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-1',
        versionNumber: 1,
      );
      final versionTwo = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-2',
        versionNumber: 2,
      );

      for (final version in [versionOne, versionTwo]) {
        final week = SessionRevisionUsageTestFixtures.seedWeek(
          programmeTables,
          version: version,
          id: 'week-${version.id}',
        );
        final day = SessionRevisionUsageTestFixtures.seedDay(
          programmeTables,
          week: week,
          id: 'day-${version.id}',
        );
        SessionRevisionUsageTestFixtures.seedSlot(
          programmeTables,
          day: day,
          protocolId: protocolV1,
          id: 'slot-${version.id}',
        );
      }

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.programmeReferenceCount, 2);
      expect(summary.slotReferenceCount, 2);
    });

    test('different revisions in same lineage remain separate', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final versionOne = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-1',
        versionNumber: 1,
      );
      final versionTwo = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-2',
        versionNumber: 2,
      );

      for (final entry in [
        (version: versionOne, protocolId: protocolV1),
        (version: versionTwo, protocolId: protocolV2),
      ]) {
        final week = SessionRevisionUsageTestFixtures.seedWeek(
          programmeTables,
          version: entry.version,
          id: 'week-${entry.version.id}',
        );
        final day = SessionRevisionUsageTestFixtures.seedDay(
          programmeTables,
          week: week,
          id: 'day-${entry.version.id}',
        );
        SessionRevisionUsageTestFixtures.seedSlot(
          programmeTables,
          day: day,
          protocolId: entry.protocolId,
          id: 'slot-${entry.version.id}',
        );
      }

      final summaryV1 = await service.getUsageForRevision(protocolV1);
      final summaryV2 = await service.getUsageForRevision(protocolV2);

      expect(summaryV1.programmeReferenceCount, 1);
      expect(summaryV1.programmeReferences.first.programmeVersionNumber, 1);
      expect(summaryV2.programmeReferenceCount, 1);
      expect(summaryV2.programmeReferences.first.programmeVersionNumber, 2);
    });

    test('unused revision returns no direct references', () async {
      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.programmeReferences, isEmpty);
      expect(summary.programmeReferenceCount, 0);
      expect(summary.slotReferenceCount, 0);
      expect(summary.hasDirectAuthoredUsage, isFalse);
      expect(summary.isUnused, isTrue);
    });

    test('archived programme version remains reported', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        lifecycleStatus: ProgrammeLifecycleStatus.archived,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: version,
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolV1,
      );

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.programmeReferences, hasLength(1));
      expect(
        summary.programmeReferences.first.programmeLifecycleStatus,
        ProgrammeLifecycleStatus.archived,
      );
    });
  });

  group('active assignment references', () {
    ProgrammeVersion seedVersionWithProtocol(String protocolId) {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: version,
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolId,
      );
      return version;
    }

    test('active assignment to referencing programme version is reported', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = seedVersionWithProtocol(protocolV1);
      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: version,
        lineage: lineage,
      );

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.activeAssignmentReferences, hasLength(1));
      expect(summary.hasActiveOperationalUsage, isTrue);
    });

    test('assignment to non-referencing programme version is not reported', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final referencingVersion = seedVersionWithProtocol(protocolV1);
      final otherVersion = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-other',
        versionNumber: 2,
      );
      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: otherVersion,
        lineage: lineage,
        id: 'assignment-other',
      );

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.activeAssignmentReferences, isEmpty);
      expect(summary.hasActiveOperationalUsage, isFalse);
      expect(referencingVersion.id, isNot(otherVersion.id));
    });

    test('completed reassigned and paused assignments are excluded', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = seedVersionWithProtocol(protocolV1);

      for (final entry in [
        (status: ProgrammeAssignmentStatus.completed, id: 'assignment-completed'),
        (status: ProgrammeAssignmentStatus.reassigned, id: 'assignment-reassigned'),
        (status: ProgrammeAssignmentStatus.paused, id: 'assignment-paused'),
      ]) {
        SessionRevisionUsageTestFixtures.seedAssignment(
          programmeTables,
          athleteId: entry.id,
          version: version,
          lineage: lineage,
          id: entry.id,
          status: entry.status,
        );
      }

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.activeAssignmentReferences, isEmpty);
    });

    test('multiple active assignments deduplicate by assignment id', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: version,
      );
      final dayOne = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-1',
        dayOrder: 1,
      );
      final dayTwo = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-2',
        dayOrder: 2,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: dayOne,
        protocolId: protocolV1,
        id: 'slot-1',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: dayTwo,
        protocolId: protocolV1,
        id: 'slot-2',
      );
      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: version,
        lineage: lineage,
        id: 'assignment-1',
      );

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.activeAssignmentReferences, hasLength(1));
      expect(summary.activeAssignmentReferences.first.assignmentId, 'assignment-1');
    });

    test('assignment remains linked to old revision after newer programme version exists',
        () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final versionOne = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-1',
        versionNumber: 1,
      );
      final versionTwo = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-2',
        versionNumber: 2,
      );

      for (final entry in [
        (version: versionOne, protocolId: protocolV1),
        (version: versionTwo, protocolId: protocolV2),
      ]) {
        final week = SessionRevisionUsageTestFixtures.seedWeek(
          programmeTables,
          version: entry.version,
          id: 'week-${entry.version.id}',
        );
        final day = SessionRevisionUsageTestFixtures.seedDay(
          programmeTables,
          week: week,
          id: 'day-${entry.version.id}',
        );
        SessionRevisionUsageTestFixtures.seedSlot(
          programmeTables,
          day: day,
          protocolId: entry.protocolId,
          id: 'slot-${entry.version.id}',
        );
      }

      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: versionOne,
        lineage: lineage,
        id: 'assignment-v1',
      );

      final summaryV1 = await service.getUsageForRevision(protocolV1);
      final summaryV2 = await service.getUsageForRevision(protocolV2);

      expect(summaryV1.activeAssignmentReferences, hasLength(1));
      expect(summaryV1.activeAssignmentReferences.first.programmeVersionId,
          versionOne.id);
      expect(summaryV2.activeAssignmentReferences, isEmpty);
    });
  });

  group('historical usage', () {
    test('terminal record with matching source_protocol_id is counted', () async {
      relationshipStore.performanceRecords.add(
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-1',
          athleteId: 'athlete-1',
          sourceProtocolId: protocolV1,
          performedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final usage = await service.getHistoricalUsage(protocolV1);

      expect(usage.recordCount, 1);
      expect(usage.hasUsage, isTrue);
    });

    test('record for different revision is not counted', () async {
      relationshipStore.performanceRecords.add(
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-1',
          athleteId: 'athlete-1',
          sourceProtocolId: protocolV2,
          performedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final usage = await service.getHistoricalUsage(protocolV1);

      expect(usage.recordCount, 0);
    });

    test('earliest and latest performed timestamps are correct', () async {
      relationshipStore.performanceRecords.addAll([
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-1',
          athleteId: 'athlete-1',
          sourceProtocolId: protocolV1,
          performedAt: DateTime.utc(2026, 1, 10),
        ),
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-2',
          athleteId: 'athlete-2',
          sourceProtocolId: protocolV1,
          performedAt: DateTime.utc(2026, 3, 15),
        ),
      ]);

      final usage = await service.getHistoricalUsage(protocolV1);

      expect(usage.recordCount, 2);
      expect(usage.earliestPerformedAt, DateTime.utc(2026, 1, 10));
      expect(usage.latestPerformedAt, DateTime.utc(2026, 3, 15));
    });

    test('no records returns zero summary safely', () async {
      final usage = await service.getHistoricalUsage(protocolV1);

      expect(usage.recordCount, 0);
      expect(usage.earliestPerformedAt, isNull);
      expect(usage.latestPerformedAt, isNull);
    });

    test('archived revision metadata does not affect historical count', () async {
      await lineageStore.updateRevisionLifecycle(
        protocolId: protocolV1,
        lifecycleStatus: SessionRevisionLifecycleStatus.archived,
        archivedAt: DateTime.utc(2026, 4, 1),
      );
      relationshipStore.performanceRecords.add(
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-1',
          athleteId: 'athlete-1',
          sourceProtocolId: protocolV1,
          performedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final usage = await service.getHistoricalUsage(protocolV1);

      expect(usage.recordCount, 1);
    });
  });

  group('combined summary', () {
    test('classifications cover direct operational historical unused and all three',
        () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: version,
      );
      final day = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolV1,
      );
      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: version,
        lineage: lineage,
      );
      relationshipStore.performanceRecords.add(
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-1',
          athleteId: 'athlete-1',
          sourceProtocolId: protocolV1,
          performedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      final allThree = await service.getUsageForRevision(protocolV1);
      expect(allThree.classifications, [
        ContentUsageClassification.directAuthored,
        ContentUsageClassification.activeOperational,
        ContentUsageClassification.historicalPerformance,
      ]);

      programmeTables.slots.clear();
      programmeTables.assignments.clear();
      relationshipStore.performanceRecords.clear();

      final directOnlySummary = await service.getUsageForRevision(protocolV1);
      expect(directOnlySummary.classifications, isEmpty);
      expect(directOnlySummary.isUnused, isTrue);

      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: day,
        protocolId: protocolV1,
      );
      final directOnly = await service.getUsageForRevision(protocolV1);
      expect(directOnly.classifications,
          [ContentUsageClassification.directAuthored]);

      relationshipStore.performanceRecords.add(
        SessionRevisionUsageTestFixtures.seedTerminalRecord(
          recordId: 'record-historical',
          athleteId: 'athlete-2',
          sourceProtocolId: protocolV1,
          performedAt: DateTime.utc(2026, 2, 2),
        ),
      );
      final historicalOnly = await service.getUsageForRevision(protocolV1);
      expect(historicalOnly.classifications, containsAll([
        ContentUsageClassification.directAuthored,
        ContentUsageClassification.historicalPerformance,
      ]));
      expect(historicalOnly.hasActiveOperationalUsage, isFalse);
    });

    test('programme-level and slot-level counts are distinct', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(programmeTables);
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        programmeTables,
        version: version,
      );
      final dayOne = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-1',
        dayOrder: 1,
      );
      final dayTwo = SessionRevisionUsageTestFixtures.seedDay(
        programmeTables,
        week: week,
        id: 'day-2',
        dayOrder: 2,
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: dayOne,
        protocolId: protocolV1,
        id: 'slot-1',
      );
      SessionRevisionUsageTestFixtures.seedSlot(
        programmeTables,
        day: dayTwo,
        protocolId: protocolV1,
        id: 'slot-2',
      );

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.programmeReferenceCount, 1);
      expect(summary.slotReferenceCount, 2);
    });

    test('stable result ordering and no duplicate assignment references', () async {
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(
        programmeTables,
        code: 'PROG-B',
      );
      final lineageA = SessionRevisionUsageTestFixtures.seedLineage(
        programmeTables,
        id: 'lineage-a',
        code: 'PROG-A',
      );
      final versionB = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineage,
        id: 'version-b',
        versionNumber: 2,
        name: 'Programme B',
      );
      final versionA = SessionRevisionUsageTestFixtures.seedVersion(
        programmeTables,
        lineage: lineageA,
        id: 'version-a',
        versionNumber: 1,
        name: 'Programme A',
      );

      for (final entry in [
        (version: versionA, slotId: 'slot-a'),
        (version: versionB, slotId: 'slot-b'),
      ]) {
        final week = SessionRevisionUsageTestFixtures.seedWeek(
          programmeTables,
          version: entry.version,
          id: 'week-${entry.version.id}',
        );
        final day = SessionRevisionUsageTestFixtures.seedDay(
          programmeTables,
          week: week,
          id: 'day-${entry.version.id}',
          dayOrder: 2,
        );
        SessionRevisionUsageTestFixtures.seedSlot(
          programmeTables,
          day: day,
          protocolId: protocolV1,
          id: entry.slotId,
          sessionOrder: 2,
        );
      }

      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-1',
        version: versionA,
        lineage: lineageA,
        id: 'assignment-a',
      );
      SessionRevisionUsageTestFixtures.seedAssignment(
        programmeTables,
        athleteId: 'athlete-2',
        version: versionB,
        lineage: lineage,
        id: 'assignment-b',
      );

      final summary = await service.getUsageForRevision(protocolV1);

      expect(summary.programmeReferences.first.programmeLineageCode, 'PROG-A');
      expect(summary.programmeReferences.last.programmeLineageCode, 'PROG-B');
      expect(
        summary.activeAssignmentReferences.map((row) => row.assignmentId),
        ['assignment-a', 'assignment-b'],
      );
      expect(
        summary.activeAssignmentReferences.map((row) => row.assignmentId).toSet(),
        hasLength(summary.activeAssignmentReferences.length),
      );
    });
  });
}
