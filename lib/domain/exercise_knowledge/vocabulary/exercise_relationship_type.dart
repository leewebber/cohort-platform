/// Typed directional relationship between two exercise definitions.
enum ExerciseRelationshipType {
  progression,
  regression,
  lateralAlternative,
  equipmentAlternative,
  environmentAlternative,
  relatedNonComparable,
  directlyComparableVariant,
}

extension ExerciseRelationshipTypeCodec on ExerciseRelationshipType {
  String get wireValue {
    return switch (this) {
      ExerciseRelationshipType.progression => 'progression',
      ExerciseRelationshipType.regression => 'regression',
      ExerciseRelationshipType.lateralAlternative => 'lateral_alternative',
      ExerciseRelationshipType.equipmentAlternative => 'equipment_alternative',
      ExerciseRelationshipType.environmentAlternative =>
        'environment_alternative',
      ExerciseRelationshipType.relatedNonComparable =>
        'related_non_comparable',
      ExerciseRelationshipType.directlyComparableVariant =>
        'directly_comparable_variant',
    };
  }

  /// True when this relationship alone must never imply like-for-like PRs.
  bool get impliesComparabilityByDefault => false;

  /// True when an explicit comparison protocol is required if claimed comparable.
  bool get requiresExplicitComparisonProtocol =>
      this == ExerciseRelationshipType.directlyComparableVariant;

  static ExerciseRelationshipType? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase().replaceAll(' ', '_');
    for (final value in ExerciseRelationshipType.values) {
      if (value.wireValue == normalized) return value;
    }
    return null;
  }
}
