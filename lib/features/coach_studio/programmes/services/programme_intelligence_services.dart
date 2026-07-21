import '../../../../data/repositories/programme_version_impact_store.dart';
import '../../../../data/repositories/programme_version_impact_supabase_store.dart';
import '../../../programme_comparison/services/programme_version_comparison_service.dart';
import '../../../programme_impact/services/programme_version_impact_service.dart';
import '../../../programme_migration/services/programme_migration_planner_service.dart';
import '../controllers/programme_intelligence_controller.dart';

/// Production wiring for Programme Intelligence (M10.4).
class ProgrammeIntelligenceServices {
  ProgrammeIntelligenceServices._();

  static ProgrammeIntelligenceController createController({
    required String versionId,
    ProgrammeVersionImpactService? impactService,
    ProgrammeVersionComparisonService? comparisonService,
    ProgrammeMigrationPlannerService? migrationPlannerService,
    ProgrammeVersionImpactStore? impactStore,
  }) {
    final store = impactStore ?? const ProgrammeVersionImpactSupabaseStore();

    return ProgrammeIntelligenceController(
      versionId: versionId,
      impactService: impactService ?? ProgrammeVersionImpactService(impactStore: store),
      comparisonService:
          comparisonService ?? ProgrammeVersionComparisonService(),
      migrationPlannerService:
          migrationPlannerService ?? ProgrammeMigrationPlannerService(),
      impactStore: store,
    );
  }
}
