import 'package:cohort_platform/data/repositories/programme_version_impact_store.dart';
import 'package:cohort_platform/features/performance/models/performance_snapshot.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/programme_impact/models/programme_version_impact_models.dart';
import 'package:cohort_platform/features/programme_impact/services/programme_version_impact_message_builder.dart';
import 'package:cohort_platform/features/programme_impact/services/programme_version_impact_service.dart';
import 'package:cohort_platform/features/session_revision/models/content_usage_vocabulary.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_slot_outcome.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_exercise_relationship_store.dart';
import '../support/in_memory_programme_stores.dart';
import '../support/in_memory_programme_version_impact_store.dart';
import '../support/in_memory_session_lineage_store.dart';
import '../support/session_revision_usage_test_fixtures.dart';

InMemoryProgrammeTables _currentProgrammeTables = InMemoryProgrammeTables();

void main() {
  late InMemoryProgrammeTables programmeTables;
  late InMemorySessionLineageStore lineageStore;
  late InMemoryExerciseRelationshipTables exerciseTables;
  late InMemoryProgrammeVersionImpactStore impactStore;
  late ProgrammeVersionImpactService service;

  const versionV1Id = 'version-1';
  const versionV2Id = 'version-2';
  const versionV3Id = 'version-3';
  const lineageId = 'lineage-1';
  const protocolA = 'session-a-rev-1';
  const protocolB = 'session-b-rev-1';
  const protocolC = 'session-c-rev-2';
  const slotV2A = 'slot-v2-a';
  const slotV2B = 'slot-v2-b';
  const slotV3 = 'slot-v3';

  late List<TrainingSessionRecord> performanceRecords;

  ProgrammeVersionImpactService buildService({
    InMemoryProgrammeVersionImpactStore? store,
  }) {
    return ProgrammeVersionImpactService(impactStore: store ?? impactStore);
  }

  setUp(() {
    programmeTables = InMemoryProgrammeTables();
    _currentProgrammeTables = programmeTables;
    lineageStore = InMemorySessionLineageStore();
    exerciseTables = InMemoryExerciseRelationshipTables();

    final lineage = SessionRevisionUsageTestFixtures.seedLineage(
      programmeTables,
      id: lineageId,
      code: 'PROG-IMPACT',
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
      ),
      _version(
        id: versionV3Id,
        lineageId: lineageId,
        versionNumber: 3,
        lifecycleStatus: ProgrammeLifecycleStatus.draft,
        name: 'HYROX Base',
      ),
    ]);

    _seedSessionMetadata(
      lineageStore: lineageStore,
      protocolId: protocolA,
      revisionNumber: 1,
      lifecycle: SessionRevisionLifecycleStatus.published,
      sessionLineageId: 'session-lineage-a',
      name: 'Strength Foundation',
    );
    _seedSessionMetadata(
      lineageStore: lineageStore,
      protocolId: protocolB,
      revisionNumber: 1,
      lifecycle: SessionRevisionLifecycleStatus.published,
      sessionLineageId: 'session-lineage-b',
      name: 'Engine Builder',
    );
    _seedSessionMetadata(
      lineageStore: lineageStore,
      protocolId: protocolC,
      revisionNumber: 2,
      lifecycle: SessionRevisionLifecycleStatus.published,
      sessionLineageId: 'session-lineage-a',
      name: 'Strength Foundation',
    );

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
      id: slotV2A,
      sessionOrder: 1,
    );
    SessionRevisionUsageTestFixtures.seedSlot(
      programmeTables,
      day: dayV2,
      protocolId: protocolA,
      id: slotV2B,
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
      id: slotV3,
    );

    exerciseTables.exercises.addAll([
      const Exercise(exerciseId: 'SQ-001', name: 'Back Squat', published: true),
      const Exercise(exerciseId: 'SQ-002', name: 'Back Squat', published: true),
    ]);

    performanceRecords = [];

    impactStore = InMemoryProgrammeVersionImpactStore(
      programmeTables: programmeTables,
      lineageStore: lineageStore,
      exerciseTables: exerciseTables,
      protocolNames: {
        protocolA: 'Strength Foundation',
        protocolB: 'Engine Builder',
        protocolC: 'Strength Foundation',
      },
      performanceRecords: performanceRecords,
    );
    service = buildService();
  });

  group('identity and slots', () {
    test('exact Programme Version loads', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.programmeVersionId, versionV2Id);
      expect(summary.versionNumber, 2);
    });

    test('missing Programme Version distinguished', () async {
      final lookup = await service.tryGetImpactForVersion('missing-version');
      expect(lookup.status, ProgrammeVersionImpactLookupStatus.versionNotFound);
    });

    test('one session slot returned', () async {
      final references = await service.getSessionReferences(versionV3Id);
      expect(references, hasLength(1));
    });

    test('multiple slots preserve order', () async {
      final references = await service.getSessionReferences(versionV2Id);
      expect(references, hasLength(3));
      expect(references[0].slotOrder, lessThan(references[1].slotOrder));
      expect(references[1].slotOrder, lessThan(references[2].slotOrder));
    });

    test('same Session Revision in multiple slots preserves slots but deduplicates revision count',
        () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.totalSessionSlotCount, 3);
      expect(summary.distinctSessionRevisionCount, 2);
    });

    test('different Programme Version excluded', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(
        summary.sessionReferences.any((ref) => ref.protocolId == protocolC),
        isFalse,
      );
    });

    test('archived Programme Version remains queryable', () async {
      final summary = await service.getImpactForVersion(versionV1Id);
      expect(summary.lifecycleStatus, ProgrammeLifecycleStatus.archived);
    });

    test('draft Programme Version remains queryable', () async {
      final summary = await service.getImpactForVersion(versionV3Id);
      expect(summary.lifecycleStatus, ProgrammeLifecycleStatus.draft);
    });

    test('raw identifiers not included in derived user-facing copy', () async {
      _seedActiveAssignment(versionId: versionV2Id, assignmentId: 'assignment-1');
      final summary = await service.getImpactForVersion(versionV2Id);
      final combined = summary.summaryMessages.join(' ');
      expect(combined.contains(versionV2Id), isFalse);
      expect(combined.contains('assignment-1'), isFalse);
    });
  });

  group('session references', () {
    test('exact revision numbers preserved', () async {
      final summary = await service.getImpactForVersion(versionV3Id);
      expect(summary.sessionReferences.single.sessionRevisionNumber, 2);
    });

    test('session lifecycle preserved', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(
        summary.sessionReferences.every(
          (ref) => ref.sessionLifecycleStatus ==
              SessionRevisionLifecycleStatus.published,
        ),
        isTrue,
      );
    });

    test('distinct Session Lineage count correct', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.distinctSessionLineageCount, 2);
    });

    test('shared lineage revisions remain distinct', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      final protocolIds =
          summary.sessionReferences.map((ref) => ref.protocolId).toSet();
      expect(protocolIds, containsAll([protocolA, protocolB]));
    });

    test('empty Programme Version handled', () async {
      final emptyVersion = _version(
        id: 'empty-version',
        lineageId: lineageId,
        versionNumber: 99,
        name: 'Empty',
      );
      programmeTables.versions.add(emptyVersion);

      final summary = await service.getImpactForVersion(emptyVersion.id);
      expect(summary.sessionReferences, isEmpty);
      expect(summary.totalSessionSlotCount, 0);
    });
  });

  group('exercises', () {
    setUp(() {
      _seedBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: protocolA,
      );
      _seedBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-001',
        protocolId: protocolB,
        blockId: 'block-b',
      );
    });

    test('exercises aggregated from exact Session Revisions', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.exerciseReferences, isNotEmpty);
      expect(summary.exerciseReferences.first.exerciseId, 'SQ-001');
    });

    test('same Exercise across multiple sessions deduplicated', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.distinctExerciseCount, 1);
      expect(summary.exerciseReferences.single.sessionCount, 2);
    });

    test('block-link count remains accurate', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.exerciseReferences.single.blockLinkCount, 2);
    });

    test('exercise removed from newer Session Revision excluded', () async {
      final summary = await service.getImpactForVersion(versionV3Id);
      expect(summary.distinctExerciseCount, 0);
    });

    test('same-name different-ID Exercise excluded', () async {
      _seedBlockLink(
        exerciseTables: exerciseTables,
        exerciseId: 'SQ-002',
        protocolId: protocolB,
        blockId: 'block-b-2',
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.distinctExerciseCount, 2);
    });

    test('legacy structured reference follows M9.4 rules', () async {
      exerciseTables.legacySteps.add(
        InMemoryExerciseLegacyStepFixture(
          stepId: 'legacy-step-1',
          exerciseId: 'SQ-001',
          protocolId: protocolB,
          title: 'Legacy Squat',
          stepOrder: 1,
          sessionLineageId: 'session-lineage-b',
          sessionRevisionNumber: 1,
          sessionName: 'Engine Builder',
          sessionLifecycleStatus: SessionRevisionLifecycleStatus.published,
        ),
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      final squat = summary.exerciseReferences
          .where((ref) => ref.exerciseId == 'SQ-001')
          .single;
      expect(squat.isLegacyReference, isFalse);
    });

    test('free-text-only movement not inferred', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(
        summary.exerciseReferences.any((ref) => ref.exerciseName.contains('text')),
        isFalse,
      );
    });
  });

  group('assignments', () {
    test('active assignment to exact version counted', () async {
      _seedActiveAssignment(versionId: versionV2Id, assignmentId: 'assignment-a');
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.activeAssignmentCount, 1);
    });

    test('assignment to newer version excluded', () async {
      _seedActiveAssignment(versionId: versionV3Id, assignmentId: 'assignment-new');
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.activeAssignmentCount, 0);
    });

    test('assignment to older version excluded', () async {
      _seedActiveAssignment(versionId: versionV1Id, assignmentId: 'assignment-old');
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.activeAssignmentCount, 0);
    });

    test('inactive status excluded from operational count', () async {
      _seedAssignment(
        versionId: versionV2Id,
        assignmentId: 'assignment-completed',
        status: ProgrammeAssignmentStatus.completed,
      );
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.activeAssignmentCount, 0);
    });

    test('multiple assignments deduplicated', () async {
      _seedActiveAssignment(versionId: versionV2Id, assignmentId: 'assignment-a');
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.activeAssignments.map((a) => a.assignmentId).toSet(),
          hasLength(summary.activeAssignmentCount));
    });

    test('shared Session content does not merge assignments across versions',
        () async {
      _seedActiveAssignment(versionId: versionV2Id, assignmentId: 'assignment-v2');
      _seedActiveAssignment(versionId: versionV3Id, assignmentId: 'assignment-v3');

      final v2 = await service.getImpactForVersion(versionV2Id);
      final v3 = await service.getImpactForVersion(versionV3Id);

      expect(v2.activeAssignmentCount, 1);
      expect(v3.activeAssignmentCount, 1);
    });
  });

  group('history', () {
    test('terminal record directly linked to exact version counted', () async {
      final assignment = _seedActiveAssignment(
        versionId: versionV2Id,
        assignmentId: 'assignment-history',
      );
      impactStore.performanceRecords.add(
        _terminalRecord(
          recordId: 'record-1',
          assignmentId: assignment.id,
          sourceProtocolId: protocolA,
        ),
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.historicalImpact.terminalRecordCount, 1);
    });

    test('in-progress record excluded', () async {
      final assignment = _seedActiveAssignment(
        versionId: versionV2Id,
        assignmentId: 'assignment-progress',
      );
      impactStore.performanceRecords.add(
        _terminalRecord(
          recordId: 'record-progress',
          assignmentId: assignment.id,
          status: TrainingSessionRecordStatus.inProgress,
        ),
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.historicalImpact.terminalRecordCount, 0);
    });

    test('record for different Programme Version excluded', () async {
      final assignment = _seedActiveAssignment(
        versionId: versionV3Id,
        assignmentId: 'assignment-v3',
      );
      impactStore.performanceRecords.add(
        _terminalRecord(
          recordId: 'record-v3',
          assignmentId: assignment.id,
          sourceProtocolId: protocolC,
        ),
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.historicalImpact.terminalRecordCount, 0);
    });

    test('shared Session Revision does not cause false historical attribution',
        () async {
      final assignmentV3 = _seedActiveAssignment(
        versionId: versionV3Id,
        assignmentId: 'assignment-shared',
      );
      impactStore.performanceRecords.add(
        _terminalRecord(
          recordId: 'record-shared',
          assignmentId: assignmentV3.id,
          sourceProtocolId: protocolA,
          programmeSessionId: slotV2A,
        ),
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.historicalImpact.terminalRecordCount, 0);
    });

    test('earliest/latest timestamps correct', () async {
      final assignment = _seedActiveAssignment(
        versionId: versionV2Id,
        assignmentId: 'assignment-range',
      );
      impactStore.performanceRecords.addAll([
        _terminalRecord(
          recordId: 'record-early',
          assignmentId: assignment.id,
          performedAt: DateTime.utc(2026, 1, 1),
        ),
        _terminalRecord(
          recordId: 'record-late',
          assignmentId: assignment.id,
          performedAt: DateTime.utc(2026, 2, 1),
        ),
      ]);

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.historicalImpact.earliestPerformedAt,
          DateTime.utc(2026, 1, 1));
      expect(summary.historicalImpact.latestPerformedAt, DateTime.utc(2026, 2, 1));
    });

    test('historical-only Programme Version represented', () async {
      final assignment = _seedAssignment(
        versionId: versionV2Id,
        assignmentId: 'assignment-done',
        status: ProgrammeAssignmentStatus.completed,
      );
      impactStore.performanceRecords.add(
        _terminalRecord(
          recordId: 'record-historical-only',
          assignmentId: assignment.id,
        ),
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.hasHistoricalImpact, isTrue);
      expect(summary.hasActiveOperationalImpact, isFalse);
    });

    test('multiple records deduplicated', () async {
      final assignment = _seedActiveAssignment(
        versionId: versionV2Id,
        assignmentId: 'assignment-dedupe',
      );
      final record = _terminalRecord(
        recordId: 'record-dedupe',
        assignmentId: assignment.id,
      );
      impactStore.performanceRecords.addAll([record, record]);

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.historicalImpact.terminalRecordCount, 1);
    });

    test('partial historical attribution reported honestly', () async {
      final failingStore = InMemoryProgrammeVersionImpactStore(
        programmeTables: programmeTables,
        lineageStore: lineageStore,
        exerciseTables: exerciseTables,
        historicalLookupFails: true,
      );
      final partialService = buildService(store: failingStore);

      final lookup = await partialService.tryGetImpactForVersion(versionV2Id);
      expect(lookup.isSuccess, isTrue);
      expect(lookup.summary!.historicalImpact.isAuthoritative, isFalse);
      expect(lookup.summary!.warnings, isNotEmpty);
    });

    test('zero history returned only when authoritative', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.historicalImpact.terminalRecordCount, 0);
      expect(summary.historicalImpact.isAuthoritative, isTrue);
    });
  });

  group('lineage context', () {
    test('no newer version', () async {
      final context = await service.getLineageContext(versionV3Id);
      expect(context.hasNewerVersion, isFalse);
    });

    test('newer draft version exists', () async {
      final context = await service.getLineageContext(versionV2Id);
      expect(context.hasNewerVersion, isTrue);
      expect(context.newerVersionIds, contains(versionV3Id));
    });

    test('newer published version exists', () async {
      programmeTables.versions.add(
        _version(
          id: 'version-4',
          lineageId: lineageId,
          versionNumber: 4,
          lifecycleStatus: ProgrammeLifecycleStatus.published,
        ),
      );
      final context = await service.getLineageContext(versionV2Id);
      expect(context.hasNewerVersion, isTrue);
    });

    test('latest published version identified', () async {
      final context = await service.getLineageContext(versionV1Id);
      expect(context.latestPublishedVersionId, versionV2Id);
      expect(context.latestPublishedVersionNumber, 2);
    });

    test('archived newer version handled correctly', () async {
      programmeTables.versions.add(
        _version(
          id: 'version-4',
          lineageId: lineageId,
          versionNumber: 4,
          lifecycleStatus: ProgrammeLifecycleStatus.archived,
        ),
      );
      final context = await service.getLineageContext(versionV2Id);
      expect(context.latestPublishedVersionId, versionV2Id);
    });

    test('exact queried version remains primary', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.versionNumber, 2);
      expect(summary.programmeVersionId, versionV2Id);
    });
  });

  group('combined summary', () {
    test('authored-only classification', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.classifications,
          contains(ContentUsageClassification.directAuthored));
      expect(summary.hasAuthoredContent, isTrue);
    });

    test('active operational classification', () async {
      _seedActiveAssignment(versionId: versionV2Id, assignmentId: 'assignment-op');
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.classifications,
          contains(ContentUsageClassification.activeOperational));
    });

    test('historical classification', () async {
      final assignment = _seedAssignment(
        versionId: versionV2Id,
        assignmentId: 'assignment-hist',
        status: ProgrammeAssignmentStatus.completed,
      );
      impactStore.performanceRecords.add(
        _terminalRecord(recordId: 'record-hist', assignmentId: assignment.id),
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.classifications,
          contains(ContentUsageClassification.historicalPerformance));
    });

    test('mixed impact classification', () async {
      final assignment = _seedActiveAssignment(
        versionId: versionV2Id,
        assignmentId: 'assignment-mixed',
      );
      impactStore.performanceRecords.add(
        _terminalRecord(recordId: 'record-mixed', assignmentId: assignment.id),
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.classifications, hasLength(3));
    });

    test('unused empty version', () async {
      final emptyVersion = _version(
        id: 'unused-version',
        lineageId: lineageId,
        versionNumber: 50,
      );
      programmeTables.versions.add(emptyVersion);

      final summary = await service.getImpactForVersion(emptyVersion.id);
      expect(summary.isUnused, isTrue);
    });

    test('stable ordering', () async {
      final first = await service.getImpactForVersion(versionV2Id);
      final second = await service.getImpactForVersion(versionV2Id);
      expect(
        first.sessionReferences.map((ref) => ref.slotId).toList(),
        second.sessionReferences.map((ref) => ref.slotId).toList(),
      );
    });

    test('aggregate counts correct', () async {
      _seedActiveAssignment(versionId: versionV2Id, assignmentId: 'assignment-count');
      final assignment = programmeTables.assignments.last;
      impactStore.performanceRecords.add(
        _terminalRecord(recordId: 'record-count', assignmentId: assignment.id),
      );

      final summary = await service.getImpactForVersion(versionV2Id);
      expect(summary.totalSessionSlotCount, 3);
      expect(summary.activeAssignmentCount, 1);
      expect(summary.historicalImpact.terminalRecordCount, 1);
    });

    test('lookup failure differs from zero impact', () async {
      final lookup = await service.tryGetImpactForVersion('missing-version');
      expect(lookup.status, ProgrammeVersionImpactLookupStatus.versionNotFound);

      final zeroImpact = await service.tryGetImpactForVersion(versionV2Id);
      expect(zeroImpact.status, ProgrammeVersionImpactLookupStatus.success);
      expect(zeroImpact.summary!.isUnused, isTrue);
    });

    test('user-facing summary contains no athlete IDs', () async {
      _seedActiveAssignment(
        versionId: versionV2Id,
        assignmentId: 'assignment-copy',
        athleteId: 'athlete-secret-88',
      );
      final summary = await service.getImpactForVersion(versionV2Id);
      expect(
        ProgrammeVersionImpactMessageBuilder.summaryContainsAthleteIdentifiers(
          summary.summaryMessages,
        ),
        isFalse,
      );
    });

    test('no duplicate entities', () async {
      final summary = await service.getImpactForVersion(versionV2Id);
      final slotIds =
          summary.sessionReferences.map((ref) => ref.slotId).toList();
      expect(slotIds.toSet().length, slotIds.length);
    });
  });
}

