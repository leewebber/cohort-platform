import 'package:cohort_platform/data/repositories/programme_version_comparison_store.dart';
import 'package:cohort_platform/features/programme_comparison/models/programme_version_comparison_models.dart';
import 'package:cohort_platform/features/programme_comparison/services/programme_version_comparison_engine.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:cohort_platform/models/session_revision_vocabulary.dart';

import 'in_memory_exercise_relationship_store.dart';
import 'in_memory_programme_stores.dart';
import 'in_memory_session_lineage_store.dart';

class InMemoryProgrammeVersionComparisonStore
    extends ProgrammeVersionComparisonStore {
  InMemoryProgrammeVersionComparisonStore({
    required this.programmeTables,
    required this.lineageStore,
    this.exerciseTables,
    this.protocolNames = const {},
    this.exerciseEnrichmentAuthoritative = true,
    this.exerciseEnrichmentLimitation,
    this.sessionEnrichmentAuthoritative = true,
    this.sessionEnrichmentLimitation,
  });

  final InMemoryProgrammeTables programmeTables;
  final InMemorySessionLineageStore lineageStore;
  final InMemoryExerciseRelationshipTables? exerciseTables;
  final Map<String, String> protocolNames;
  final bool exerciseEnrichmentAuthoritative;
  final String? exerciseEnrichmentLimitation;
  final bool sessionEnrichmentAuthoritative;
  final String? sessionEnrichmentLimitation;

  @override
  Future<ProgrammeVersion?> getVersionById(String programmeVersionId) async {
    for (final version in programmeTables.versions) {
      if (version.id == programmeVersionId) return version;
    }
    return null;
  }

  @override
  Future<ProgrammeVersionComparisonSnapshot> loadSnapshot(
    String programmeVersionId, {
    bool exerciseEnrichmentAuthoritative = true,
    String? exerciseEnrichmentLimitation,
  }) async {
    final version = await getVersionById(programmeVersionId);
    if (version == null) {
      throw ProgrammeVersionComparisonStoreException(
        'Programme version $programmeVersionId was not found.',
      );
    }

    final weeks = programmeTables.weeks
        .where((week) => week.versionId == version.id)
        .toList()
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));

    final weekRefs = weeks
        .map(
          (week) => ProgrammeWeekReference(
            weekId: week.id,
            weekIndex: week.weekNumber,
            title: week.title,
          ),
        )
        .toList();

    final dayRefs = <ProgrammeDayReference>[];
    final slots = <ProgrammeSlotSnapshot>[];

    for (final week in weeks) {
      final days = programmeTables.days
          .where((day) => day.weekId == week.id)
          .toList()
        ..sort((a, b) => a.dayOrder.compareTo(b.dayOrder));

      for (final day in days) {
        dayRefs.add(
          ProgrammeDayReference(
            dayId: day.id,
            weekIndex: week.weekNumber,
            dayIndex: day.dayOrder,
            dayKey: day.dayKey,
            title: day.title,
          ),
        );

        final daySlots = programmeTables.slots
            .where((slot) => slot.dayId == day.id)
            .toList()
          ..sort((a, b) => a.sessionOrder.compareTo(b.sessionOrder));

        for (final slot in daySlots) {
          final metadata = await _sessionMetadata(slot.protocolId);
          slots.add(
            ProgrammeSlotSnapshot(
              slotId: slot.id,
              weekId: week.id,
              dayId: day.id,
              weekIndex: week.weekNumber,
              dayIndex: day.dayOrder,
              slotIndex: slot.sessionOrder,
              dayKey: day.dayKey,
              protocolId: slot.protocolId,
              sessionLineageId: metadata.sessionLineageId,
              sessionRevisionNumber: metadata.revisionNumber,
              sessionName: metadata.sessionName,
              sessionLifecycleStatus: metadata.lifecycleStatus,
              slotLabel: slot.displayTitle,
              timeOfDay: slot.timeOfDay.dbValue,
              isOptional: slot.isOptional,
              completionExpectation: slot.completionExpectation.dbValue,
              coachNote: slot.coachNote,
              athleteNote: slot.athleteNote,
            ),
          );
        }
      }
    }

    final protocolIds = slots.map((slot) => slot.protocolId).toSet();
    final exercises = await _loadExerciseReferences(
      protocolIds,
      authoritative: exerciseEnrichmentAuthoritative &&
          this.exerciseEnrichmentAuthoritative,
      limitation: exerciseEnrichmentLimitation ?? this.exerciseEnrichmentLimitation,
    );

    return ProgrammeVersionComparisonSnapshot(
      versionId: version.id,
      lineageId: version.lineageId,
      versionNumber: version.versionNumber,
      lifecycleStatus: version.lifecycleStatus,
      programmeName: version.name,
      metadata: ProgrammeVersionComparisonEngine.extractComparableMetadata(
        name: version.name,
        description: version.description,
        durationWeeks: version.durationWeeks,
        targetAthlete: version.targetAthlete,
        difficulty: version.difficulty,
        primaryGoal: version.primaryGoal,
        equipmentRequirements: version.equipmentRequirements,
        sessionsPerWeek: version.sessionsPerWeek,
      ),
      weeks: weekRefs,
      days: dayRefs,
      slots: slots,
      exercises: exercises,
      exerciseEnrichmentAuthoritative: exerciseEnrichmentAuthoritative &&
          this.exerciseEnrichmentAuthoritative,
      exerciseEnrichmentLimitation:
          exerciseEnrichmentLimitation ?? this.exerciseEnrichmentLimitation,
      sessionEnrichmentAuthoritative: sessionEnrichmentAuthoritative,
      sessionEnrichmentLimitation:
          sessionEnrichmentLimitation ?? this.sessionEnrichmentLimitation,
    );
  }

  Future<_SessionMetadata> _sessionMetadata(String protocolId) async {
    if (!sessionEnrichmentAuthoritative) {
      return _SessionMetadata(
        sessionLineageId: 'unknown-lineage',
        revisionNumber: 1,
        sessionName: protocolNames[protocolId] ?? 'Session',
        lifecycleStatus: SessionRevisionLifecycleStatus.published,
      );
    }

    final identity = await lineageStore.getRevisionIdentity(protocolId);
    final lifecycle = await lineageStore.getRevisionLifecycleStatus(protocolId);

    return _SessionMetadata(
      sessionLineageId: identity?.sessionLineageId ?? 'unknown-lineage',
      revisionNumber: identity?.revisionNumber ?? 1,
      sessionName: protocolNames[protocolId] ?? 'Session',
      lifecycleStatus:
          lifecycle ?? SessionRevisionLifecycleStatus.published,
    );
  }

  Future<List<ExerciseReferenceChange>> _loadExerciseReferences(
    Set<String> protocolIds, {
    required bool authoritative,
    String? limitation,
  }) async {
    if (exerciseTables == null || protocolIds.isEmpty) {
      return const [];
    }

    final byExercise = <String, _ExerciseAccumulator>{};

    for (final link in exerciseTables!.blockLinks) {
      if (!protocolIds.contains(link.protocolId)) continue;
      final accumulator = byExercise.putIfAbsent(
        link.exerciseId,
        () => _ExerciseAccumulator(
          exerciseId: link.exerciseId,
          exerciseName: _exerciseName(link.exerciseId),
        ),
      );
      accumulator.blockLinkCount++;
      accumulator.sessionRevisionIds.add(link.protocolId);
    }

    for (final step in exerciseTables!.legacySteps) {
      if (!protocolIds.contains(step.protocolId)) continue;
      if (byExercise.values.any(
        (entry) =>
            entry.sessionRevisionIds.contains(step.protocolId) &&
            !entry.isLegacy,
      )) {
        continue;
      }

      final accumulator = byExercise.putIfAbsent(
        step.exerciseId,
        () => _ExerciseAccumulator(
          exerciseId: step.exerciseId,
          exerciseName: _exerciseName(step.exerciseId),
        ),
      );
      accumulator.blockLinkCount++;
      accumulator.sessionRevisionIds.add(step.protocolId);
      accumulator.isLegacy = true;
    }

    return byExercise.values
        .map(
          (accumulator) => ExerciseReferenceChange(
            exerciseId: accumulator.exerciseId,
            exerciseName: accumulator.exerciseName,
            changeType: ProgrammeChangeType.unchanged,
            sourceSessionRevisionIds: accumulator.sessionRevisionIds.toList()
              ..sort(),
            targetSessionRevisionIds: const [],
            sourceBlockLinkCount: accumulator.blockLinkCount,
            targetBlockLinkCount: 0,
          ),
        )
        .toList()
      ..sort((a, b) => a.exerciseName.compareTo(b.exerciseName));
  }

  String _exerciseName(String exerciseId) {
    for (final exercise in exerciseTables!.exercises) {
      if (exercise.exerciseId == exerciseId) return exercise.name;
    }
    return exerciseId;
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
  var isLegacy = false;
}
