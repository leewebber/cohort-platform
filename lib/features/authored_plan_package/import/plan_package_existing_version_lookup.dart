import '../../../models/programme_vocabulary.dart';

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
  final String? packageContentHash;
  final int? packageSchemaVersion;
}

abstract class PlanPackageExistingVersionLookup {
  Future<PlanPackageExistingVersionSnapshot?> findByLineageCodeAndVersion({
    required String lineageCode,
    required int versionNumber,
  });
}