ProgrammeVersion _version({
  required String id,
  required String lineageId,
  required int versionNumber,
  ProgrammeLifecycleStatus lifecycleStatus = ProgrammeLifecycleStatus.published,
  String name = 'Test Programme',
}) {
  return ProgrammeVersion(
    id: id,
    lineageId: lineageId,
    versionNumber: versionNumber,
    lifecycleStatus: lifecycleStatus,
    libraryScope: ProgrammeLibraryScope.cohortGlobal,
    ownerType: ProgrammeOwnerType.global,
    name: name,
  );
}

void _seedSessionMetadata({
  required InMemorySessionLineageStore lineageStore,
  required String protocolId,
  required int revisionNumber,
  required SessionRevisionLifecycleStatus lifecycle,
  required String sessionLineageId,
  required String name,
}) {
  SessionRevisionUsageTestFixtures.seedRevisionMetadata(
    lineageStore,
    protocolId: protocolId,
    sessionLineageId: sessionLineageId,
    revisionNumber: revisionNumber,
    lifecycleStatus: lifecycle,
  );
}

ProgrammeAssignment _seedActiveAssignment({
  required String versionId,
  required String assignmentId,
  String athleteId = 'athlete-1',
}) {
  return _seedAssignment(
    versionId: versionId,
    assignmentId: assignmentId,
    athleteId: athleteId,
    status: ProgrammeAssignmentStatus.active,
  );
}

