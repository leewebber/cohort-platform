import 'package:founder_importer/models/programme_vocabulary.dart';

/// Version-level authoring metadata for [ProgrammeBuilderDocument].
///
/// Mirrors `programme_versions` without persistence maps in the UI layer.
/// See `44_Programme_Builder.md`.
class ProgrammeVersionDraftMetadata {
  const ProgrammeVersionDraftMetadata({
    required this.lineageCode,
    required this.versionNumber,
    required this.name,
    this.versionId,
    this.lineageId,
    this.lifecycleStatus = ProgrammeLifecycleStatus.draft,
    this.libraryScope = ProgrammeLibraryScope.coachPrivate,
    this.ownerType = ProgrammeOwnerType.coach,
    this.ownerId,
    this.description,
    this.durationWeeks,
    this.targetAthlete,
    this.difficulty,
    this.primaryGoal,
    this.equipmentRequirements,
    this.sessionsPerWeek,
    this.updatedAt,
  });

  final String? versionId;
  final String? lineageId;
  final String lineageCode;
  final int versionNumber;
  final ProgrammeLifecycleStatus lifecycleStatus;
  final ProgrammeLibraryScope libraryScope;
  final ProgrammeOwnerType ownerType;
  final String? ownerId;
  final String name;
  final String? description;
  final int? durationWeeks;
  final String? targetAthlete;
  final String? difficulty;
  final String? primaryGoal;
  final String? equipmentRequirements;
  final int? sessionsPerWeek;
  final DateTime? updatedAt;

  bool get isPersisted => versionId != null && versionId!.isNotEmpty;

  bool get isEditable => lifecycleStatus == ProgrammeLifecycleStatus.draft;

  ProgrammeVersionDraftMetadata copyWith({
    String? versionId,
    String? lineageId,
    String? lineageCode,
    int? versionNumber,
    ProgrammeLifecycleStatus? lifecycleStatus,
    ProgrammeLibraryScope? libraryScope,
    ProgrammeOwnerType? ownerType,
    String? ownerId,
    String? name,
    String? description,
    int? durationWeeks,
    String? targetAthlete,
    String? difficulty,
    String? primaryGoal,
    String? equipmentRequirements,
    int? sessionsPerWeek,
    DateTime? updatedAt,
    bool clearVersionId = false,
    bool clearLineageId = false,
    bool clearOwnerId = false,
    bool clearDescription = false,
    bool clearDurationWeeks = false,
    bool clearTargetAthlete = false,
    bool clearDifficulty = false,
    bool clearPrimaryGoal = false,
    bool clearEquipmentRequirements = false,
    bool clearSessionsPerWeek = false,
    bool clearUpdatedAt = false,
  }) {
    return ProgrammeVersionDraftMetadata(
      versionId: clearVersionId ? null : (versionId ?? this.versionId),
      lineageId: clearLineageId ? null : (lineageId ?? this.lineageId),
      lineageCode: lineageCode ?? this.lineageCode,
      versionNumber: versionNumber ?? this.versionNumber,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      libraryScope: libraryScope ?? this.libraryScope,
      ownerType: ownerType ?? this.ownerType,
      ownerId: clearOwnerId ? null : (ownerId ?? this.ownerId),
      name: name ?? this.name,
      description:
          clearDescription ? null : (description ?? this.description),
      durationWeeks:
          clearDurationWeeks ? null : (durationWeeks ?? this.durationWeeks),
      targetAthlete:
          clearTargetAthlete ? null : (targetAthlete ?? this.targetAthlete),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      primaryGoal:
          clearPrimaryGoal ? null : (primaryGoal ?? this.primaryGoal),
      equipmentRequirements: clearEquipmentRequirements
          ? null
          : (equipmentRequirements ?? this.equipmentRequirements),
      sessionsPerWeek: clearSessionsPerWeek
          ? null
          : (sessionsPerWeek ?? this.sessionsPerWeek),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }
}
