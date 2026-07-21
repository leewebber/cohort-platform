import 'package:cohort_platform/features/exercise_relationship/models/exercise_usage_models.dart';
import 'package:cohort_platform/features/exercise_relationship/services/exercise_relationship_service.dart';
import 'package:cohort_platform/features/session_revision/models/content_usage_vocabulary.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_exercise_relationship_store.dart';
import '../support/session_revision_usage_test_fixtures.dart';

void main() {
  late InMemoryExerciseRelationshipTables tables;
  late InMemoryExerciseRelationshipStore store;
  late ExerciseRelationshipService service;

  const exerciseA = 'SQ-001';
  const exerciseB = 'BP-001';
  const sessionLineageId = 'session-lineage-1';

  setUp(() {
    tables = InMemoryExerciseRelationshipTables();
    store = InMemoryExerciseRelationshipStore(tables);
    service = ExerciseRelationshipService(relationshipStore: store);

    tables.exercises.addAll([
      const Exercise(exerciseId: exerciseA, name: 'Back Squat', published: true),
      const Exercise(exerciseId: exerciseB, name: 'Back Squat Clone', published: true),
    ]);
  });

  group('direct session usage', () {
    test('exercise used by one block in one session revision', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        blockId: 'block-1',
        blockOrder: 1,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directBlockReferenceCount, 1);
      expect(summary.directSessionRevisionCount, 1);
      expect(summary.hasDirectAuthoredUsage, isTrue);
    });

    test('exercise used in multiple blocks in one revision', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        blockId: 'block-1',
        blockOrder: 1,
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        blockId: 'block-2',
        blockOrder: 2,
        blockTitle: 'Accessory',
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directSessionRevisionCount, 1);
      expect(summary.directBlockReferenceCount, 2);
    });

    test('exercise used across multiple revisions', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        revisionNumber: 1,
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1-rev-2',
        revisionNumber: 2,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directSessionRevisionCount, 2);
      expect(summary.directBlockReferenceCount, 2);
    });

    test('exercise removed from newer revision remains linked only to older revision',
        () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        revisionNumber: 1,
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1-rev-2',
        revisionNumber: 2,
        includeExercise: false,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directSessionReferences, hasLength(1));
      expect(summary.directSessionReferences.first.protocolId, 'session-v1');
    });

    test('different exercise with same display name is excluded', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        displayLabelOverride: 'Back Squat',
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseB,
        protocolId: 'session-v2',
        displayLabelOverride: 'Back Squat',
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directSessionReferences, hasLength(1));
      expect(summary.directSessionReferences.first.protocolId, 'session-v1');
    });

    test('unused exercise returns no direct references', () async {
      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directSessionReferences, isEmpty);
      expect(summary.isUnused, isTrue);
    });

    test('archived session revision remains visible', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        lifecycle: SessionRevisionLifecycleStatus.archived,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directSessionReferences.first.sessionLifecycleStatus,
          SessionRevisionLifecycleStatus.archived);
    });

    test('block ordering and label overrides preserved', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        blockId: 'block-2',
        blockOrder: 2,
        displayLabelOverride: 'Tempo Squat',
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        blockId: 'block-1',
        blockOrder: 1,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directSessionReferences.first.blockOrder, 1);
      expect(summary.directSessionReferences.last.displayLabelOverride,
          'Tempo Squat');
    });

    test('session revision count differs from block link count', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        blockId: 'block-1',
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        blockId: 'block-2',
        blockOrder: 2,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directSessionRevisionCount, 1);
      expect(summary.directBlockReferenceCount, 2);
    });
  });

  group('session lineage roll-up', () {
    test('multiple revisions in same lineage deduplicate lineage count', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        revisionNumber: 1,
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1-rev-2',
        revisionNumber: 2,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.sessionLineageCount, 1);
      expect(summary.sessionLineageReferences.first.revisionCount, 2);
    });

    test('multiple different lineages reported separately', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-a',
        sessionLineageId: 'lineage-a',
        sessionName: 'Alpha Session',
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-b',
        sessionLineageId: 'lineage-b',
        sessionName: 'Beta Session',
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.sessionLineageCount, 2);
    });
  });

  group('programme usage', () {
    test('referencing programme version reported through exact session revision',
        () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
      );
      _attachProtocolToProgramme(
        tables: tables,
        protocolId: 'session-v1',
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.programmeVersionCount, 1);
      expect(summary.programmeReferences.first.protocolId, 'session-v1');
    });

    test('non-referencing programme version excluded', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
      );
      _attachProtocolToProgramme(
        tables: tables,
        protocolId: 'other-session',
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.programmeReferences, isEmpty);
    });

    test('multiple sessions in one programme version deduplicate programme count',
        () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-a',
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-b',
      );
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(
        tables.programmeTables,
      );
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        tables.programmeTables,
        lineage: lineage,
      );
      for (final protocolId in ['session-a', 'session-b']) {
        final week = SessionRevisionUsageTestFixtures.seedWeek(
          tables.programmeTables,
          version: version,
          id: 'week-$protocolId',
        );
        final day = SessionRevisionUsageTestFixtures.seedDay(
          tables.programmeTables,
          week: week,
          id: 'day-$protocolId',
        );
        SessionRevisionUsageTestFixtures.seedSlot(
          tables.programmeTables,
          day: day,
          protocolId: protocolId,
          id: 'slot-$protocolId',
        );
      }

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.programmeVersionCount, 1);
      expect(summary.programmeReferences, hasLength(2));
    });

    test('archived programme version remains visible', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
      );
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(
        tables.programmeTables,
      );
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        tables.programmeTables,
        lineage: lineage,
        lifecycleStatus: ProgrammeLifecycleStatus.archived,
      );
      _attachProtocolToProgramme(
        tables: tables,
        protocolId: 'session-v1',
        version: version,
        lineage: lineage,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.programmeReferences.first.programmeLifecycleStatus,
          ProgrammeLifecycleStatus.archived);
    });

    test('newer programme version using revision without exercise is excluded',
        () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
        revisionNumber: 1,
      );
      _attachProtocolToProgramme(
        tables: tables,
        protocolId: 'session-v1',
        versionNumber: 1,
      );
      _attachProtocolToProgramme(
        tables: tables,
        protocolId: 'session-v1-rev-2',
        versionNumber: 2,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.programmeVersionCount, 1);
      expect(summary.programmeReferences.first.programmeVersionNumber, 1);
    });
  });

  group('active assignments', () {
    test('active assignment to dependent programme version reported', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
      );
      final version = _attachProtocolToProgramme(
        tables: tables,
        protocolId: 'session-v1',
      );
      SessionRevisionUsageTestFixtures.seedAssignment(
        tables.programmeTables,
        athleteId: 'athlete-1',
        version: version,
        lineage: tables.programmeTables.lineages.first,
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.activeAssignmentCount, 1);
      expect(summary.hasActiveOperationalUsage, isTrue);
    });

    test('completed reassigned and paused assignments excluded', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
      );
      final version = _attachProtocolToProgramme(
        tables: tables,
        protocolId: 'session-v1',
      );
      final lineage = tables.programmeTables.lineages.first;
      for (final entry in [
        (status: ProgrammeAssignmentStatus.completed, id: 'assignment-completed'),
        (status: ProgrammeAssignmentStatus.reassigned, id: 'assignment-reassigned'),
        (status: ProgrammeAssignmentStatus.paused, id: 'assignment-paused'),
      ]) {
        SessionRevisionUsageTestFixtures.seedAssignment(
          tables.programmeTables,
          athleteId: entry.id,
          version: version,
          lineage: lineage,
          id: entry.id,
          status: entry.status,
        );
      }

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.activeAssignmentReferences, isEmpty);
    });

    test('assignment deduplicated across multiple paths', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-a',
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-b',
      );
      final lineage = SessionRevisionUsageTestFixtures.seedLineage(
        tables.programmeTables,
      );
      final version = SessionRevisionUsageTestFixtures.seedVersion(
        tables.programmeTables,
        lineage: lineage,
      );
      final week = SessionRevisionUsageTestFixtures.seedWeek(
        tables.programmeTables,
        version: version,
      );
      for (final entry in [
        (protocolId: 'session-a', slotId: 'slot-a'),
        (protocolId: 'session-b', slotId: 'slot-b'),
      ]) {
        final day = SessionRevisionUsageTestFixtures.seedDay(
          tables.programmeTables,
          week: week,
          id: 'day-${entry.slotId}',
        );
        SessionRevisionUsageTestFixtures.seedSlot(
          tables.programmeTables,
          day: day,
          protocolId: entry.protocolId,
          id: entry.slotId,
        );
      }
      SessionRevisionUsageTestFixtures.seedAssignment(
        tables.programmeTables,
        athleteId: 'athlete-1',
        version: version,
        lineage: lineage,
        id: 'assignment-1',
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.activeAssignmentCount, 1);
    });
  });

  group('historical usage', () {
    test('matching terminal historical record counted', () async {
      tables.historicalResults.add(
        InMemoryExerciseHistoricalResultFixture(
          exerciseResultId: 'result-1',
          exerciseId: exerciseA,
          recordId: 'record-1',
          sourceProtocolId: 'session-v1',
          performedAt: DateTime.utc(2026, 2, 1),
          status: TrainingSessionRecordStatus.completed,
        ),
      );

      final usage = await service.getHistoricalUsage(exerciseA);

      expect(usage.recordCount, 1);
      expect(usage.hasUsage, isTrue);
      expect(usage.isAuthoritative, isTrue);
    });

    test('different exercise id excluded', () async {
      tables.historicalResults.add(
        InMemoryExerciseHistoricalResultFixture(
          exerciseResultId: 'result-1',
          exerciseId: exerciseB,
          recordId: 'record-1',
          sourceProtocolId: 'session-v1',
          performedAt: DateTime.utc(2026, 2, 1),
          status: TrainingSessionRecordStatus.completed,
        ),
      );

      final usage = await service.getHistoricalUsage(exerciseA);

      expect(usage.recordCount, 0);
    });

    test('in_progress record excluded', () async {
      tables.historicalResults.add(
        InMemoryExerciseHistoricalResultFixture(
          exerciseResultId: 'result-1',
          exerciseId: exerciseA,
          recordId: 'record-1',
          sourceProtocolId: 'session-v1',
          performedAt: DateTime.utc(2026, 2, 1),
          status: TrainingSessionRecordStatus.inProgress,
        ),
      );

      final usage = await service.getHistoricalUsage(exerciseA);

      expect(usage.recordCount, 0);
    });

    test('multiple occurrences in one record handled correctly', () async {
      tables.historicalResults.addAll([
        InMemoryExerciseHistoricalResultFixture(
          exerciseResultId: 'result-1',
          exerciseId: exerciseA,
          recordId: 'record-1',
          sourceProtocolId: 'session-v1',
          performedAt: DateTime.utc(2026, 2, 1),
          status: TrainingSessionRecordStatus.completed,
        ),
        InMemoryExerciseHistoricalResultFixture(
          exerciseResultId: 'result-2',
          exerciseId: exerciseA,
          recordId: 'record-1',
          sourceProtocolId: 'session-v1',
          performedAt: DateTime.utc(2026, 2, 1),
          status: TrainingSessionRecordStatus.completed,
        ),
      ]);

      final usage = await service.getHistoricalUsage(exerciseA);

      expect(usage.recordCount, 1);
      expect(usage.performanceOccurrenceCount, 2);
    });

    test('no history returns zero when lookup is authoritative', () async {
      final usage = await service.getHistoricalUsage(exerciseA);

      expect(usage.recordCount, 0);
      expect(usage.isAuthoritative, isTrue);
    });
  });

  group('combined summary and lookup', () {
    test('classifications and lookup failure differ from unused', () async {
      final unused = await service.tryGetUsageForExercise(exerciseA);
      expect(unused.isSuccess, isTrue);
      expect(unused.summary!.isUnused, isTrue);

      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-v1',
      );
      final directOnly = await service.getUsageForExercise(exerciseA);
      expect(directOnly.classifications,
          [ContentUsageClassification.directAuthored]);

      final missing = await service.tryGetUsageForExercise('missing-exercise');
      expect(missing.status, ExerciseUsageLookupStatus.exerciseNotFound);

      final failingService = ExerciseRelationshipService(
        relationshipStore: _ThrowingExerciseRelationshipStore(tables),
      );
      final failed = await failingService.tryGetUsageForExercise(exerciseA);
      expect(failed.status, ExerciseUsageLookupStatus.lookupFailed);
    });

    test('stable ordering and no duplicate entities', () async {
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-b',
        sessionName: 'Beta Session',
      );
      _seedBlockLink(
        tables: tables,
        exerciseId: exerciseA,
        protocolId: 'session-a',
        sessionName: 'Alpha Session',
      );

      final summary = await service.getUsageForExercise(exerciseA);

      expect(summary.directSessionReferences.first.sessionName, 'Alpha Session');
      expect(
        summary.directSessionReferences.map((row) => row.protocolId).toSet(),
        hasLength(summary.directSessionReferences.length),
      );
    });
  });
}

