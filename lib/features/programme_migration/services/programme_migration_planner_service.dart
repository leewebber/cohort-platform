import '../../../data/repositories/programme_migration_planner_store.dart';
import '../../../data/repositories/programme_migration_planner_supabase_store.dart';
import '../../../data/repositories/programme_version_comparison_store.dart';
import '../../../data/repositories/programme_version_comparison_supabase_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_slot_outcome.dart';
import '../../programme_comparison/models/programme_version_comparison_models.dart';
import '../../programme_comparison/services/programme_version_comparison_service.dart';
import '../../programme_impact/models/programme_version_impact_models.dart';
import '../../programme_impact/services/programme_version_impact_service.dart';
import '../models/programme_migration_plan_models.dart';
import 'programme_migration_planner_engine.dart';
import 'programme_migration_recommendation_builder.dart';

export '../../../data/repositories/programme_migration_planner_store.dart'
    show ProgrammeMigrationPlannerStoreException;

/// Read-only Programme assignment migration planning (M10.3).
///
/// Produces facts and classifications only — never mutates assignments.
class ProgrammeMigrationPlannerService {
  ProgrammeMigrationPlannerService({
    ProgrammeVersionComparisonService? comparisonService,
    ProgrammeVersionImpactService? impactService,
    ProgrammeMigrationPlannerStore? plannerStore,
    ProgrammeVersionComparisonStore? comparisonStore,
  })  : _comparisonService =
            comparisonService ?? ProgrammeVersionComparisonService(),
        _impactService = impactService ?? ProgrammeVersionImpactService(),
        _plannerStore =
            plannerStore ?? const ProgrammeMigrationPlannerSupabaseStore(),
        _comparisonStore =
            comparisonStore ?? const ProgrammeVersionComparisonSupabaseStore();

  final ProgrammeVersionComparisonService _comparisonService;
  final ProgrammeVersionImpactService _impactService;
  final ProgrammeMigrationPlannerStore _plannerStore;
  final ProgrammeVersionComparisonStore _comparisonStore;

  Future<ProgrammeMigrationPlan> planMigration({
    required String sourceProgrammeVersionId,
    required String targetProgrammeVersionId,
    List<String>? assignmentIds,
  }) async {
    final lookup = await tryPlanMigration(
      sourceProgrammeVersionId: sourceProgrammeVersionId,
      targetProgrammeVersionId: targetProgrammeVersionId,
      assignmentIds: assignmentIds,
    );

    switch (lookup.status) {
      case ProgrammeMigrationPlannerStatus.success:
      case ProgrammeMigrationPlannerStatus.partial:
        return lookup.plan!;
      case ProgrammeMigrationPlannerStatus.sourceNotFound:
        throw ProgrammeMigrationPlannerStoreException(
          'Source programme version ${sourceProgrammeVersionId.trim()} was not found.',
        );
      case ProgrammeMigrationPlannerStatus.targetNotFound:
        throw ProgrammeMigrationPlannerStoreException(
          'Target programme version ${targetProgrammeVersionId.trim()} was not found.',
        );
      case ProgrammeMigrationPlannerStatus.incompatibleLineage:
        throw ProgrammeMigrationPlannerStoreException(
          'Programme versions belong to different lineages and cannot be planned.',
        );
      case ProgrammeMigrationPlannerStatus.comparisonUnavailable:
        throw ProgrammeMigrationPlannerStoreException(
          lookup.message ?? 'Programme version comparison is unavailable.',
        );
      case ProgrammeMigrationPlannerStatus.impactUnavailable:
        throw ProgrammeMigrationPlannerStoreException(
          lookup.message ?? 'Programme version impact is unavailable.',
        );
      case ProgrammeMigrationPlannerStatus.assignmentUnavailable:
        throw ProgrammeMigrationPlannerStoreException(
          lookup.message ?? 'Assignments could not be loaded for planning.',
        );
      case ProgrammeMigrationPlannerStatus.lookupFailed:
        throw ProgrammeMigrationPlannerStoreException(
          lookup.message ?? 'Migration planning lookup failed.',
        );
    }
  }

