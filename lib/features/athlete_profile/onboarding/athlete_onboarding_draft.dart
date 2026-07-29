import '../models/athlete_profile.dart';

enum AthleteOnboardingStep {
  welcome,
  goal,
  equipment,
  availability,
  assessment,
  generating,
}

/// Draft state for the linear onboarding wizard. Persistence-ready snapshot.
class AthleteOnboardingDraft {
  const AthleteOnboardingDraft({
    this.displayName = '',
    this.primaryGoal,
    this.selectedEquipmentPresetIds = const {},
    this.trainingDaysPerWeek = 3,
    this.preferredSessionDurationMinutes = 45,
    this.experienceLevel,
    this.currentActivity,
    this.step = AthleteOnboardingStep.welcome,
  });

  final String displayName;
  final AthleteGoalSelection? primaryGoal;
  final Set<String> selectedEquipmentPresetIds;
  final int trainingDaysPerWeek;
  final int preferredSessionDurationMinutes;
  final AthleteExperienceLevel? experienceLevel;
  final String? currentActivity;
  final AthleteOnboardingStep step;

  bool get canContinueFromWelcome => displayName.trim().length >= 2;
  bool get canContinueFromGoal => primaryGoal != null;
  bool get canContinueFromEquipment => selectedEquipmentPresetIds.isNotEmpty;
  bool get canContinueFromAvailability =>
      trainingDaysPerWeek >= 2 &&
      trainingDaysPerWeek <= 7 &&
      preferredSessionDurationMinutes >= 20;
  bool get canContinueFromAssessment => experienceLevel != null;

  AthleteOnboardingDraft copyWith({
    String? displayName,
    AthleteGoalSelection? primaryGoal,
    Set<String>? selectedEquipmentPresetIds,
    int? trainingDaysPerWeek,
    int? preferredSessionDurationMinutes,
    AthleteExperienceLevel? experienceLevel,
    String? currentActivity,
    AthleteOnboardingStep? step,
    bool clearCurrentActivity = false,
  }) {
    return AthleteOnboardingDraft(
      displayName: displayName ?? this.displayName,
      primaryGoal: primaryGoal ?? this.primaryGoal,
      selectedEquipmentPresetIds:
          selectedEquipmentPresetIds ?? this.selectedEquipmentPresetIds,
      trainingDaysPerWeek: trainingDaysPerWeek ?? this.trainingDaysPerWeek,
      preferredSessionDurationMinutes:
          preferredSessionDurationMinutes ?? this.preferredSessionDurationMinutes,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      currentActivity: clearCurrentActivity
          ? null
          : (currentActivity ?? this.currentActivity),
      step: step ?? this.step,
    );
  }

  /// Builds canonical [AthleteProfile] from completed draft.
  AthleteProfile toProfile({required String athleteId, DateTime? now}) {
    final goal = primaryGoal;
    final experience = experienceLevel;
    if (goal == null || experience == null) {
      throw StateError('Onboarding draft incomplete');
    }

    final presets = selectedEquipmentPresetIds
        .map(AthleteEquipmentCatalog.byId)
        .toList();
    final equipment = <String>{
      for (final p in presets) ...p.equipmentIds,
    }.toList()..sort();

    // Prefer gym environments when mixed with outdoor.
    final environmentId = presets.any((p) => p.id == 'commercial_gym')
        ? 'cohort.environment.commercial_gym'
        : presets.any((p) => p.id == 'home_gym' || p.id == 'minimal')
        ? 'cohort.environment.home'
        : presets.first.environmentId;

    final stamp = now ?? DateTime.now().toUtc();
    final relative = switch (experience) {
      AthleteExperienceLevel.beginner => 0.35,
      AthleteExperienceLevel.intermediate => 0.55,
      AthleteExperienceLevel.advanced => 0.75,
    };

    return AthleteProfile(
      athleteId: athleteId,
      displayName: displayName.trim(),
      primaryGoal: goal,
      availableEquipment: equipment.isEmpty
          ? const ['cohort.equipment.bodyweight']
          : equipment,
      environmentId: environmentId,
      trainingDaysPerWeek: trainingDaysPerWeek,
      preferredSessionDurationMinutes: preferredSessionDurationMinutes,
      experienceLevel: experience,
      assessmentComplete: true,
      baselineCapabilities: [
        AthleteBaselineCapability(
          capabilityId: 'cohort.capability.relative_strength',
          relativeLevel: relative,
        ),
        AthleteBaselineCapability(
          capabilityId: 'cohort.capability.aerobic_capacity',
          relativeLevel: relative,
        ),
        AthleteBaselineCapability(
          capabilityId: 'cohort.capability.work_capacity',
          relativeLevel: relative,
        ),
        AthleteBaselineCapability(
          capabilityId: 'cohort.capability.movement_competency',
          relativeLevel: relative,
        ),
      ],
      currentActivity: currentActivity?.trim().isEmpty == true
          ? null
          : currentActivity?.trim(),
      preferredTrainingStyle: goal.preferenceTag,
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  Map<String, dynamic> toPersistenceMap() => {
    'displayName': displayName,
    'primaryGoalId': primaryGoal?.id,
    'selectedEquipmentPresetIds': selectedEquipmentPresetIds.toList(),
    'trainingDaysPerWeek': trainingDaysPerWeek,
    'preferredSessionDurationMinutes': preferredSessionDurationMinutes,
    'experienceLevel': experienceLevel?.name,
    'currentActivity': currentActivity,
    'step': step.name,
  };
}
