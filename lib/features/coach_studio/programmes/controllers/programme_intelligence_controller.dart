import 'package:flutter/foundation.dart';

import '../../../../data/repositories/programme_version_impact_store.dart';
import '../../../../models/programme_version.dart';
import '../../../programme_comparison/models/programme_version_comparison_models.dart';
import '../../../programme_comparison/services/programme_version_comparison_service.dart';
import '../../../programme_impact/models/programme_version_impact_models.dart';
import '../../../programme_impact/services/programme_version_impact_service.dart';
import '../../../programme_migration/models/programme_migration_plan_models.dart';
import '../../../programme_migration/services/programme_migration_planner_service.dart';
import '../models/programme_intelligence_view_state.dart';
import '../../coach_studio_error_messages.dart';

/// Orchestrates M10.1–M10.3 services for Coach Studio Programme Intelligence.
class ProgrammeIntelligenceController extends ChangeNotifier {
  ProgrammeIntelligenceController({
    required String versionId,
    required ProgrammeVersionImpactService impactService,
    required ProgrammeVersionComparisonService comparisonService,
    required ProgrammeMigrationPlannerService migrationPlannerService,
    required ProgrammeVersionImpactStore impactStore,
  })  : _versionId = versionId.trim(),
        _impactService = impactService,
        _comparisonService = comparisonService,
        _migrationPlannerService = migrationPlannerService,
        _impactStore = impactStore,
        _state = ProgrammeIntelligenceViewState.initial();

  final String _versionId;
  final ProgrammeVersionImpactService _impactService;
  final ProgrammeVersionComparisonService _comparisonService;
  final ProgrammeMigrationPlannerService _migrationPlannerService;
  final ProgrammeVersionImpactStore _impactStore;

  ProgrammeIntelligenceViewState _state;

  ProgrammeIntelligenceViewState get state => _state;
  String get versionId => _versionId;

  Future<void> load() async {
    await loadImpact();
  }

  Future<void> refresh() => load();

  Future<void> loadImpact() async {
    _state = _state.copyWith(
      impactStatus: ProgrammeIntelligenceCardStatus.loading,
      clearImpactError: true,
    );
    notifyListeners();

    try {
      final lookup = await _impactService.tryGetImpactForVersion(_versionId);
      switch (lookup.status) {
        case ProgrammeVersionImpactLookupStatus.versionNotFound:
          _state = _state.copyWith(
            impactStatus: ProgrammeIntelligenceCardStatus.error,
            impactError: 'This programme version could not be found.',
          );
        case ProgrammeVersionImpactLookupStatus.lookupFailed:
          _state = _state.copyWith(
            impactStatus: ProgrammeIntelligenceCardStatus.error,
            impactError: lookup.message ?? 'Impact lookup failed.',
          );
        case ProgrammeVersionImpactLookupStatus.success:
          final summary = lookup.summary!;
          final versions = await _impactStore.listVersionsForLineage(
            summary.programmeLineageId,
          );
          _state = _state.copyWith(
            impactStatus: ProgrammeIntelligenceCardStatus.ready,
            impactSummary: summary,
            lineageVersions: _sortedLineageVersions(versions),
          );
      }
    } catch (error, stackTrace) {
      debugPrint('Impact lookup failed: $error\n$stackTrace');
      _state = _state.copyWith(
        impactStatus: ProgrammeIntelligenceCardStatus.error,
        impactError: CoachStudioErrorMessages.fromObject(error),
      );
    }

    notifyListeners();
  }

