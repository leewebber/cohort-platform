import 'package:founder_importer/models/programme_vocabulary.dart';

/// Versioned programme template row.
///
/// Draft rows are mutable; published rows are immutable snapshots.
/// See `42_Programme_Engine_Schema.md`.
class ProgrammeVersion {
  const ProgrammeVersion({
    required this.id,
    required this.lineageId,
    required this.versionNumber,
    required this.lifecycleStatus,
    required this.libraryScope,
    required this.ownerType,
    required this.name,
    this.ownerId,
    this.organisationId,
    this.createdBy,
    this.description,
    this.durationWeeks,
    this.targetAthlete,
    this.difficulty,
    this.primaryGoal,
    this.equipmentRequirements,
    this.sessionsPerWeek,
    this.approvedForGlobal = false,
    this.approvedForAdaptation = false,
    this.publishedAt,
    this.archivedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// UUID primary key.
  final String id;

  /// FK → `programme_lineages.id`.
  final String lineageId;

  final int versionNumber;
  final ProgrammeLifecycleStatus lifecycleStatus;
  final ProgrammeLibraryScope libraryScope;
  final ProgrammeOwnerType ownerType;
  final String? ownerId;
  final String? organisationId;
  final String? createdBy;
  final String name;
  final String? description;
  final int? durationWeeks;
  final String? targetAthlete;
  final String? difficulty;
  final String? primaryGoal;
  final String? equipmentRequirements;
  final int? sessionsPerWeek;
  final bool approvedForGlobal;
  final bool approvedForAdaptation;
  final DateTime? publishedAt;
  final DateTime? archivedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPublished => lifecycleStatus == ProgrammeLifecycleStatus.published;

  bool get isDraft => lifecycleStatus == ProgrammeLifecycleStatus.draft;

  bool get isAssignable => isPublished;

  factory ProgrammeVersion.fromMap(Map<String, dynamic> map) {
    return ProgrammeVersion(
      id: _trimStringRequired(map['id']),
      lineageId: _trimStringRequired(map['lineage_id']),
      versionNumber: map['version_number'] ?? 1,
      lifecycleStatus:
          ProgrammeLifecycleStatusDb.fromDb(map['lifecycle_status']?.toString()),
      libraryScope:
          ProgrammeLibraryScopeDb.fromDb(map['library_scope']?.toString()),
      ownerType: ProgrammeOwnerTypeDb.fromDb(map['owner_type']?.toString()),
      ownerId: _trimString(map['owner_id']),
      organisationId: _trimString(map['organisation_id']),
      createdBy: _trimString(map['created_by']),
      name: _trimStringRequired(map['name']),
      description: _trimString(map['description']),
      durationWeeks: _nullableInt(map['duration_weeks']),
      targetAthlete: _trimString(map['target_athlete']),
      difficulty: _trimString(map['difficulty']),
      primaryGoal: _trimString(map['primary_goal']),
      equipmentRequirements: _trimString(map['equipment_requirements']),
      sessionsPerWeek: _nullableInt(map['sessions_per_week']),
      approvedForGlobal: map['approved_for_global'] == true,
      approvedForAdaptation: map['approved_for_adaptation'] == true,
      publishedAt: _parseDateTime(map['published_at']),
      archivedAt: _parseDateTime(map['archived_at']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'lineage_id': lineageId,
      'version_number': versionNumber,
      'lifecycle_status': lifecycleStatus.dbValue,
      'library_scope': libraryScope.dbValue,
      'owner_type': ownerType.dbValue,
      if (ownerId != null) 'owner_id': ownerId,
      if (organisationId != null) 'organisation_id': organisationId,
      if (createdBy != null) 'created_by': createdBy,
      'name': name,
      if (description != null) 'description': description,
      if (durationWeeks != null) 'duration_weeks': durationWeeks,
      if (targetAthlete != null) 'target_athlete': targetAthlete,
      if (difficulty != null) 'difficulty': difficulty,
      if (primaryGoal != null) 'primary_goal': primaryGoal,
      if (equipmentRequirements != null)
        'equipment_requirements': equipmentRequirements,
      if (sessionsPerWeek != null) 'sessions_per_week': sessionsPerWeek,
      'approved_for_global': approvedForGlobal,
      'approved_for_adaptation': approvedForAdaptation,
      if (publishedAt != null) 'published_at': publishedAt!.toIso8601String(),
      if (archivedAt != null) 'archived_at': archivedAt!.toIso8601String(),
    };
  }

  ProgrammeVersion copyWith({
    String? id,
    String? lineageId,
    int? versionNumber,
    ProgrammeLifecycleStatus? lifecycleStatus,
    ProgrammeLibraryScope? libraryScope,
    ProgrammeOwnerType? ownerType,
    String? ownerId,
    String? organisationId,
    String? createdBy,
    String? name,
    String? description,
    int? durationWeeks,
    String? targetAthlete,
    String? difficulty,
    String? primaryGoal,
    String? equipmentRequirements,
    int? sessionsPerWeek,
    bool? approvedForGlobal,
    bool? approvedForAdaptation,
    DateTime? publishedAt,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearOwnerId = false,
    bool clearOrganisationId = false,
    bool clearCreatedBy = false,
    bool clearDescription = false,
    bool clearDurationWeeks = false,
    bool clearTargetAthlete = false,
    bool clearDifficulty = false,
    bool clearPrimaryGoal = false,
    bool clearEquipmentRequirements = false,
    bool clearSessionsPerWeek = false,
    bool clearPublishedAt = false,
    bool clearArchivedAt = false,
  }) {
    return ProgrammeVersion(
      id: id ?? this.id,
      lineageId: lineageId ?? this.lineageId,
      versionNumber: versionNumber ?? this.versionNumber,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      libraryScope: libraryScope ?? this.libraryScope,
      ownerType: ownerType ?? this.ownerType,
      ownerId: clearOwnerId ? null : (ownerId ?? this.ownerId),
      organisationId:
          clearOrganisationId ? null : (organisationId ?? this.organisationId),
      createdBy: clearCreatedBy ? null : (createdBy ?? this.createdBy),
      name: name ?? this.name,
      description: clearDescription ? null : (description ?? this.description),
      durationWeeks:
          clearDurationWeeks ? null : (durationWeeks ?? this.durationWeeks),
      targetAthlete:
          clearTargetAthlete ? null : (targetAthlete ?? this.targetAthlete),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      primaryGoal: clearPrimaryGoal ? null : (primaryGoal ?? this.primaryGoal),
      equipmentRequirements: clearEquipmentRequirements
          ? null
          : (equipmentRequirements ?? this.equipmentRequirements),
      sessionsPerWeek: clearSessionsPerWeek
          ? null
          : (sessionsPerWeek ?? this.sessionsPerWeek),
      approvedForGlobal: approvedForGlobal ?? this.approvedForGlobal,
      approvedForAdaptation:
          approvedForAdaptation ?? this.approvedForAdaptation,
      publishedAt: clearPublishedAt ? null : (publishedAt ?? this.publishedAt),
      archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _trimString(dynamic value) {
    if (value == null) return null;

    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _trimStringRequired(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;

    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }
}
