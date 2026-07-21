import '../../../data/repositories/exercise_relationship_store.dart';
import '../../../data/repositories/exercise_relationship_supabase_store.dart';
import '../models/exercise_usage_models.dart';

/// Read-only Exercise usage relationships (M9.4).
class ExerciseRelationshipService {
  ExerciseRelationshipService({
    ExerciseRelationshipStore? relationshipStore,
  }) : _relationshipStore =
            relationshipStore ?? const ExerciseRelationshipSupabaseStore();

  final ExerciseRelationshipStore _relationshipStore;

  Future<ExerciseUsageSummary> getUsageForExercise(String exerciseId) async {
    final lookup = await tryGetUsageForExercise(exerciseId);
    switch (lookup.status) {
      case ExerciseUsageLookupStatus.success:
        return lookup.summary!;
      case ExerciseUsageLookupStatus.exerciseNotFound:
        throw ExerciseRelationshipStoreException(
          'Exercise ${exerciseId.trim()} was not found.',
        );
      case ExerciseUsageLookupStatus.lookupFailed:
        throw ExerciseRelationshipStoreException(
          lookup.message ?? 'Exercise usage lookup failed.',
        );
    }
  }

  Future<ExerciseUsageLookupResult> tryGetUsageForExercise(
    String exerciseId,
  ) async {
    final normalizedExerciseId = exerciseId.trim();
    if (normalizedExerciseId.isEmpty) {
      return const ExerciseUsageLookupResult.exerciseNotFound();
    }

    try {
      final exercise =
          await _relationshipStore.getExerciseById(normalizedExerciseId);
      if (exercise == null) {
        return const ExerciseUsageLookupResult.exerciseNotFound();
      }

      final sessionReferences =
          await getSessionRevisionReferences(normalizedExerciseId);
      final protocolIds =
          sessionReferences.map((reference) => reference.protocolId).toSet();
      final programmeReferences =
          await getProgrammeReferences(normalizedExerciseId, protocolIds);
      final programmeVersionIds = programmeReferences
          .map((reference) => reference.programmeVersionId)
          .toSet();
      final activeAssignmentReferences = await getActiveAssignmentReferences(
        normalizedExerciseId,
        programmeVersionIds,
      );
      final historicalUsage =
          await getHistoricalUsage(normalizedExerciseId);

      final sessionLineageReferences =
          buildSessionLineageReferences(sessionReferences);

      final hasDirectAuthoredUsage = sessionReferences.isNotEmpty;
      final hasActiveOperationalUsage = activeAssignmentReferences.isNotEmpty;
      final hasHistoricalUsage =
          historicalUsage.isAuthoritative && historicalUsage.hasUsage;

      return ExerciseUsageLookupResult.success(
        ExerciseUsageSummary(
          exerciseId: exercise.exerciseId,
          exerciseName: exercise.name,
          directSessionReferences: sessionReferences,
          sessionLineageReferences: sessionLineageReferences,
          programmeReferences: programmeReferences,
          activeAssignmentReferences: activeAssignmentReferences,
          historicalUsage: historicalUsage,
          classifications: buildExerciseUsageClassifications(
            hasDirectAuthoredUsage: hasDirectAuthoredUsage,
            hasActiveOperationalUsage: hasActiveOperationalUsage,
            hasHistoricalUsage: hasHistoricalUsage,
          ),
          directSessionRevisionCount: protocolIds.length,
          directBlockReferenceCount: sessionReferences.length,
          sessionLineageCount: sessionLineageReferences.length,
          programmeVersionCount: programmeVersionIds.length,
          activeAssignmentCount: activeAssignmentReferences.length,
          historicalRecordCount: historicalUsage.recordCount,
        ),
      );
    } catch (error) {
      return ExerciseUsageLookupResult.lookupFailed(error.toString());
    }
  }

  Future<List<ExerciseRevisionReference>> getSessionRevisionReferences(
    String exerciseId,
  ) {
    return _relationshipStore.listSessionRevisionReferences(exerciseId.trim());
  }

  Future<List<ExerciseProgrammeReference>> getProgrammeReferences(
    String exerciseId,
    Set<String> protocolIds,
  ) {
    return _relationshipStore.listProgrammeReferences(
      exerciseId.trim(),
      protocolIds,
    );
  }

  Future<List<ExerciseAssignmentReference>> getActiveAssignmentReferences(
    String exerciseId,
    Set<String> programmeVersionIds,
  ) {
    return _relationshipStore.listActiveAssignmentReferences(
      exerciseId.trim(),
      programmeVersionIds,
    );
  }

  Future<ExerciseHistoricalUsage> getHistoricalUsage(String exerciseId) {
    return _relationshipStore.getHistoricalUsage(exerciseId.trim());
  }
}
