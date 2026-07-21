import 'package:cohort_platform/data/repositories/programme_version_impact_store.dart';
import 'package:cohort_platform/features/exercise_relationship/models/exercise_usage_models.dart';
import 'package:cohort_platform/features/performance/models/training_session_record.dart';
import 'package:cohort_platform/features/programme_impact/models/programme_version_impact_models.dart';
import 'package:cohort_platform/models/programme_assignment.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_version_day.dart';
import 'package:cohort_platform/models/programme_version_session_slot.dart';
import 'package:cohort_platform/models/programme_version_week.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';

import 'in_memory_exercise_relationship_store.dart';
import 'in_memory_programme_stores.dart';
import 'in_memory_session_lineage_store.dart';

/// In-memory Programme Version impact store for unit tests (M10.1).
class InMemoryProgrammeVersionImpactStore extends ProgrammeVersionImpactStore {
  InMemoryProgrammeVersionImpactStore({
    required this.programmeTables,
    required this.lineageStore,
    this.exerciseTables,
    this.performanceRecords = const [],
    this.protocolNames = const {},
    this.protocolPublished = const {},
    this.historicalLookupFails = false,
  });

  final InMemoryProgrammeTables programmeTables;
  final InMemorySessionLineageStore lineageStore;
  final InMemoryExerciseRelationshipTables? exerciseTables;
  final List<TrainingSessionRecord> performanceRecords;
  final Map<String, String> protocolNames;
  final Map<String, bool> protocolPublished;
  final bool historicalLookupFails;

  @override
  Future<ProgrammeVersion?> getVersionById(String programmeVersionId) async {
    for (final version in programmeTables.versions) {
      if (version.id == programmeVersionId) return version;
    }
    return null;
  }

  @override
  Future<List<ProgrammeVersion>> listVersionsForLineage(String lineageId) async {
    return programmeTables.versions
        .where((version) => version.lineageId == lineageId)
        .toList()
      ..sort((a, b) => a.versionNumber.compareTo(b.versionNumber));
  }

  @override
  Future<List<ProgrammeVersionSessionReference>> listSessionReferences(
    String programmeVersionId,
  ) async {
    final version = await getVersionById(programmeVersionId);
    if (version == null) return const [];

    final weeks = programmeTables.weeks
        .where((week) => week.versionId == version.id)
        .toList()
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

    final references = <ProgrammeVersionSessionReference>[];

    for (final week in weeks) {
      final days = programmeTables.days
          .where((day) => day.weekId == week.id)
          .toList()
        ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));

