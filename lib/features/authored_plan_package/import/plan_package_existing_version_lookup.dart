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
    this.packageGraphMatches,
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

  /// Result of comparing the persisted package graph to the incoming package.
  ///
  /// - `true`: lookup proved complete equivalence (same gate as SQL helper)
  /// - `false`: lookup proved incompleteness / mismatch
  /// - `null`: completeness unknown — preview must not promise idempotency
  final bool? packageGraphMatches;

  /// Mirrors `import_authored_plan_package` idempotent / collision classification.
  ///
  /// SQL remains authoritative. Preview never claims exact idempotency unless
  /// [packageGraphMatches] is explicitly `true`.
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
    if (!matchesProvenance(
      packageContentHash: packageContentHash,
      packageSchemaVersion: packageSchemaVersion,
    )) {
      if (this.packageContentHash != null &&
          this.packageContentHash != packageContentHash) {
        return PlanPackageExistingImportOutcome.hashCollision;
      }
      return PlanPackageExistingImportOutcome.partialDraftConflict;
    }

    // Provenance matches. Completeness decides idempotent vs partial vs defer.
    return switch (packageGraphMatches) {
      true => PlanPackageExistingImportOutcome.idempotentSameHash,
      false => PlanPackageExistingImportOutcome.partialDraftConflict,
      null =>
        PlanPackageExistingImportOutcome.authoritativeCompletenessRequired,
    };
  }

  bool matchesProvenance({
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

  bool isExactIdempotentDraft({
    required String packageContentHash,
    required int packageSchemaVersion,
  }) {
    return matchesProvenance(
          packageContentHash: packageContentHash,
          packageSchemaVersion: packageSchemaVersion,
        ) &&
        packageGraphMatches == true;
  }
}

abstract class PlanPackageExistingVersionLookup {
  Future<PlanPackageExistingVersionSnapshot?> findByLineageCodeAndVersion({
    required String lineageCode,
    required int versionNumber,
  });
}
