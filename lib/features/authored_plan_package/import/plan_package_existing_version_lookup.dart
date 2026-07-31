import '../../../models/programme_vocabulary.dart';
import 'plan_package_import_models.dart';

/// Read-only lookup of an existing programme version for preview collision checks.
class PlanPackageExistingVersionSnapshot {
  const PlanPackageExistingVersionSnapshot({
    required this.versionId,
    required this.lineageId,
    required this.lineageCode,
    required this.versionNumber,
    required this.lifecycleStatus,
    required this.libraryScope,
    required this.ownerType,
    required this.approvedForGlobal,
    this.ownerId,
    this.packageContentHash,
    this.packageSchemaVersion,
  });

  final String versionId;
  final String lineageId;
  final String lineageCode;
  final int versionNumber;
  final ProgrammeLifecycleStatus lifecycleStatus;
  final ProgrammeLibraryScope libraryScope;
  final ProgrammeOwnerType ownerType;
  final bool approvedForGlobal;

  /// Null for Cohort Global imports; non-null fails the SQL idempotency predicate.
  final String? ownerId;
  final String? packageContentHash;
  final int? packageSchemaVersion;

  /// Mirrors `import_authored_plan_package` idempotent / collision classification.
  ///
  /// SQL remains authoritative; preview must not report idempotent when SQL
  /// would return partial_state or another conflict.
  PlanPackageExistingImportOutcome classifyAgainstPackage({
    required String packageContentHash,
    required int packageSchemaVersion,
  }) {
    if (lifecycleStatus == ProgrammeLifecycleStatus.published) {
      return PlanPackageExistingImportOutcome.publishedConflict;
    }
    if (lifecycleStatus != ProgrammeLifecycleStatus.draft) {
      return PlanPackageExistingImportOutcome.nonDraftConflict;
    }
    if (isExactIdempotentDraft(
      packageContentHash: packageContentHash,
      packageSchemaVersion: packageSchemaVersion,
    )) {
      return PlanPackageExistingImportOutcome.idempotentSameHash;
    }
    if (this.packageContentHash != null &&
        this.packageContentHash != packageContentHash) {
      return PlanPackageExistingImportOutcome.hashCollision;
    }
    return PlanPackageExistingImportOutcome.partialDraftConflict;
  }

  bool isExactIdempotentDraft({
    required String packageContentHash,
    required int packageSchemaVersion,
  }) {
    return lifecycleStatus == ProgrammeLifecycleStatus.draft &&
        this.packageContentHash != null &&
        this.packageContentHash == packageContentHash &&
        this.packageSchemaVersion == packageSchemaVersion &&
        libraryScope == ProgrammeLibraryScope.cohortGlobal &&
        ownerType == ProgrammeOwnerType.global &&
        ownerId == null &&
        !approvedForGlobal;
  }
}

abstract class PlanPackageExistingVersionLookup {
  Future<PlanPackageExistingVersionSnapshot?> findByLineageCodeAndVersion({
    required String lineageCode,
    required int versionNumber,
  });
}
