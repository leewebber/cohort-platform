/// Canonical athlete profile — single source of truth for onboarding and planning.
///
/// Immutable. No persistence in Sprint 2; designed for later storage/sync.
class AthleteProfile {
  const AthleteProfile({
    required this.athleteId,
    required this.displayName,
    required this.primaryGoal,
    this.secondaryGoal,
    required this.availableEquipment,
    required this.environmentId,
    required this.trainingDaysPerWeek,
    required this.preferredSessionDurationMinutes,
    required this.experienceLevel,
    required this.assessmentComplete,
    this.baselineCapabilities = const [],
    this.currentActivity,
    this.preferredTrainingStyle,
    this.injuries = const [],
    this.constraints = const [],
    required this.createdAt,
    required this.updatedAt,
    this.onboardingVersion = AthleteProfile.onboardingVersionV1,
  });

  static const onboardingVersionV1 = 'athlete_onboarding_v1';

  final String athleteId;
  final String displayName;

  /// Athlete-facing goal choice (may map to ontology goal).
  final AthleteGoalSelection primaryGoal;
  final AthleteGoalSelection? secondaryGoal;

  final List<String> availableEquipment;
  final String environmentId;

  final int trainingDaysPerWeek;
  final int preferredSessionDurationMinutes;

  final AthleteExperienceLevel experienceLevel;
  final bool assessmentComplete;
  final List<AthleteBaselineCapability> baselineCapabilities;
  final String? currentActivity;

  final String? preferredTrainingStyle;
  final List<String> injuries;
  final List<String> constraints;

  final DateTime createdAt;
  final DateTime updatedAt;
  final String onboardingVersion;

  /// Ontology goal id for [PlanningInput] (never invented beyond knowledge map).
  String get planningGoalId => primaryGoal.ontologyGoalId;

  String get planningGoalLabel => primaryGoal.label;

  AthleteProfile copyWith({
    String? displayName,
    AthleteGoalSelection? primaryGoal,
    AthleteGoalSelection? secondaryGoal,
    List<String>? availableEquipment,
    String? environmentId,
    int? trainingDaysPerWeek,
    int? preferredSessionDurationMinutes,
    AthleteExperienceLevel? experienceLevel,
    bool? assessmentComplete,
    List<AthleteBaselineCapability>? baselineCapabilities,
    String? currentActivity,
    String? preferredTrainingStyle,
    List<String>? injuries,
    List<String>? constraints,
    DateTime? updatedAt,
  }) {
    return AthleteProfile(
      athleteId: athleteId,
      displayName: displayName ?? this.displayName,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      secondaryGoal: secondaryGoal ?? this.secondaryGoal,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      environmentId: environmentId ?? this.environmentId,
      trainingDaysPerWeek: trainingDaysPerWeek ?? this.trainingDaysPerWeek,
      preferredSessionDurationMinutes:
          preferredSessionDurationMinutes ?? this.preferredSessionDurationMinutes,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      assessmentComplete: assessmentComplete ?? this.assessmentComplete,
      baselineCapabilities: baselineCapabilities ?? this.baselineCapabilities,
      currentActivity: currentActivity ?? this.currentActivity,
      preferredTrainingStyle:
          preferredTrainingStyle ?? this.preferredTrainingStyle,
      injuries: injuries ?? this.injuries,
      constraints: constraints ?? this.constraints,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      onboardingVersion: onboardingVersion,
    );
  }

  Map<String, dynamic> toPersistenceMap() {
    return {
      'athleteId': athleteId,
      'displayName': displayName,
      'primaryGoalId': primaryGoal.id,
      'secondaryGoalId': secondaryGoal?.id,
      'availableEquipment': availableEquipment,
      'environmentId': environmentId,
      'trainingDaysPerWeek': trainingDaysPerWeek,
      'preferredSessionDurationMinutes': preferredSessionDurationMinutes,
      'experienceLevel': experienceLevel.name,
      'assessmentComplete': assessmentComplete,
      'baselineCapabilities': baselineCapabilities
          .map((c) => c.toPersistenceMap())
          .toList(),
      'currentActivity': currentActivity,
      'preferredTrainingStyle': preferredTrainingStyle,
      'injuries': injuries,
      'constraints': constraints,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'onboardingVersion': onboardingVersion,
    };
  }

