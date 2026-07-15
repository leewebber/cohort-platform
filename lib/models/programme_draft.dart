import 'programme_phase_draft.dart';
import 'programme_vocabulary.dart';
import 'programme_week_draft.dart';

/// In-memory authoring representation of a multi-week programme.
///
/// Maps to versioned programme template rows when schema lands.
/// Published snapshots are immutable; edits create a new version.
/// See `07 Documentation/41_Programme_Engine.md`.
class ProgrammeDraft {
  const ProgrammeDraft({
    required this.programmeId,
    required this.name,
    required this.version,
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
    this.approvedForGlobal = false,
    this.approvedForAdaptation = false,
    this.phases = const [],
    this.weeks = const [],
  });

  /// Stable lineage identifier across versions — e.g. `PROG-HYROX-12`.
  final String programmeId;

  final String name;

  /// Monotonic version within the programme lineage.
  final int version;

  final ProgrammeLifecycleStatus lifecycleStatus;
  final ProgrammeLibraryScope libraryScope;
  final ProgrammeOwnerType ownerType;

  /// Coach user id, organisation id, or null for global.
  final String? ownerId;

  final String? description;
  final int? durationWeeks;
  final String? targetAthlete;
  final String? difficulty;
  final String? primaryGoal;
  final String? equipmentRequirements;
  final int? sessionsPerWeek;

  /// Separate from `published` — global catalogue curation gate.
  final bool approvedForGlobal;

  /// Eligible for Decision Engine substitution pools.
  final bool approvedForAdaptation;

  /// Macro blocks; when empty, [weeks] is the flat week list.
  final List<ProgrammePhaseDraft> phases;

  /// Flat week list when programme has no phases.
  final List<ProgrammeWeekDraft> weeks;

  bool get isPublished =>
      lifecycleStatus == ProgrammeLifecycleStatus.published;

  bool get isDraft => lifecycleStatus == ProgrammeLifecycleStatus.draft;

  /// All weeks from phases plus flat weeks, sorted by week number.
  List<ProgrammeWeekDraft> get allWeeks {
    final combined = <ProgrammeWeekDraft>[
      ...weeks,
      for (final phase in phases) ...phase.weeks,
    ];

    combined.sort((left, right) => left.weekNumber.compareTo(right.weekNumber));
    return combined;
  }

  ProgrammeDraft copyWith({
    String? programmeId,
    String? name,
    int? version,
    ProgrammeLifecycleStatus? lifecycleStatus,
    ProgrammeLibraryScope? libraryScope,
    ProgrammeOwnerType? ownerType,
    String? ownerId,
    String? description,
    int? durationWeeks,
    String? targetAthlete,
    String? difficulty,
    String? primaryGoal,
    String? equipmentRequirements,
    int? sessionsPerWeek,
    bool? approvedForGlobal,
    bool? approvedForAdaptation,
    List<ProgrammePhaseDraft>? phases,
    List<ProgrammeWeekDraft>? weeks,
    bool clearOwnerId = false,
    bool clearDescription = false,
    bool clearDurationWeeks = false,
    bool clearTargetAthlete = false,
    bool clearDifficulty = false,
    bool clearPrimaryGoal = false,
    bool clearEquipmentRequirements = false,
    bool clearSessionsPerWeek = false,
  }) {
    return ProgrammeDraft(
      programmeId: programmeId ?? this.programmeId,
      name: name ?? this.name,
      version: version ?? this.version,
      lifecycleStatus: lifecycleStatus ?? this.lifecycleStatus,
      libraryScope: libraryScope ?? this.libraryScope,
      ownerType: ownerType ?? this.ownerType,
      ownerId: clearOwnerId ? null : (ownerId ?? this.ownerId),
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
      phases: phases ?? this.phases,
      weeks: weeks ?? this.weeks,
    );
  }
}