      for (final day in days) {
        final slots = programmeTables.slots
            .where((slot) => slot.dayId == day.id)
            .toList()
          ..sort((a, b) => a.sessionOrder.compareTo(b.sessionOrder));

        for (final slot in slots) {
          final metadata = await _sessionMetadata(slot.protocolId);
          references.add(
            buildSessionReference(
              version: version,
              week: week,
              day: day,
              slot: slot,
              sessionLineageId: metadata.sessionLineageId,
              sessionRevisionNumber: metadata.revisionNumber,
              sessionName: metadata.sessionName,
              sessionLifecycleStatus: metadata.lifecycleStatus,
            ),
          );
        }
      }
    }

    references.sort(compareProgrammeVersionSessionReferences);
    return references;
  }

  @override
  Future<List<ProgrammeVersionAssignmentImpact>> listAssignmentImpact(
    String programmeVersionId,
  ) async {
    return buildActiveAssignmentImpact(
      assignments: programmeTables.assignments,
      programmeVersionId: programmeVersionId,
    );
  }

  @override
  Future<ProgrammeVersionHistoricalImpactResult> getHistoricalImpact(
    String programmeVersionId,
  ) async {
    if (historicalLookupFails) {
      return ProgrammeVersionHistoricalImpactResult(
        impact: ProgrammeVersionHistoricalImpact(
          terminalRecordCount: 0,
          completedSessionCount: 0,
          skippedSessionCount: 0,
          athleteCount: 0,
          sessionRevisionCount: 0,
          exerciseResultCount: 0,
          isAuthoritative: false,
          limitationNote: 'Historical impact lookup failed.',
        ),
        lookupFailed: true,
        failureMessage: 'Historical impact lookup failed.',
      );
    }

    final assignmentVersionById =
        buildAssignmentVersionIndex(programmeTables.assignments);
    final slotVersionById = buildSlotVersionIndex(
      slots: programmeTables.slots,
      days: programmeTables.days,
      weeks: programmeTables.weeks,
    );

    final attributedRecords = performanceRecords.where(
      (record) => isRecordAttributableToProgrammeVersion(
        record: record,
        programmeVersionId: programmeVersionId,
        assignmentVersionById: assignmentVersionById,
        slotVersionById: slotVersionById,
      ),
    );

    final skippedCount = countSkippedSlotOutcomes(
      outcomes: programmeTables.outcomes,
      assignments: programmeTables.assignments,
      programmeVersionId: programmeVersionId,
    );

    var exerciseResultCount = 0;
    for (final record in attributedRecords) {
      for (final block in record.blockResults) {
        exerciseResultCount += block.exerciseResults.length;
      }
    }

    return ProgrammeVersionHistoricalImpactResult(
      impact: buildHistoricalImpactFromRecords(
        terminalRecords: attributedRecords,
        skippedSessionCount: skippedCount,
        exerciseResultCount: exerciseResultCount,
        isAuthoritative: true,
      ),
    );
  }

  @override
  Future<List<ProgrammeVersionExerciseReference>> listExerciseReferences(
    String programmeVersionId,
    Set<String> protocolIds,
  ) async {
    if (exerciseTables == null || protocolIds.isEmpty) return const [];

    final byExercise = <String, _ExerciseAccumulator>{};

    for (final link in exerciseTables!.blockLinks) {
      if (!protocolIds.contains(link.protocolId)) continue;

      final exercise = exerciseTables!.exercises
          .where((entry) => entry.exerciseId == link.exerciseId)
          .firstOrNull;
      final exerciseName = exercise?.name ?? link.exerciseId;

      final accumulator = byExercise.putIfAbsent(
        link.exerciseId,
        () => _ExerciseAccumulator(
          exerciseId: link.exerciseId,
          exerciseName: exerciseName,
        ),
      );
      accumulator.blockLinkCount++;
      accumulator.sessionRevisionIds.add(link.protocolId);
      accumulator.isLegacyReference = false;
    }

    for (final step in exerciseTables!.legacySteps) {
      if (!protocolIds.contains(step.protocolId)) continue;
      if (byExercise.values.any(
        (entry) =>
            entry.sessionRevisionIds.contains(step.protocolId) &&
            !entry.isLegacyReference,
      )) {
        continue;
      }

      final exercise = exerciseTables!.exercises
          .where((entry) => entry.exerciseId == step.exerciseId)
          .firstOrNull;
      final exerciseName = exercise?.name ?? step.exerciseId;

      final accumulator = byExercise.putIfAbsent(
        step.exerciseId,
        () => _ExerciseAccumulator(
          exerciseId: step.exerciseId,
          exerciseName: exerciseName,
        ),
      );
      accumulator.blockLinkCount++;
      accumulator.sessionRevisionIds.add(step.protocolId);
      accumulator.isLegacyReference = true;
    }

    final results = byExercise.values
        .map(
          (accumulator) => ProgrammeVersionExerciseReference(
            exerciseId: accumulator.exerciseId,
            exerciseName: accumulator.exerciseName,
            sessionRevisionIds: accumulator.sessionRevisionIds.toList()..sort(),
            sessionCount: accumulator.sessionRevisionIds.length,
            blockLinkCount: accumulator.blockLinkCount,
            isLegacyReference: accumulator.isLegacyReference,
          ),
        )
        .toList()
      ..sort(compareProgrammeVersionExerciseReferences);

    return results;
  }

  Future<_SessionMetadata> _sessionMetadata(String protocolId) async {
    final identity = await lineageStore.getRevisionIdentity(protocolId);
    final lifecycle = await lineageStore.getRevisionLifecycleStatus(protocolId);
    final published = protocolPublished[protocolId] ?? true;

    return _SessionMetadata(
      sessionLineageId: identity?.sessionLineageId ?? 'unknown-lineage',
      revisionNumber: identity?.revisionNumber ?? 1,
      sessionName: protocolNames[protocolId] ?? 'Session',
      lifecycleStatus: lifecycle ??
          defaultSessionLifecycleForProtocol(published: published),
    );
  }
}

class _SessionMetadata {
  const _SessionMetadata({
    required this.sessionLineageId,
    required this.revisionNumber,
    required this.sessionName,
    required this.lifecycleStatus,
  });

  final String sessionLineageId;
  final int revisionNumber;
  final String sessionName;
  final SessionRevisionLifecycleStatus lifecycleStatus;
}

class _ExerciseAccumulator {
  _ExerciseAccumulator({
    required this.exerciseId,
    required this.exerciseName,
  });

  final String exerciseId;
  final String exerciseName;
  final Set<String> sessionRevisionIds = {};
  var blockLinkCount = 0;
  var isLegacyReference = false;
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
