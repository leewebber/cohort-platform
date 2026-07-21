import '../../../data/repositories/programme_version_impact_store.dart';
import '../../../data/repositories/programme_version_impact_supabase_store.dart';
import '../models/programme_version_impact_models.dart';
import 'programme_version_impact_message_builder.dart';

/// Read-only Programme Version impact analysis (M10.1).
///
/// Answers what depends on one exact Programme Version without making policy
/// decisions or migration recommendations.
class ProgrammeVersionImpactService {
  ProgrammeVersionImpactService({
    ProgrammeVersionImpactStore? impactStore,
  }) : _impactStore = impactStore ?? const ProgrammeVersionImpactSupabaseStore();

  final ProgrammeVersionImpactStore _impactStore;

  Future<ProgrammeVersionImpactSummary> getImpactForVersion(
    String programmeVersionId,
  ) async {
    final lookup = await tryGetImpactForVersion(programmeVersionId);
    switch (lookup.status) {
      case ProgrammeVersionImpactLookupStatus.success:
        return lookup.summary!;
      case ProgrammeVersionImpactLookupStatus.versionNotFound:
        throw ProgrammeVersionImpactStoreException(
          'Programme version ${programmeVersionId.trim()} was not found.',
        );
      case ProgrammeVersionImpactLookupStatus.lookupFailed:
        throw ProgrammeVersionImpactStoreException(
          lookup.message ?? 'Programme version impact lookup failed.',
        );
    }
  }

  Future<ProgrammeVersionImpactLookupResult> tryGetImpactForVersion(
    String programmeVersionId,
  ) async {
    final normalizedVersionId = programmeVersionId.trim();
    if (normalizedVersionId.isEmpty) {
      return const ProgrammeVersionImpactLookupResult.versionNotFound();
    }

    try {
      final version = await _impactStore.getVersionById(normalizedVersionId);
      if (version == null) {
        return const ProgrammeVersionImpactLookupResult.versionNotFound();
      }

      final sessionReferences =
          await getSessionReferences(normalizedVersionId);
      final exerciseReferences = await getExerciseReferences(
        normalizedVersionId,
        sessionReferences.map((reference) => reference.protocolId).toSet(),
      );
      final activeAssignments =
          await getAssignmentImpact(normalizedVersionId);
      final historicalResult =
          await _impactStore.getHistoricalImpact(normalizedVersionId);
      final lineageVersions =
          await _impactStore.listVersionsForLineage(version.lineageId);
      final lineageContext = buildProgrammeVersionLineageContext(
        queriedVersion: version,
        lineageVersions: lineageVersions,
      );

      final hasAuthoredContent = sessionReferences.isNotEmpty;
      final hasActiveOperationalImpact = activeAssignments.isNotEmpty;
      final hasHistoricalImpact = historicalResult.impact.hasUsage;

      final warnings = <String>[];
      if (historicalResult.lookupFailed) {
        warnings.add(
          historicalResult.failureMessage ??
              'Historical impact could not be loaded for this Programme Version.',
        );
      } else if (!historicalResult.impact.isAuthoritative) {
        warnings.add(
          historicalResult.impact.limitationNote ??
              'Historical impact is partially unavailable.',
        );
      }

      final summary = ProgrammeVersionImpactSummary(
        programmeVersionId: version.id,
        programmeLineageId: version.lineageId,
        programmeName: version.name,
        versionNumber: version.versionNumber,
        lifecycleStatus: version.lifecycleStatus,
        sessionReferences: sessionReferences,
        distinctSessionRevisionCount:
            countDistinctSessionRevisions(sessionReferences),
        distinctSessionLineageCount:
            countDistinctSessionLineages(sessionReferences),
        totalSessionSlotCount: sessionReferences.length,
        exerciseReferences: exerciseReferences,
        distinctExerciseCount: exerciseReferences.length,
        activeAssignments: activeAssignments,
        activeAssignmentCount: activeAssignments.length,
        historicalImpact: historicalResult.impact,
        lineageContext: lineageContext,
        classifications: buildProgrammeVersionImpactClassifications(
          hasAuthoredContent: hasAuthoredContent,
          hasActiveOperationalImpact: hasActiveOperationalImpact,
          hasHistoricalImpact: hasHistoricalImpact,
        ),
        hasAuthoredContent: hasAuthoredContent,
        hasActiveOperationalImpact: hasActiveOperationalImpact,
        hasHistoricalImpact: hasHistoricalImpact,
        isUnused: !hasActiveOperationalImpact && !hasHistoricalImpact,
        warnings: warnings,
        summaryMessages: const [],
      );

      return ProgrammeVersionImpactLookupResult.success(
        ProgrammeVersionImpactSummary(
          programmeVersionId: summary.programmeVersionId,
          programmeLineageId: summary.programmeLineageId,
          programmeName: summary.programmeName,
          versionNumber: summary.versionNumber,
          lifecycleStatus: summary.lifecycleStatus,
          sessionReferences: summary.sessionReferences,
          distinctSessionRevisionCount: summary.distinctSessionRevisionCount,
          distinctSessionLineageCount: summary.distinctSessionLineageCount,
          totalSessionSlotCount: summary.totalSessionSlotCount,
          exerciseReferences: summary.exerciseReferences,
          distinctExerciseCount: summary.distinctExerciseCount,
          activeAssignments: summary.activeAssignments,
          activeAssignmentCount: summary.activeAssignmentCount,
          historicalImpact: summary.historicalImpact,
          lineageContext: summary.lineageContext,
          classifications: summary.classifications,
          hasAuthoredContent: summary.hasAuthoredContent,
          hasActiveOperationalImpact: summary.hasActiveOperationalImpact,
          hasHistoricalImpact: summary.hasHistoricalImpact,
          isUnused: summary.isUnused,
          warnings: summary.warnings,
          summaryMessages:
              ProgrammeVersionImpactMessageBuilder.buildSummaryMessages(summary),
        ),
      );
    } catch (error) {
      return ProgrammeVersionImpactLookupResult.lookupFailed(error.toString());
    }
  }

  Future<List<ProgrammeVersionSessionReference>> getSessionReferences(
    String programmeVersionId,
  ) {
    return _impactStore.listSessionReferences(programmeVersionId.trim());
  }

  Future<List<ProgrammeVersionExerciseReference>> getExerciseReferences(
    String programmeVersionId,
    Set<String> protocolIds,
  ) {
    return _impactStore.listExerciseReferences(
      programmeVersionId.trim(),
      protocolIds,
    );
  }

  Future<List<ProgrammeVersionAssignmentImpact>> getAssignmentImpact(
    String programmeVersionId,
  ) {
    return _impactStore.listAssignmentImpact(programmeVersionId.trim());
  }

  Future<ProgrammeVersionHistoricalImpact> getHistoricalImpact(
    String programmeVersionId,
  ) async {
    final result =
        await _impactStore.getHistoricalImpact(programmeVersionId.trim());
    return result.impact;
  }

  Future<ProgrammeVersionLineageContext> getLineageContext(
    String programmeVersionId,
  ) async {
    final version = await _impactStore.getVersionById(programmeVersionId.trim());
    if (version == null) {
      throw ProgrammeVersionImpactStoreException(
        'Programme version ${programmeVersionId.trim()} was not found.',
      );
    }

    final lineageVersions =
        await _impactStore.listVersionsForLineage(version.lineageId);
    return buildProgrammeVersionLineageContext(
      queriedVersion: version,
      lineageVersions: lineageVersions,
    );
  }
}