  Future<ProgrammeMigrationPlannerLookupResult> tryPlanMigration({
    required String sourceProgrammeVersionId,
    required String targetProgrammeVersionId,
    List<String>? assignmentIds,
  }) async {
    final sourceId = sourceProgrammeVersionId.trim();
    final targetId = targetProgrammeVersionId.trim();

    if (sourceId.isEmpty) {
      return const ProgrammeMigrationPlannerLookupResult.sourceNotFound();
    }
    if (targetId.isEmpty) {
      return const ProgrammeMigrationPlannerLookupResult.targetNotFound();
    }

    try {
      final comparisonLookup = await _comparisonService.tryCompareVersions(
        sourceProgrammeVersionId: sourceId,
        targetProgrammeVersionId: targetId,
      );

      switch (comparisonLookup.status) {
        case ProgrammeVersionComparisonStatus.sourceNotFound:
          return const ProgrammeMigrationPlannerLookupResult.sourceNotFound();
        case ProgrammeVersionComparisonStatus.targetNotFound:
          return const ProgrammeMigrationPlannerLookupResult.targetNotFound();
        case ProgrammeVersionComparisonStatus.incompatibleLineage:
          return const ProgrammeMigrationPlannerLookupResult.incompatibleLineage();
        case ProgrammeVersionComparisonStatus.lookupFailed:
          return ProgrammeMigrationPlannerLookupResult.comparisonUnavailable(
            comparisonLookup.message ?? 'Comparison lookup failed.',
          );
        case ProgrammeVersionComparisonStatus.success:
        case ProgrammeVersionComparisonStatus.partial:
          break;
      }

      final comparison = comparisonLookup.summary;
      if (comparison == null) {
        return ProgrammeMigrationPlannerLookupResult.comparisonUnavailable(
          'Comparison summary was unavailable.',
        );
      }

      ProgrammeVersionImpactSummary sourceImpact;
      try {
        sourceImpact = await _impactService.getImpactForVersion(sourceId);
      } catch (error) {
        return ProgrammeMigrationPlannerLookupResult.impactUnavailable(
          error.toString(),
        );
      }

      List<ProgrammeAssignment> assignments;
      try {
        assignments = await _plannerStore.listAssignmentsForPlanning(
          programmeVersionId: sourceId,
          assignmentIds: assignmentIds,
        );
      } catch (error) {
        return ProgrammeMigrationPlannerLookupResult.assignmentUnavailable(
          error.toString(),
        );
      }

      final sourceSnapshot = await _comparisonStore.loadSnapshot(sourceId);
      final sourceSlots = sourceSnapshot.slots;

      final normalizedAssignmentIds = assignments.map((a) => a.id).toList();
      final outcomesByAssignment = normalizedAssignmentIds.isEmpty
          ? const <String, List<ProgrammeSlotOutcome>>{}
          : await _plannerStore.listOutcomesForAssignments(
              normalizedAssignmentIds,
            );

      final warnings = <String>[...comparison.warnings];
      final limitationNotes = <String>[...comparison.limitationNotes];
      var isPartial = comparison.isPartial;

      final assignmentPlans = <AssignmentMigrationPlan>[];

      for (final assignment in assignments) {
        final progress = ProgrammeMigrationPlannerEngine.buildProgressSnapshot(
          assignment: assignment,
          sourceSlots: sourceSlots,
          outcomes: outcomesByAssignment[assignment.id] ?? const [],
        );

        if (!progress.isAuthoritative) {
          isPartial = true;
          if (progress.limitationNote != null) {
            limitationNotes.add(progress.limitationNote!);
          }
        }

        final changeScope = ProgrammeMigrationPlannerEngine.analyzeChangeScope(
          comparison: comparison,
          currentPosition: progress.currentPosition,
        );

        final classification = ProgrammeMigrationPlannerEngine.classifyAssignment(
          assignment: assignment,
          progress: progress,
          changeScope: changeScope,
          comparisonAvailable: true,
          comparisonPartial: comparison.isPartial,
        );

        final reasoning = ProgrammeMigrationPlannerEngine.buildReasoning(
          classification: classification,
          progress: progress,
          changeScope: changeScope,
          comparison: comparison,
        );

        assignmentPlans.add(
          AssignmentMigrationPlan(
            assignmentId: assignment.id,
            assignmentStatus: assignment.status,
            currentWeek: assignment.currentWeek,
            currentDayKey: assignment.currentDayKey,
            currentSessionOrder: assignment.currentSessionOrder,
            completionPercent: progress.completionPercent,
            currentProgrammePosition: progress.currentPosition,
            completedRequiredSlotCount: progress.completedRequiredSlotCount,
            totalRequiredSlotCount: progress.totalRequiredSlotCount,
            hasStarted: progress.hasStarted,
            migrationClassification: classification,
            recommendation:
                ProgrammeMigrationRecommendationBuilder.recommendationFor(
              classification,
            ),
            reasoning: reasoning,
            warnings: progress.limitationNote == null
                ? const []
                : [progress.limitationNote!],
          ),
        );
      }

      assignmentPlans.sort((a, b) => a.assignmentId.compareTo(b.assignmentId));

      final plan = ProgrammeMigrationPlan(
        identity: ProgrammeMigrationIdentity(
          programmeLineageId: comparison.identity.programmeLineageId,
          programmeName: comparison.identity.programmeName,
          sourceProgrammeVersionId: sourceId,
          sourceVersionNumber: comparison.identity.sourceVersionNumber,
          targetProgrammeVersionId: targetId,
          targetVersionNumber: comparison.identity.targetVersionNumber,
          comparisonSummary: comparison,
          sourceImpactSummary: sourceImpact,
        ),
        assignmentPlans: assignmentPlans,
        summary: ProgrammeMigrationPlannerEngine.buildSummary(assignmentPlans),
        warnings: warnings,
        limitationNotes: limitationNotes,
        isPartial: isPartial,
      );

      if (isPartial) {
        return ProgrammeMigrationPlannerLookupResult.partial(plan);
      }

      return ProgrammeMigrationPlannerLookupResult.success(plan);
    } catch (error) {
      return ProgrammeMigrationPlannerLookupResult.lookupFailed(
        error.toString(),
      );
    }
  }
}
