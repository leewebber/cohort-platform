import 'plan_package_import_models.dart';

/// Persistence port for the service-role-only import RPC.
///
/// Implementations must never embed service-role credentials. A future founder
/// backend supplies an already-authorised client; Flutter clients must not call
/// this pathway.
abstract class PlanPackageImportStore {
  Future<PlanPackageImportResult> importPackage(Map<String, Object?> payload);
}

/// Persistence port for Cohort Global publish / catalogue-approval RPCs.
abstract class PlanPackageLifecycleStore {
  Future<Map<String, dynamic>> publishCohortGlobalVersion({
    required String versionId,
    required String actor,
  });

  Future<Map<String, dynamic>> approveCohortGlobalVersion({
    required String versionId,
    required String actor,
  });
}