  /// Restores from [toPersistenceMap] payload. Throws on invalid shape.
  factory AthleteProfile.fromPersistenceMap(Map<String, dynamic> map) {
    final primaryId = map['primaryGoalId']?.toString();
    if (primaryId == null || primaryId.isEmpty) {
      throw const FormatException('Missing primaryGoalId');
    }
    final primary = AthleteGoalCatalog.byId(primaryId);
    final secondaryId = map['secondaryGoalId']?.toString();
    final secondary = secondaryId == null || secondaryId.isEmpty
        ? null
        : AthleteGoalCatalog.byId(secondaryId);

    final experienceName = map['experienceLevel']?.toString() ?? 'beginner';
    final experience = AthleteExperienceLevel.values.firstWhere(
      (e) => e.name == experienceName,
      orElse: () => AthleteExperienceLevel.beginner,
    );

    final baselinesRaw = map['baselineCapabilities'];
    final baselines = <AthleteBaselineCapability>[];
    if (baselinesRaw is List) {
      for (final item in baselinesRaw) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          baselines.add(
            AthleteBaselineCapability(
              capabilityId: m['capabilityId']?.toString() ?? '',
              relativeLevel: (m['relativeLevel'] as num?)?.toDouble() ?? 0,
            ),
          );
        }
      }
    }

    DateTime parseRequired(String key) {
      final raw = map[key]?.toString();
      final parsed = raw == null ? null : DateTime.tryParse(raw);
      if (parsed == null) {
        throw FormatException('Invalid $key');
      }
      return parsed.toUtc();
    }

    return AthleteProfile(
      athleteId: map['athleteId']?.toString() ?? '',
      displayName: map['displayName']?.toString() ?? 'Athlete',
      primaryGoal: primary,
      secondaryGoal: secondary,
      availableEquipment: (map['availableEquipment'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      environmentId: map['environmentId']?.toString() ?? 'gym',
      trainingDaysPerWeek: (map['trainingDaysPerWeek'] as num?)?.toInt() ?? 3,
      preferredSessionDurationMinutes:
          (map['preferredSessionDurationMinutes'] as num?)?.toInt() ?? 45,
      experienceLevel: experience,
      assessmentComplete: map['assessmentComplete'] == true,
      baselineCapabilities: baselines,
      currentActivity: map['currentActivity']?.toString(),
      preferredTrainingStyle: map['preferredTrainingStyle']?.toString(),
      injuries: (map['injuries'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      constraints: (map['constraints'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      createdAt: parseRequired('createdAt'),
      updatedAt: parseRequired('updatedAt'),
      onboardingVersion:
          map['onboardingVersion']?.toString() ?? onboardingVersionV1,
    );
  }
}

enum AthleteExperienceLevel { beginner, intermediate, advanced }

class AthleteBaselineCapability {
  const AthleteBaselineCapability({
    required this.capabilityId,
    required this.relativeLevel,
  });

  final String capabilityId;

  /// 0.0–1.0 self-reported relative level (mapped to evidence confidence).
  final double relativeLevel;

  Map<String, dynamic> toPersistenceMap() => {
    'capabilityId': capabilityId,
    'relativeLevel': relativeLevel,
  };
}

/// Curated athlete goal. UI choice + ontology mapping (ADR: knowledge is source of truth).
class AthleteGoalSelection {
  const AthleteGoalSelection({
    required this.id,
    required this.label,
    required this.description,
    required this.ontologyGoalId,
    this.preferenceTag,
  });

  final String id;
  final String label;
  final String description;

  /// Must exist in knowledge `goal_requirements.yaml`.
  final String ontologyGoalId;

  /// Optional preference when multiple UI goals share one ontology goal.
  final String? preferenceTag;
}

/// Catalog of onboarding goals. Only ontology-backed goal ids are used for planning.
class AthleteGoalCatalog {
  const AthleteGoalCatalog._();

  static const List<AthleteGoalSelection> options = [
    AthleteGoalSelection(
      id: 'hyrox',
      label: 'HYROX',
      description: 'Race-ready engine, stations, and pacing under fatigue.',
      ontologyGoalId: 'cohort.goal.hyrox_sub_60',
    ),
    AthleteGoalSelection(
      id: 'general_fitness',
      label: 'General Fitness',
      description: 'Balanced strength, capacity, and movement for everyday life.',
      ontologyGoalId: 'cohort.goal.general_fat_loss',
      preferenceTag: 'general_fitness',
    ),
    AthleteGoalSelection(
      id: 'fat_loss',
      label: 'Fat Loss',
      description: 'Sustainable conditioning with strength that protects progress.',
      ontologyGoalId: 'cohort.goal.general_fat_loss',
    ),
    AthleteGoalSelection(
      id: 'strength',
      label: 'Strength',
      description: 'Build resilient force with clean movement quality.',
      ontologyGoalId: 'cohort.goal.general_fat_loss',
      preferenceTag: 'strength_emphasis',
    ),
    AthleteGoalSelection(
      id: 'military',
      label: 'Military Preparation',
      description: 'Selection-ready strength, carry capacity, and aerobic base.',
      ontologyGoalId: 'cohort.goal.military_selection',
    ),
    AthleteGoalSelection(
      id: 'longevity',
      label: 'Longevity',
      description: 'Train for decades — capacity, strength, and recovery balance.',
      ontologyGoalId: 'cohort.goal.general_fat_loss',
      preferenceTag: 'longevity',
    ),
  ];

  static AthleteGoalSelection byId(String id) {
    return options.firstWhere(
      (o) => o.id == id,
      orElse: () => options.firstWhere((o) => o.id == 'fat_loss'),
    );
  }
}

/// Equipment / environment presets for onboarding (maps to knowledge ids).
class AthleteEquipmentPreset {
  const AthleteEquipmentPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.equipmentIds,
    required this.environmentId,
  });

  final String id;
  final String label;
  final String description;
  final List<String> equipmentIds;
  final String environmentId;
}

class AthleteEquipmentCatalog {
  const AthleteEquipmentCatalog._();

  static const List<AthleteEquipmentPreset> options = [
    AthleteEquipmentPreset(
      id: 'commercial_gym',
      label: 'Commercial Gym',
      description: 'Full racks, free weights, and machines.',
      equipmentIds: [
        'cohort.equipment.barbell',
        'cohort.equipment.squat_rack',
        'cohort.equipment.dumbbell',
        'cohort.equipment.kettlebell',
        'cohort.equipment.bench',
        'cohort.equipment.cable_machine',
        'cohort.equipment.pull_up_bar',
        'cohort.equipment.bodyweight',
      ],
      environmentId: 'cohort.environment.commercial_gym',
    ),
    AthleteEquipmentPreset(
      id: 'home_gym',
      label: 'Home Gym',
      description: 'Dumbbells, kettlebells, and bodyweight staples.',
      equipmentIds: [
        'cohort.equipment.dumbbell',
        'cohort.equipment.kettlebell',
        'cohort.equipment.pull_up_bar',
        'cohort.equipment.bodyweight',
      ],
      environmentId: 'cohort.environment.home',
    ),
    AthleteEquipmentPreset(
      id: 'minimal',
      label: 'Minimal Equipment',
      description: 'Bodyweight-first with light free weights if available.',
      equipmentIds: [
        'cohort.equipment.bodyweight',
        'cohort.equipment.dumbbell',
      ],
      environmentId: 'cohort.environment.home',
    ),
    AthleteEquipmentPreset(
      id: 'running',
      label: 'Running',
      description: 'Outdoor or road running emphasis.',
      equipmentIds: ['cohort.equipment.bodyweight'],
      environmentId: 'cohort.environment.outdoors',
    ),
    AthleteEquipmentPreset(
      id: 'pool',
      label: 'Pool',
      description: 'Swim-friendly environment (land training still applies).',
      equipmentIds: ['cohort.equipment.bodyweight'],
      environmentId: 'cohort.environment.outdoors',
    ),
    AthleteEquipmentPreset(
      id: 'outdoor',
      label: 'Outdoor Space',
      description: 'Parks, trails, and open-air training.',
      equipmentIds: [
        'cohort.equipment.bodyweight',
        'cohort.equipment.kettlebell',
      ],
      environmentId: 'cohort.environment.outdoors',
    ),
  ];

  static AthleteEquipmentPreset byId(String id) {
    return options.firstWhere(
      (o) => o.id == id,
      orElse: () => options.first,
    );
  }
}