class _ThrowingExerciseRelationshipStore extends InMemoryExerciseRelationshipStore {
  _ThrowingExerciseRelationshipStore(super.tables);

  @override
  Future<List<ExerciseRevisionReference>> listSessionRevisionReferences(
    String exerciseId,
  ) {
    throw Exception('lookup failed');
  }
}

void _seedBlockLink({
  required InMemoryExerciseRelationshipTables tables,
  required String exerciseId,
  required String protocolId,
  String blockId = 'block-1',
  int blockOrder = 1,
  String blockTitle = 'Strength',
  int revisionNumber = 1,
  String sessionLineageId = 'session-lineage-1',
  String sessionName = 'Strength Session',
  SessionRevisionLifecycleStatus lifecycle =
      SessionRevisionLifecycleStatus.published,
  String? displayLabelOverride,
  bool includeExercise = true,
}) {
  if (!includeExercise) return;

  tables.blockLinks.add(
    InMemoryExerciseBlockLinkFixture(
      exerciseLinkId: 'link-$blockId',
      exerciseId: exerciseId,
      blockId: blockId,
      blockTitle: blockTitle,
      blockOrder: blockOrder,
      protocolId: protocolId,
      sessionLineageId: sessionLineageId,
      sessionRevisionNumber: revisionNumber,
      sessionName: sessionName,
      sessionLifecycleStatus: lifecycle,
      displayLabelOverride: displayLabelOverride,
    ),
  );
}

ProgrammeVersion _attachProtocolToProgramme({
  required InMemoryExerciseRelationshipTables tables,
  required String protocolId,
  int versionNumber = 1,
  ProgrammeVersion? version,
  ProgrammeLineage? lineage,
}) {
  final resolvedLineage = lineage ??
      SessionRevisionUsageTestFixtures.seedLineage(tables.programmeTables);
  final resolvedVersion = version ??
      SessionRevisionUsageTestFixtures.seedVersion(
        tables.programmeTables,
        lineage: resolvedLineage,
        versionNumber: versionNumber,
        id: 'version-$versionNumber',
      );
  final week = SessionRevisionUsageTestFixtures.seedWeek(
    tables.programmeTables,
    version: resolvedVersion,
    id: 'week-$versionNumber',
  );
  final day = SessionRevisionUsageTestFixtures.seedDay(
    tables.programmeTables,
    week: week,
    id: 'day-$versionNumber',
  );
  SessionRevisionUsageTestFixtures.seedSlot(
    tables.programmeTables,
    day: day,
    protocolId: protocolId,
    id: 'slot-$versionNumber',
  );
  return resolvedVersion;
}
