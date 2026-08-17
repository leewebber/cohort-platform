import 'plan_package_catalogue_replacement_result.dart';
import 'plan_package_import_store.dart';

/// Separate catalogue-approval gate for published Cohort Global versions.
///
/// Does not mutate authored programme content. Not callable from ordinary
/// Flutter clients with end-user credentials — requires service-role store.
class PlanPackageCatalogueApprovalService {
  const PlanPackageCatalogueApprovalService(this._lifecycleStore);

  final PlanPackageLifecycleStore _lifecycleStore;

  Future<Map<String, dynamic>> approvePublishedVersion({
    required String versionId,
    required String actor,
  }) {
    return _lifecycleStore.approveCohortGlobalVersion(
      versionId: versionId,
      actor: actor,
    );
  }

  /// Atomically retires one approved immutable version and approves its valid
  /// published replacement from the same lineage.
  Future<PlanPackageCatalogueReplacementResult> replaceApprovedVersion({
    required String retiringVersionId,
    required String replacementVersionId,
    required String actor,
  }) {
    return _lifecycleStore.replaceApprovedCohortGlobalVersion(
      retiringVersionId: retiringVersionId,
      replacementVersionId: replacementVersionId,
      actor: actor,
    );
  }
}

/// Explicit publication gate for imported Cohort Global drafts.
class PlanPackagePublicationService {
  const PlanPackagePublicationService(this._lifecycleStore);

  final PlanPackageLifecycleStore _lifecycleStore;

  Future<Map<String, dynamic>> publishDraft({
    required String versionId,
    required String actor,
  }) {
    return _lifecycleStore.publishCohortGlobalVersion(
      versionId: versionId,
      actor: actor,
    );
  }
}
