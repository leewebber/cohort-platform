import '../../../data/repositories/programme_version_comparison_store.dart';
import '../../../data/repositories/programme_version_comparison_supabase_store.dart';
import '../models/programme_version_comparison_models.dart';
import 'programme_version_comparison_engine.dart';
import 'programme_version_comparison_message_builder.dart';

/// Deterministic Programme Version comparison (M10.2).
class ProgrammeVersionComparisonService {
  ProgrammeVersionComparisonService({
    ProgrammeVersionComparisonStore? comparisonStore,
  }) : _comparisonStore =
            comparisonStore ?? const ProgrammeVersionComparisonSupabaseStore();

  final ProgrammeVersionComparisonStore _comparisonStore;

  Future<ProgrammeVersionComparisonSummary> compareVersions({
    required String sourceProgrammeVersionId,
    required String targetProgrammeVersionId,
  }) async {
    final lookup = await tryCompareVersions(
      sourceProgrammeVersionId: sourceProgrammeVersionId,
      targetProgrammeVersionId: targetProgrammeVersionId,
    );

    switch (lookup.status) {
      case ProgrammeVersionComparisonStatus.success:
      case ProgrammeVersionComparisonStatus.partial:
        return lookup.summary!;
      case ProgrammeVersionComparisonStatus.sourceNotFound:
        throw ProgrammeVersionComparisonStoreException(
          'Source programme version ${sourceProgrammeVersionId.trim()} was not found.',
        );
      case ProgrammeVersionComparisonStatus.targetNotFound:
        throw ProgrammeVersionComparisonStoreException(
          'Target programme version ${targetProgrammeVersionId.trim()} was not found.',
        );
      case ProgrammeVersionComparisonStatus.incompatibleLineage:
        throw ProgrammeVersionComparisonStoreException(
          'Programme versions belong to different lineages and cannot be compared.',
        );
      case ProgrammeVersionComparisonStatus.lookupFailed:
        throw ProgrammeVersionComparisonStoreException(
          lookup.message ?? 'Programme version comparison lookup failed.',
        );
    }
  }

  Future<ProgrammeVersionComparisonLookupResult> tryCompareVersions({
    required String sourceProgrammeVersionId,
    required String targetProgrammeVersionId,
  }) async {
    final sourceId = sourceProgrammeVersionId.trim();
    final targetId = targetProgrammeVersionId.trim();

    if (sourceId.isEmpty) {
      return const ProgrammeVersionComparisonLookupResult.sourceNotFound();
    }
    if (targetId.isEmpty) {
      return const ProgrammeVersionComparisonLookupResult.targetNotFound();
    }

    try {
      final sourceVersion = await _comparisonStore.getVersionById(sourceId);
      if (sourceVersion == null) {
        return const ProgrammeVersionComparisonLookupResult.sourceNotFound();
      }

      final targetVersion = await _comparisonStore.getVersionById(targetId);
      if (targetVersion == null) {
        return const ProgrammeVersionComparisonLookupResult.targetNotFound();
      }

      if (sourceVersion.lineageId != targetVersion.lineageId) {
        return const ProgrammeVersionComparisonLookupResult.incompatibleLineage();
      }

      final sourceSnapshot = await _comparisonStore.loadSnapshot(sourceId);
      final targetSnapshot = await _comparisonStore.loadSnapshot(targetId);
      final normalizedTarget = _normalizeExerciseSide(
        targetSnapshot,
        asTarget: true,
      );
      final normalizedSource = _normalizeExerciseSide(
        sourceSnapshot,
        asTarget: false,
      );

      final compared = ProgrammeVersionComparisonEngine.compare(
        source: normalizedSource,
        target: normalizedTarget,
      );

      final summary = ProgrammeVersionComparisonSummary(
        identity: compared.identity,
        metadataChanges: compared.metadataChanges,
        weekChanges: compared.weekChanges,
        dayChanges: compared.dayChanges,
        slotChanges: compared.slotChanges,
        sessionRevisionChanges: compared.sessionRevisionChanges,
        exerciseChanges: compared.exerciseChanges,
        exerciseSetChange: compared.exerciseSetChange,
        structureMetrics: compared.structureMetrics,
        classifications: compared.classifications,
        isIdentical: compared.isIdentical,
        hasStructuralChanges: compared.hasStructuralChanges,
        hasSessionChanges: compared.hasSessionChanges,
        hasExerciseChanges: compared.hasExerciseChanges,
        warnings: compared.warnings,
        limitationNotes: compared.limitationNotes,
        summaryMessages: ProgrammeVersionComparisonMessageBuilder.buildSummaryMessages(
          compared,
        ),
        isPartial: compared.isPartial,
      );

      if (summary.isPartial) {
        return ProgrammeVersionComparisonLookupResult.partial(summary);
      }

      return ProgrammeVersionComparisonLookupResult.success(summary);
    } catch (error) {
      return ProgrammeVersionComparisonLookupResult.lookupFailed(
        error.toString(),
      );
    }
  }