ProgrammeAssignment _seedAssignment({
  required String versionId,
  required String assignmentId,
  ProgrammeAssignmentStatus status = ProgrammeAssignmentStatus.active,
  String athleteId = 'athlete-1',
}) {
  final assignment = ProgrammeAssignment(
    id: assignmentId,
    athleteId: athleteId,
    programmeVersionId: versionId,
    lineageCode: 'PROG-IMPACT',
    status: status,
    startedAt: DateTime.utc(2026, 1, 1),
  );
  _currentProgrammeTables.assignments.add(assignment);
  return assignment;
}

TrainingSessionRecord _terminalRecord({
  required String recordId,
  String? assignmentId,
  String? programmeSessionId,
  String? sourceProtocolId,
  TrainingSessionRecordStatus status = TrainingSessionRecordStatus.completed,
  DateTime? performedAt,
}) {
  final timestamp = performedAt ?? DateTime.utc(2026, 1, 15);
  return TrainingSessionRecord(
    recordId: recordId,
    athleteId: 'athlete-1',
    assignmentId: assignmentId,
    programmeSessionId: programmeSessionId,
    sourceProtocolId: sourceProtocolId,
    status: status,
    sessionSnapshot: SessionPerformanceSnapshot(
      sourceProtocolId: sourceProtocolId ?? '',
      sessionTitle: 'Snapshot',
    ),
    startedAt: timestamp,
    completedAt: timestamp,
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