  Future<void> selectComparisonTarget(String? targetVersionId) async {
    final normalized = targetVersionId?.trim();
    if (normalized == null || normalized.isEmpty || normalized == _versionId) {
      _state = _state.copyWith(
        clearComparisonTarget: true,
        clearComparisonSummary: true,
        clearMigrationPlan: true,
        comparisonStatus: ProgrammeIntelligenceCardStatus.idle,
        migrationStatus: ProgrammeIntelligenceCardStatus.idle,
        clearComparisonError: true,
        clearMigrationError: true,
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      selectedComparisonTargetVersionId: normalized,
      comparisonStatus: ProgrammeIntelligenceCardStatus.loading,
      migrationStatus: ProgrammeIntelligenceCardStatus.loading,
      clearComparisonSummary: true,
      clearMigrationPlan: true,
      clearComparisonError: true,
      clearMigrationError: true,
    );
    notifyListeners();

    await Future.wait([
      _loadComparison(normalized),
      _loadMigrationPlan(normalized),
    ]);
  }

  Future<void> _loadComparison(String targetVersionId) async {
    try {
      final lookup = await _comparisonService.tryCompareVersions(
        sourceProgrammeVersionId: _versionId,
        targetProgrammeVersionId: targetVersionId,
      );

      switch (lookup.status) {
        case ProgrammeVersionComparisonStatus.sourceNotFound:
        case ProgrammeVersionComparisonStatus.targetNotFound:
          _state = _state.copyWith(
            comparisonStatus: ProgrammeIntelligenceCardStatus.error,
            comparisonError: 'One of the selected programme versions was not found.',
          );
        case ProgrammeVersionComparisonStatus.incompatibleLineage:
          _state = _state.copyWith(
            comparisonStatus: ProgrammeIntelligenceCardStatus.error,
            comparisonError: 'Versions must belong to the same programme lineage.',
          );
        case ProgrammeVersionComparisonStatus.lookupFailed:
          _state = _state.copyWith(
            comparisonStatus: ProgrammeIntelligenceCardStatus.error,
            comparisonError: lookup.message ?? 'Comparison lookup failed.',
          );
        case ProgrammeVersionComparisonStatus.success:
        case ProgrammeVersionComparisonStatus.partial:
          final summary = lookup.summary;
          if (summary == null) {
            _state = _state.copyWith(
              comparisonStatus: ProgrammeIntelligenceCardStatus.error,
              comparisonError: 'Comparison summary was unavailable.',
            );
          } else {
            _state = _state.copyWith(
              comparisonStatus: ProgrammeIntelligenceCardStatus.ready,
              comparisonSummary: summary,
              comparisonPartial: summary.isPartial,
            );
          }
      }
    } catch (error) {
      _state = _state.copyWith(
        comparisonStatus: ProgrammeIntelligenceCardStatus.error,
        comparisonError: error.toString(),
      );
    }

    notifyListeners();
  }

  Future<void> _loadMigrationPlan(String targetVersionId) async {
    try {
      final lookup = await _migrationPlannerService.tryPlanMigration(
        sourceProgrammeVersionId: _versionId,
        targetProgrammeVersionId: targetVersionId,
      );

      switch (lookup.status) {
        case ProgrammeMigrationPlannerStatus.sourceNotFound:
        case ProgrammeMigrationPlannerStatus.targetNotFound:
          _state = _state.copyWith(
            migrationStatus: ProgrammeIntelligenceCardStatus.error,
            migrationError: 'One of the selected programme versions was not found.',
          );
        case ProgrammeMigrationPlannerStatus.incompatibleLineage:
          _state = _state.copyWith(
            migrationStatus: ProgrammeIntelligenceCardStatus.error,
            migrationError: 'Versions must belong to the same programme lineage.',
          );
        case ProgrammeMigrationPlannerStatus.comparisonUnavailable:
        case ProgrammeMigrationPlannerStatus.impactUnavailable:
        case ProgrammeMigrationPlannerStatus.assignmentUnavailable:
        case ProgrammeMigrationPlannerStatus.lookupFailed:
          _state = _state.copyWith(
            migrationStatus: ProgrammeIntelligenceCardStatus.error,
            migrationError: lookup.message ?? 'Migration planning failed.',
          );
        case ProgrammeMigrationPlannerStatus.success:
        case ProgrammeMigrationPlannerStatus.partial:
          final plan = lookup.plan;
          if (plan == null) {
            _state = _state.copyWith(
              migrationStatus: ProgrammeIntelligenceCardStatus.error,
              migrationError: 'Migration plan was unavailable.',
            );
          } else {
            _state = _state.copyWith(
              migrationStatus: ProgrammeIntelligenceCardStatus.ready,
              migrationPlan: plan,
              migrationPartial: plan.isPartial,
            );
          }
      }
    } catch (error) {
      _state = _state.copyWith(
        migrationStatus: ProgrammeIntelligenceCardStatus.error,
        migrationError: error.toString(),
      );
    }

    notifyListeners();
  }

  List<ProgrammeVersion> _sortedLineageVersions(List<ProgrammeVersion> versions) {
    final sorted = versions.toList()
      ..sort((a, b) => b.versionNumber.compareTo(a.versionNumber));
    return sorted;
  }
}
