import '../../../models/programme_vocabulary.dart';

/// Catalogue filter for programme versions.
class ProgrammeCatalogueQuery {
  const ProgrammeCatalogueQuery({
    this.libraryScope,
    this.ownerType,
    this.ownerId,
    this.includeGlobalApprovedOnly = false,
    this.searchTerm,
    this.lifecycleStatus,
    this.primaryGoal,
  });

  final ProgrammeLibraryScope? libraryScope;
  final ProgrammeOwnerType? ownerType;
  final String? ownerId;

  /// When true, only versions with `approved_for_global = true`.
  final bool includeGlobalApprovedOnly;
  final String? searchTerm;
  final ProgrammeLifecycleStatus? lifecycleStatus;
  final String? primaryGoal;

  ProgrammeCatalogueQuery copyWith({
    ProgrammeLibraryScope? libraryScope,
    ProgrammeOwnerType? ownerType,
    String? ownerId,
    bool? includeGlobalApprovedOnly,
    String? searchTerm,
    ProgrammeLifecycleStatus? lifecycleStatus,
    String? primaryGoal,
    bool clearLibraryScope = false,
    bool clearOwnerType = false,
    bool clearOwnerId = false,
    bool clearSearchTerm = false,
    bool clearLifecycleStatus = false,
    bool clearPrimaryGoal = false,
  }) {
    return ProgrammeCatalogueQuery(
      libraryScope:
          clearLibraryScope ? null : (libraryScope ?? this.libraryScope),
      ownerType: clearOwnerType ? null : (ownerType ?? this.ownerType),
      ownerId: clearOwnerId ? null : (ownerId ?? this.ownerId),
      includeGlobalApprovedOnly:
          includeGlobalApprovedOnly ?? this.includeGlobalApprovedOnly,
      searchTerm: clearSearchTerm ? null : (searchTerm ?? this.searchTerm),
      lifecycleStatus: clearLifecycleStatus
          ? null
          : (lifecycleStatus ?? this.lifecycleStatus),
      primaryGoal:
          clearPrimaryGoal ? null : (primaryGoal ?? this.primaryGoal),
    );
  }
}

/// Summary row for catalogue and enrolment pickers.
class ProgrammeCatalogEntry {
  const ProgrammeCatalogEntry({
    required this.versionId,
    required this.lineageCode,
    required this.versionNumber,
    required this.name,
    required this.lifecycleStatus,
    required this.libraryScope,
    required this.ownerType,
    this.description,
    this.durationWeeks,
    this.difficulty,
    this.primaryGoal,
    this.sessionsPerWeek,
    this.equipmentRequirements,
    this.approvedForGlobal = false,
    this.ownerId,
    this.updatedAt,
    this.publishedAt,
    this.archivedAt,
    this.hasBlockingValidationErrors = false,
    this.ownerDisplayLabel,
  });

  final String versionId;
  final String lineageCode;
  final int versionNumber;
  final String name;
  final ProgrammeLifecycleStatus lifecycleStatus;
  final ProgrammeLibraryScope libraryScope;
  final ProgrammeOwnerType ownerType;
  final String? ownerId;
  final String? description;
  final int? durationWeeks;
  final String? difficulty;
  final String? primaryGoal;
  final int? sessionsPerWeek;
  final String? equipmentRequirements;
  final bool approvedForGlobal;
  final DateTime? updatedAt;
  final DateTime? publishedAt;
  final DateTime? archivedAt;
  final bool hasBlockingValidationErrors;
  final String? ownerDisplayLabel;

  ProgrammeCatalogEntry copyWith({
    String? versionId,
    String? lineageCode,
    int? versionNumber,
    String? name,
    ProgrammeLifecycleStatus? lifecycleStatus,
    ProgrammeLibraryScope? libraryScope,
    ProgrammeOwnerType? ownerType,
    String? ownerId,
    String? description,
    int? durationWeeks,
    String? difficulty,
    String? primaryGoal,
    int? sessionsPerWeek,
    String? equipmentRequirements,
    bool? approvedForGlobal,
    DateTime? updatedAt,
    DateTime? publishedAt,
    DateTime? archivedAt,
    bool? hasBlockingValidationErrors,
    String? ownerDisplayLabel,
  }) {
    return ProgrammeCatalogEntry(
      versionId: versionId ?? this.versionId,
      lineageCode: lineageCode ?? this.lineageCode,
      versionNumber: versionNumber ?? this.versionNumber,
      name: name ?? this.name,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      libraryScope: libraryScope ?? this.libraryScope,
      ownerType: ownerType ?? this.ownerType,
      ownerId: ownerId ?? this.ownerId,
      description: description ?? this.description,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      difficulty: difficulty ?? this.difficulty,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
      equipmentRequirements:
          equipmentRequirements ?? this.equipmentRequirements,
      approvedForGlobal: approvedForGlobal ?? this.approvedForGlobal,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      hasBlockingValidationErrors:
          hasBlockingValidationErrors ?? this.hasBlockingValidationErrors,
      ownerDisplayLabel: ownerDisplayLabel ?? this.ownerDisplayLabel,
    );
  }
}