  Future<List<ProgrammeMetadataChange>> compareMetadata({
    required String sourceProgrammeVersionId,
    required String targetProgrammeVersionId,
  }) async {
    final summary = await compareVersions(
      sourceProgrammeVersionId: sourceProgrammeVersionId,
      targetProgrammeVersionId: targetProgrammeVersionId,
    );
    return summary.metadataChanges;
  }

  Future<List<ProgrammeSlotChange>> compareSlots({
    required String sourceProgrammeVersionId,
    required String targetProgrammeVersionId,
  }) async {
    final summary = await compareVersions(
      sourceProgrammeVersionId: sourceProgrammeVersionId,
      targetProgrammeVersionId: targetProgrammeVersionId,
    );
    return summary.slotChanges;
  }

  Future<List<ExerciseReferenceChange>> compareExercises({
    required String sourceProgrammeVersionId,
    required String targetProgrammeVersionId,
  }) async {
    final summary = await compareVersions(
      sourceProgrammeVersionId: sourceProgrammeVersionId,
      targetProgrammeVersionId: targetProgrammeVersionId,
    );
    return summary.exerciseChanges;
  }

  ProgrammeVersionComparisonSnapshot _normalizeExerciseSide(
    ProgrammeVersionComparisonSnapshot snapshot, {
    required bool asTarget,
  }) {
    return ProgrammeVersionComparisonSnapshot(
      versionId: snapshot.versionId,
      lineageId: snapshot.lineageId,
      versionNumber: snapshot.versionNumber,
      lifecycleStatus: snapshot.lifecycleStatus,
      programmeName: snapshot.programmeName,
      metadata: snapshot.metadata,
      weeks: snapshot.weeks,
      days: snapshot.days,
      slots: snapshot.slots,
      exercises: snapshot.exercises
          .map(
            (exercise) => ExerciseReferenceChange(
              exerciseId: exercise.exerciseId,
              exerciseName: exercise.exerciseName,
              changeType: ProgrammeChangeType.unchanged,
              sourceSessionRevisionIds: asTarget
                  ? const []
                  : exercise.sourceSessionRevisionIds,
              targetSessionRevisionIds: asTarget
                  ? exercise.sourceSessionRevisionIds
                  : const [],
              sourceBlockLinkCount:
                  asTarget ? 0 : exercise.sourceBlockLinkCount,
              targetBlockLinkCount:
                  asTarget ? exercise.sourceBlockLinkCount : 0,
            ),
          )
          .toList(),
      exerciseEnrichmentAuthoritative: snapshot.exerciseEnrichmentAuthoritative,
      exerciseEnrichmentLimitation: snapshot.exerciseEnrichmentLimitation,
      sessionEnrichmentAuthoritative: snapshot.sessionEnrichmentAuthoritative,
      sessionEnrichmentLimitation: snapshot.sessionEnrichmentLimitation,
    );
  }
}
