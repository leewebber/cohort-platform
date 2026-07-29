import '../../athlete_profile/models/athlete_profile.dart';
import '../data/plan_catalog.dart';
import '../models/plan_assignment.dart';
import '../models/plan_definition.dart';

/// Lightweight filter state for the Plan Library.
class PlanLibraryFilters {
  const PlanLibraryFilters({
    this.goalId,
    this.equipmentPresetId,
    this.daysPerWeek,
    this.experienceLevel,
    this.maxDurationMinutes,
  });

  final String? goalId;
  final String? equipmentPresetId;
  final int? daysPerWeek;
  final AthleteExperienceLevel? experienceLevel;
  final int? maxDurationMinutes;

  bool get isEmpty =>
      goalId == null &&
      equipmentPresetId == null &&
      daysPerWeek == null &&
      experienceLevel == null &&
      maxDurationMinutes == null;

  PlanLibraryFilters copyWith({
    String? goalId,
    String? equipmentPresetId,
    int? daysPerWeek,
    AthleteExperienceLevel? experienceLevel,
    int? maxDurationMinutes,
    bool clearGoal = false,
    bool clearEquipment = false,
    bool clearDays = false,
    bool clearExperience = false,
    bool clearDuration = false,
  }) {
    return PlanLibraryFilters(
      goalId: clearGoal ? null : (goalId ?? this.goalId),
      equipmentPresetId: clearEquipment
          ? null
          : (equipmentPresetId ?? this.equipmentPresetId),
      daysPerWeek: clearDays ? null : (daysPerWeek ?? this.daysPerWeek),
      experienceLevel: clearExperience
          ? null
          : (experienceLevel ?? this.experienceLevel),
      maxDurationMinutes: clearDuration
          ? null
          : (maxDurationMinutes ?? this.maxDurationMinutes),
    );
  }

  List<PlanDefinition> apply(List<PlanDefinition> plans) {
    return plans.where((plan) {
      if (goalId != null && plan.primaryGoal.id != goalId) return false;
      if (equipmentPresetId != null &&
          !plan.equipmentPresetIds.contains(equipmentPresetId)) {
        return false;
      }
      if (daysPerWeek != null && plan.recommendedDaysPerWeek != daysPerWeek) {
        return false;
      }
      if (experienceLevel != null && plan.experienceLevel != experienceLevel) {
        return false;
      }
      if (maxDurationMinutes != null &&
          plan.typicalSessionDurationMinutes > maxDurationMinutes!) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }
}

/// In-memory plan assignment store (MVP — no persistence).
///
/// Responsibilities: assign, replace active, read active, clear active.
class PlanAssignmentService {
  PlanAssignment? _activeAssignment;
  PlanDefinition? _activeDefinition;
  final List<PlanAssignment> _history = [];

  PlanAssignment? get activeAssignment => _activeAssignment;
  PlanDefinition? get activePlan => _activeDefinition;
  bool get hasActivePlan =>
      _activeAssignment != null &&
      _activeAssignment!.isActive &&
      _activeDefinition != null;

  /// Assigns [plan] as the athlete's active plan (replaces any existing active).
  PlanAssignment assign({
    required String athleteId,
    required PlanDefinition plan,
    DateTime? now,
  }) {
    return replaceActivePlan(
      athleteId: athleteId,
      plan: plan,
      now: now,
    );
  }

  /// Replaces the current active plan with [plan]. Prior active → cancelled.
  PlanAssignment replaceActivePlan({
    required String athleteId,
    required PlanDefinition plan,
    DateTime? now,
  }) {
    final stamp = now ?? DateTime.now().toUtc();
    final previous = _activeAssignment;
    if (previous != null && previous.isActive) {
      final cancelled = previous.copyWith(
        status: PlanAssignmentStatus.cancelled,
        completedAt: stamp,
      );
      _history.add(cancelled);
    }

    final assignment = PlanAssignment(
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

    _activeAssignment = assignment;
    _activeDefinition = plan;
    return assignment;
  }

  /// Reads the active assignment, if any.
  PlanAssignment? readActiveAssignment() => _activeAssignment;

  /// Reads the active [PlanDefinition], if any.
  PlanDefinition? readActivePlan() => _activeDefinition;

  /// Clears the active plan assignment (in-memory).
  void clearActivePlan({DateTime? now}) {
    final stamp = now ?? DateTime.now().toUtc();
    final previous = _activeAssignment;
    if (previous != null && previous.isActive) {
      _history.add(
        previous.copyWith(
          status: PlanAssignmentStatus.cancelled,
          completedAt: stamp,
        ),
      );
    }
    _activeAssignment = null;
    _activeDefinition = null;
  }

  /// Updates progress cursor on the active assignment.
  PlanAssignment? updateProgress({
    String? currentPhase,
    int? currentWeek,
    int? currentDay,
  }) {
    final active = _activeAssignment;
    if (active == null || !active.isActive) return null;
    final updated = active.copyWith(
      currentPhase: currentPhase,
      currentWeek: currentWeek,
      currentDay: currentDay,
    );
    _activeAssignment = updated;
    return updated;
  }

  List<PlanAssignment> history() => List.unmodifiable(_history);

  void resetForTests() {
    _activeAssignment = null;
    _activeDefinition = null;
    _history.clear();
  }

  /// Ensures a usable [AthleteProfile] when starting a plan.
  AthleteProfile ensureProfile({
    AthleteProfile? existing,
    required PlanDefinition plan,
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
    final presetId = plan.equipmentPresetIds.isNotEmpty
        ? plan.equipmentPresetIds.first
        : 'minimal';
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
      experienceLevel: plan.experienceLevel,
      assessmentComplete: true,
      preferredTrainingStyle: plan.primaryGoal.preferenceTag,
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  PlanDefinition requirePlan(String planId) {
    final plan = PlanCatalog.byId(planId);
    if (plan == null) {
      throw StateError('Unknown plan: $planId');
    }
    return plan;
  }
}
