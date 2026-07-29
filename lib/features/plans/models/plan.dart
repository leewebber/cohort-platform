import 'package:flutter/material.dart';

import '../../athlete_profile/models/athlete_profile.dart';

/// Immutable coaching product (athlete-facing plan).
class Plan {
  const Plan({
    required this.planId,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.primaryGoal,
    required this.category,
    required this.difficulty,
    required this.recommendedDaysPerWeek,
    required this.typicalSessionDurationMinutes,
    required this.equipmentPresetIds,
    required this.experience,
    required this.whoItsFor,
    required this.whatYouImprove,
    required this.typicalWeekSummary,
    this.tags = const [],
    this.colourTheme = const Color(0xFF738864),
    this.version = '1.0.0',
    this.author = 'Cohort',
    this.status = PlanStatus.published,
    this.coverImageAsset,
    this.faqs = const [],
  });

  final String planId;
  final String name;
  final String subtitle;
  final String description;

  final AthleteGoalSelection primaryGoal;
  final PlanCategory category;
  final PlanDifficulty difficulty;

  final int recommendedDaysPerWeek;
  final int typicalSessionDurationMinutes;
  final List<String> equipmentPresetIds;
  final AthleteExperienceLevel experience;

  final String whoItsFor;
  final List<String> whatYouImprove;
  final String typicalWeekSummary;
  final List<String> tags;
  final Color colourTheme;
  final String version;
  final String author;
  final PlanStatus status;
  final String? coverImageAsset;
  final List<PlanFaq> faqs;

  String get goalLabel => primaryGoal.label;
  String get ontologyGoalId => primaryGoal.ontologyGoalId;

  String get difficultyLabel => switch (difficulty) {
    PlanDifficulty.beginner => 'Beginner',
    PlanDifficulty.intermediate => 'Intermediate',
    PlanDifficulty.advanced => 'Advanced',
  };

  String get durationLabel => '$typicalSessionDurationMinutes min';
  String get daysLabel => '$recommendedDaysPerWeek days / week';

  String get equipmentSummary {
    if (equipmentPresetIds.isEmpty) return 'Flexible';
    return equipmentPresetIds
        .map(AthleteEquipmentCatalog.byId)
        .map((p) => p.label)
        .join(' · ');
  }
}

enum PlanCategory { race, physique, strength, military, longevity, general }

enum PlanDifficulty { beginner, intermediate, advanced }

enum PlanStatus { draft, published, archived }

class PlanFaq {
  const PlanFaq({required this.question, required this.answer});

  final String question;
  final String answer;
}
