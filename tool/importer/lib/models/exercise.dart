class Exercise {
  final String exerciseId;
  final String name;
  final String? slug;
  final bool published;

  final String? category;
  final String? movementPattern;
  final String? movementPlane;
  final String? exerciseType;
  final String? bodyRegion;
  final String? equipment;
  final String? equipmentCategory;
  final String? environment;
  final String? technicalComplexity;
  final String? primaryMuscles;
  final String? secondaryMuscleGroups;
  final String? primaryCapability;

  final String? purpose;
  final String? setup;
  final String? execution;
  final String? coachingCues;
  final String? commonMistakes;
  final String? breathingNotes;
  final String? safetyNotes;
  final String? regression;
  final String? progression;
  final String? scalingNotes;

  final String? bestUsedFor;
  final String? loadingOptions;
  final String? repRangeGuidance;
  final String? tempoGuidance;
  final String? restGuidance;

  final String? videoUrl;
  final String? imageUrl;

  const Exercise({
    required this.exerciseId,
    required this.name,
    required this.published,
    this.slug,
    this.category,
    this.movementPattern,
    this.movementPlane,
    this.exerciseType,
    this.bodyRegion,
    this.equipment,
    this.equipmentCategory,
    this.environment,
    this.technicalComplexity,
    this.primaryMuscles,
    this.secondaryMuscleGroups,
    this.primaryCapability,
    this.purpose,
    this.setup,
    this.execution,
    this.coachingCues,
    this.commonMistakes,
    this.breathingNotes,
    this.safetyNotes,
    this.regression,
    this.progression,
    this.scalingNotes,
    this.bestUsedFor,
    this.loadingOptions,
    this.repRangeGuidance,
    this.tempoGuidance,
    this.restGuidance,
    this.videoUrl,
    this.imageUrl,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      exerciseId: map['exercise_id'] ?? '',
      name: map['name'] ?? '',
      slug: map['slug'],
      published: map['published'] == true,
      category: map['category'],
      movementPattern: map['movement_pattern'],
      movementPlane: map['movement_plane'],
      exerciseType: map['exercise_type'],
      bodyRegion: map['body_region'],
      equipment: map['equipment'],
      equipmentCategory: map['equipment_category'],
      environment: map['environment'],
      technicalComplexity: map['technical_complexity'],
      primaryMuscles: map['primary_muscles'],
      secondaryMuscleGroups: map['secondary_muscle_groups'],
      primaryCapability: map['primary_capability'],
      purpose: map['purpose'],
      setup: map['setup'],
      execution: map['execution'],
      coachingCues: map['coaching_cues'],
      commonMistakes: map['common_mistakes'],
      breathingNotes: map['breathing_notes'],
      safetyNotes: map['safety_notes'],
      regression: map['regression'],
      progression: map['progression'],
      scalingNotes: map['scaling_notes'],
      bestUsedFor: map['best_used_for'],
      loadingOptions: map['loading_options'],
      repRangeGuidance: map['rep_range_guidance'],
      tempoGuidance: map['tempo_guidance'],
      restGuidance: map['rest_guidance'],
      videoUrl: map['video_url'],
      imageUrl: map['image_url'],
    );
  }
}