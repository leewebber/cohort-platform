import '../../../models/programme_vocabulary.dart';
import '../plan_package_validation_issue.dart';

/// Side-effect-free import preview for a validated Plan Package compile result.
class PlanPackageImportPreview {
  const PlanPackageImportPreview({
    required this.lineageCode,
    required this.versionNumber,
    required this.packageSchemaVersion,
    required this.packageContentHash,
    required this.programmeName,
    required this.coachingIntent,
    required this.libraryScope,
    required this.ownerType,
    required this.lifecycleStatus,
    required this.approvedForGlobal,
    required this.phaseCount,
    required this.weekCount,
    required this.dayCount,
    required this.slotCount,
    required this.sessionRevisions,
    required this.adaptationPermissionIds,
    required this.protectedInvariantIds,
    required this.assessmentIds,
    required this.evidenceRequirementIds,
    required this.comparisonIdentityIds,
    required this.blockingErrors,
    required this.warnings,
    this.description,
    this.existingOutcome,
  });

  final String lineageCode;
  final int versionNumber;
  final int packageSchemaVersion;
  final String packageContentHash;
  final String programmeName;
  final String? description;
  final String coachingIntent;
  final ProgrammeLibraryScope libraryScope;
  final ProgrammeOwnerType ownerType;
  final ProgrammeLifecycleStatus lifecycleStatus;
  final bool approvedForGlobal;
  final int phaseCount;
  final int weekCount;
  final int dayCount;
  final int slotCount;
  final List<PlanPackageResolvedSessionRevision> sessionRevisions;
  final List<String> adaptationPermissionIds;
  final List<String> protectedInvariantIds;
  final List<String> assessmentIds;
  final List<String> evidenceRequirementIds;
  final List<String> comparisonIdentityIds;
  final List<PlanPackageValidationIssue> blockingErrors;
  final List<PlanPackageValidationIssue> warnings;
  final PlanPackageExistingImportOutcome? existingOutcome;

  bool get isImportable =>
      blockingErrors.isEmpty &&
      (existingOutcome == null ||
          existingOutcome ==
              PlanPackageExistingImportOutcome.idempotentSameHash ||
          existingOutcome ==
              PlanPackageExistingImportOutcome
                  .authoritativeCompletenessRequired);
}

enum PlanPackageExistingImportOutcome {
  idempotentSameHash,
  hashCollision,
  publishedConflict,
  partialDraftConflict,
  nonDraftConflict,

  /// Provenance matches but preview cannot prove package-graph completeness.
  /// Importable; SQL performs the authoritative completeness gate.
  authoritativeCompletenessRequired,
}

class PlanPackageResolvedSessionRevision {
  const PlanPackageResolvedSessionRevision({
    required this.sessionKey,
    required this.protocolId,
    required this.sessionLineageId,
    required this.revisionNumber,
    required this.title,
    required this.resolved,
    this.failureCode,
    this.failureMessage,
  });

  final String sessionKey;
  final String protocolId;
  final String sessionLineageId;
  final int revisionNumber;
  final String title;
  final bool resolved;
  final String? failureCode;
  final String? failureMessage;
}

/// Structured import application result variants.
enum PlanPackageImportStatus {
  importedDraft,
  idempotentExistingDraft,
  versionCollision,
  publishedVersionConflict,
  partialStateConflict,
  sessionResolutionFailure,
  validationFailure,
  authorizationFailure,
  databaseFailure,
}

class PlanPackageImportResult {
  const PlanPackageImportResult({
    required this.status,
    required this.code,
    this.message,
    this.programmeVersionId,
    this.lineageId,
    this.lineageCode,
    this.versionNumber,
    this.packageContentHash,
    this.lifecycleStatus,
    this.approvedForGlobal,
  });

  final PlanPackageImportStatus status;
  final String code;
  final String? message;
  final String? programmeVersionId;
  final String? lineageId;
  final String? lineageCode;
  final int? versionNumber;
  final String? packageContentHash;
  final String? lifecycleStatus;
  final bool? approvedForGlobal;

  bool get isSuccess =>
      status == PlanPackageImportStatus.importedDraft ||
      status == PlanPackageImportStatus.idempotentExistingDraft;

  factory PlanPackageImportResult.fromRpcMap(Map<String, dynamic> map) {
    final statusRaw = map['status']?.toString() ?? 'database_failure';
    final status = switch (statusRaw) {
      'imported_draft' => PlanPackageImportStatus.importedDraft,
      'idempotent_existing_draft' =>
        PlanPackageImportStatus.idempotentExistingDraft,
      'version_collision' => PlanPackageImportStatus.versionCollision,
      'published_version_conflict' =>
        PlanPackageImportStatus.publishedVersionConflict,
      'partial_state_conflict' => PlanPackageImportStatus.partialStateConflict,
      'session_resolution_failure' =>
        PlanPackageImportStatus.sessionResolutionFailure,
      'validation_failure' => PlanPackageImportStatus.validationFailure,
      'authorization_failure' => PlanPackageImportStatus.authorizationFailure,
      _ => PlanPackageImportStatus.databaseFailure,
    };

    return PlanPackageImportResult(
      status: status,
      code: map['code']?.toString() ?? statusRaw,
      message: map['message']?.toString(),
      programmeVersionId: map['programme_version_id']?.toString(),
      lineageId: map['lineage_id']?.toString(),
      lineageCode: map['lineage_code']?.toString(),
      versionNumber: map['version_number'] is int
          ? map['version_number'] as int
          : int.tryParse('${map['version_number']}'),
      packageContentHash: map['package_content_hash']?.toString(),
      lifecycleStatus: map['lifecycle_status']?.toString(),
      approvedForGlobal: map['approved_for_global'] == true,
    );
  }
}

/// Lookup row used by the session-resolution port (read-only).
class PlanPackageSessionRevisionRecord {
  const PlanPackageSessionRevisionRecord({
    required this.protocolId,
    required this.sessionLineageId,
    required this.revisionNumber,
    required this.lifecycleStatus,
    this.contentKind,
    this.name,
  });

  final String protocolId;
  final String sessionLineageId;
  final int revisionNumber;
  final String lifecycleStatus;
  final String? contentKind;
  final String? name;
}
