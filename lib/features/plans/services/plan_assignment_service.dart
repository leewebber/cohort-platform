import '../../athlete_profile/models/athlete_profile.dart';
import '../data/plan_catalog.dart';
import '../models/plan.dart';
import '../models/plan_assignment.dart';

/// Lightweight filter state for the Plan Library.
class PlanLibraryFilters {
  const PlanLibraryFilters({
    this.goalId,
    this.equipmentPresetId,
    this.daysPerWeek,
    this.difficulty,
    this.maxDurationMinutes,
  });

  final String? goalId;
  final String? equipmentPresetId;
  final int? daysPerWeek;
  final PlanDifficulty? difficulty;
  final int? maxDurationMinutes;

  bool get isEmpty =>
      goalId == null &&
      equipmentPresetId == null &&
      daysPerWeek == null &&
      difficulty == null &&
      maxDurationMinutes == null;

  PlanLibraryFilters copyWith({
    String? goalId,
    String? equipmentPresetId,
    int? daysPerWeek,
    PlanDifficulty? difficulty,
    int? maxDurationMinutes,
    bool clearGoal = false,
    bool clearEquipment = false,
    bool clearDays = false,
    bool clearDifficulty = false,
    bool clearDuration = false,
  }) {
    return PlanLibraryFilters(
      goalId: clearGoal ? null : (goalId ?? this.goalId),
      equipmentPresetId: clearEquipment
          ? null
          : (equipmentPresetId ?? this.equipmentPresetId),
      daysPerWeek: clearDays ? null : (daysPerWeek ?? this.daysPerWeek),
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      maxDurationMinutes: clearDuration
          ? null
          : (maxDurationMinutes ?? this.maxDurationMinutes),
    );
  }

  List<Plan> apply(List<Plan> plans) {
    return plans.where((plan) {
      if (goalId != null && plan.primaryGoal.id != goalId) return false;
      if (equipmentPresetId != null &&
          !plan.equipmentPresetIds.contains(equipmentPresetId)) {
        return false;
      }
      if (daysPerWeek != null && plan.recommendedDaysPerWeek != daysPerWeek) {
        return false;
      }
      if (difficulty != null && plan.difficulty != difficulty) return false;
      if (maxDurationMinutes != null &&
          plan.typicalSessionDurationMinutes > maxDurationMinutes!) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }
}

/// Creates and activates plan assignments (in-memory MVP).
class PlanAssignmentService {
  PlanAssignment assign({
    required String athleteId,
    required Plan plan,
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now().toUtc();
    return PlanAssignment(
      assignmentId: 'assignment.$athleteId.${plan.planId}.$stamp',
      athleteId: athleteId,
      planId: plan.planId,
      assignedAt: stamp,
      startedAt: stamp,
      currentPhase: 'Foundation',
      currentWeek: 1,
      currentDay: 1,
      status: PlanAssignmentStatus.active,
    );
  }

  /// Ensures a usable [AthleteProfile] when starting a plan.
  AthleteProfile ensureProfile({
    AthleteProfile? existing,
    required Plan plan,
    required String athleteId,
    String? displayName,
    DateTime? now,
  }) {
    if (existing != null) {
      return existing.copyWith(
        primaryGoal: plan.primaryGoal,
        trainingDaysPerWeek: plan.recommendedDaysPerWeek,
        preferredSessionDurationMinutes: plan.typicalSessionDurationMinutes,
        preferredTrainingStyle: plan.primaryGoal.preferenceTag,
        updatedAt: now ?? DateTime.now().toUtc(),
      );
    }

    final stamp = now ?? DateTime.now().toUtc();
    final presetId = plan.equipmentPresetIds.first;
    final preset = AthleteEquipmentCatalog.byId(presetId);
    return AthleteProfile(
      athleteId: athleteId,
      displayName: (displayName == null || displayName.trim().isEmpty)
          ? 'Athlete'
          : displayName.trim(),
      primaryGoal: plan.primaryGoal,
      availableEquipment: preset.equipmentIds,
      environmentId: preset.environmentId,
      trainingDaysPerWeek: plan.recommendedDaysPerWeek,
      preferredSessionDurationMinutes: plan.typicalSessionDurationMinutes,
      experienceLevel: plan.experience,
      assessmentComplete: true,
      preferredTrainingStyle: plan.primaryGoal.preferenceTag,
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  Plan requirePlan(String planId) {
    final plan = PlanCatalog.byId(planId);
    if (plan == null) {
      throw StateError('Unknown plan: $planId');
    }
    return plan;
  }
}
