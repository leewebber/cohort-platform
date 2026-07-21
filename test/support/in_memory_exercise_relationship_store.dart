import 'package:cohort_platform/data/repositories/exercise_relationship_store.dart';
import 'package:cohort_platform/features/exercise_relationship/models/exercise_usage_models.dart';
import 'package:cohort_platform/features/performance/models/training_session_record_status.dart';
import 'package:cohort_platform/features/performance/repositories/performance_record_store.dart';
import 'package:cohort_platform/models/exercise.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';
import 'in_memory_programme_stores.dart';

class InMemoryExerciseBlockLinkFixture {
  const InMemoryExerciseBlockLinkFixture({
    required this.exerciseLinkId,
    required this.exerciseId,
    required this.blockId,
    required this.blockTitle,
    required this.blockOrder,
    required this.protocolId,
    required this.sessionLineageId,
    required this.sessionRevisionNumber,
    required this.sessionName,
    required this.sessionLifecycleStatus,
    this.displayLabelOverride,
  });

  final String exerciseLinkId;
  final String exerciseId;
  final String blockId;
  final String blockTitle;
  final int blockOrder;
  final String protocolId;
  final String sessionLineageId;
  final int sessionRevisionNumber;
  final String sessionName;
  final SessionRevisionLifecycleStatus sessionLifecycleStatus;
  final String? displayLabelOverride;
}

class InMemoryExerciseLegacyStepFixture {
  const InMemoryExerciseLegacyStepFixture({
    required this.stepId,
    required this.exerciseId,
    required this.protocolId,
    required this.title,
    required this.stepOrder,
    required this.sessionLineageId,
    required this.sessionRevisionNumber,
    required this.sessionName,
    required this.sessionLifecycleStatus,
  });

  final String stepId;
  final String exerciseId;
  final String protocolId;
  final String title;
  final int stepOrder;
  final String sessionLineageId;
  final int sessionRevisionNumber;
  final String sessionName;
  final SessionRevisionLifecycleStatus sessionLifecycleStatus;
}

class InMemoryExerciseHistoricalResultFixture {
  const InMemoryExerciseHistoricalResultFixture({
    required this.exerciseResultId,
    required this.exerciseId,
    required this.recordId,
    required this.sourceProtocolId,
    required this.performedAt,
    required this.status,
  });

  final String exerciseResultId;
  final String exerciseId;
  final String recordId;
  final String sourceProtocolId;
  final DateTime performedAt;
  final TrainingSessionRecordStatus status;
}

class InMemoryExerciseRelationshipTables {
  final exercises = <Exercise>[];
  final blockLinks = <InMemoryExerciseBlockLinkFixture>[];
  final legacySteps = <InMemoryExerciseLegacyStepFixture>[];
  final historicalResults = <InMemoryExerciseHistoricalResultFixture>[];
  final programmeTables = InMemoryProgrammeTables();
}

class InMemoryExerciseRelationshipStore extends ExerciseRelationshipStore {
  InMemoryExerciseRelationshipStore(this.tables);

  final InMemoryExerciseRelationshipTables tables;

  @override
  Future<Exercise?> getExerciseById(String exerciseId) async {
    for (final exercise in tables.exercises) {
      if (exercise.exerciseId == exerciseId) return exercise;
    }
    return null;
  }

  @override
  Future<List<ExerciseRevisionReference>> listSessionRevisionReferences(
    String exerciseId,
  ) async {
    final normalizedExerciseId = exerciseId.trim();
    if (normalizedExerciseId.isEmpty) return const [];

    final blockReferences = tables.blockLinks
        .where((link) => link.exerciseId == normalizedExerciseId)
        .map(
          (link) => ExerciseRevisionReference(
            protocolId: link.protocolId,
            sessionLineageId: link.sessionLineageId,
            sessionRevisionNumber: link.sessionRevisionNumber,
            sessionName: link.sessionName,
            sessionLifecycleStatus: link.sessionLifecycleStatus,
            blockId: link.blockId,
            blockTitle: link.blockTitle,
            blockOrder: link.blockOrder,
            relationshipSource: ExerciseRelationshipSource.sessionBlockLink,
            exerciseLinkId: link.exerciseLinkId,
            displayLabelOverride: link.displayLabelOverride,
          ),
        )
        .toList();

    final protocolsWithBlockLinks =
        blockReferences.map((reference) => reference.protocolId).toSet();

    final legacyReferences = tables.legacySteps
        .where(
          (step) =>
              step.exerciseId == normalizedExerciseId &&
              !protocolsWithBlockLinks.contains(step.protocolId),
        )
        .map(
          (step) => ExerciseRevisionReference(
            protocolId: step.protocolId,
            sessionLineageId: step.sessionLineageId,
            sessionRevisionNumber: step.sessionRevisionNumber,
            sessionName: step.sessionName,
            sessionLifecycleStatus: step.sessionLifecycleStatus,
            blockId: 'legacy-step-${step.stepId}',
            blockTitle: step.title,
            blockOrder: step.stepOrder,
            relationshipSource: ExerciseRelationshipSource.legacyProtocolStep,
            exerciseLinkId: step.stepId,
          ),
        )
        .toList();

    final references = [...blockReferences, ...legacyReferences]
      ..sort(compareExerciseRevisionReferences);
    return references;
  }

