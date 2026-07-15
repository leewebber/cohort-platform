import '../../../models/programme_vocabulary.dart';

/// Catalogue filter for published programme versions.
class ProgrammeCatalogueQuery {
  const ProgrammeCatalogueQuery({
    this.libraryScope,
    this.ownerType,
    this.ownerId,
    this.includeGlobalApprovedOnly = false,
    this.searchTerm,
  });

  final ProgrammeLibraryScope? libraryScope;
  final ProgrammeOwnerType? ownerType;
  final String? ownerId;

  /// When true, only versions with `approved_for_global = true`.
  final bool includeGlobalApprovedOnly;
  final String? searchTerm;
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
    this.approvedForGlobal = false,
    this.ownerId,
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
  final bool approvedForGlobal;
}