  @override
  Future<List<ExerciseProgrammeReference>> listProgrammeReferences(
    String exerciseId,
    Set<String> protocolIds,
  ) async {
    if (protocolIds.isEmpty) return const [];

    final sessionReferences = await listSessionRevisionReferences(exerciseId);
    final revisionByProtocol = {
      for (final reference in sessionReferences)
        reference.protocolId: reference,
    };

    final references = <ExerciseProgrammeReference>[];

    for (final slot in tables.programmeTables.slots) {
      if (!protocolIds.contains(slot.protocolId)) continue;

      final sessionReference = revisionByProtocol[slot.protocolId];
      if (sessionReference == null) continue;

      ProgrammeVersionDay? day;
      for (final candidate in tables.programmeTables.days) {
        if (candidate.id == slot.dayId) {
          day = candidate;
          break;
        }
      }
      if (day == null) continue;

      ProgrammeVersionWeek? week;
      for (final candidate in tables.programmeTables.weeks) {
        if (candidate.id == day.weekId) {
          week = candidate;
          break;
        }
      }
      if (week == null) continue;

      ProgrammeVersion? version;
      for (final candidate in tables.programmeTables.versions) {
        if (candidate.id == week.versionId) {
          version = candidate;
          break;
        }
      }
      if (version == null) continue;

      ProgrammeLineage? lineage;
      for (final candidate in tables.programmeTables.lineages) {
        if (candidate.id == version.lineageId) {
          lineage = candidate;
          break;
        }
      }
      if (lineage == null) continue;

      references.add(
        ExerciseProgrammeReference(
          programmeLineageId: lineage.id,
          programmeLineageCode: lineage.code,
          programmeVersionId: version.id,
          programmeVersionNumber: version.versionNumber,
          programmeName: version.name,
          programmeLifecycleStatus: version.lifecycleStatus,
          protocolId: slot.protocolId,
          sessionRevisionNumber: sessionReference.sessionRevisionNumber,
          slotId: slot.id,
          weekNumber: week.weekNumber,
          dayKey: day.dayKey,
          dayOrder: day.dayOrder,
          slotOrder: slot.sessionOrder,
          slotLabel: slot.displayTitle,
        ),
      );
    }

    references.sort(compareExerciseProgrammeReferences);
    return references;
  }

  @override
  Future<List<ExerciseAssignmentReference>> listActiveAssignmentReferences(
    String exerciseId,
    Set<String> programmeVersionIds,
  ) async {
    return buildExerciseActiveAssignmentReferences(
      assignments: tables.programmeTables.assignments,
      referencingVersionIds: programmeVersionIds,
    );
  }

  @override
  Future<ExerciseHistoricalUsage> getHistoricalUsage(String exerciseId) async {
    final normalizedExerciseId = exerciseId.trim();
    if (normalizedExerciseId.isEmpty) {
      return const ExerciseHistoricalUsage(
        recordCount: 0,
        performanceOccurrenceCount: 0,
        isAuthoritative: true,
      );
    }

    DateTime? earliest;
    DateTime? latest;
    final matchedRecordIds = <String>{};
    final matchedProtocolIds = <String>{};
    var occurrenceCount = 0;

    for (final result in tables.historicalResults) {
      if (result.exerciseId != normalizedExerciseId) continue;
      if (!isTerminalRecordStatus(result.status)) continue;

      occurrenceCount++;
      matchedRecordIds.add(result.recordId);
      matchedProtocolIds.add(result.sourceProtocolId);

      if (earliest == null || result.performedAt.isBefore(earliest)) {
        earliest = result.performedAt;
      }
      if (latest == null || result.performedAt.isAfter(latest)) {
        latest = result.performedAt;
      }
    }

    return ExerciseHistoricalUsage(
      recordCount: matchedRecordIds.length,
      performanceOccurrenceCount: occurrenceCount,
      earliestPerformedAt: earliest,
      latestPerformedAt: latest,
      sessionRevisionCount: matchedProtocolIds.length,
      isAuthoritative: true,
      limitationNote:
          'Counts terminal records with structured source_exercise_id only.',
    );
  }
}
