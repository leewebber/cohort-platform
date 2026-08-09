import '../../adaptation/vocabulary/training_environment.dart';
import '../vocabulary/exercise_relationship_type.dart';

/// Reusable facts about when a relationship might preserve intent.
///
/// Does **not** authorise a substitution in a programme. Actual permission is
/// the intersection of exercise knowledge, authored programme policy, athlete
/// circumstances, protected invariants, and athlete agreement.
class SubstitutionConstraint {
  const SubstitutionConstraint({
    this.requiredRelationshipTypes = const [],
    this.requiredEnvironments = const [],
    this.forbiddenEnvironments = const [],
    this.requiredEquipmentTokens = const [],
    this.forbiddenEquipmentTokens = const [],
    this.emergencyOrRegressionOnly = false,
    this.sportStandardRestrictionIds = const [],
    this.mustPreserveCharacteristics = const [],
    this.invalidWhenNotes,
    this.explanationRefId,
  });

  final List<ExerciseRelationshipType> requiredRelationshipTypes;
  final List<TrainingEnvironment> requiredEnvironments;
  final List<TrainingEnvironment> forbiddenEnvironments;
  final List<String> requiredEquipmentTokens;
  final List<String> forbiddenEquipmentTokens;
  final bool emergencyOrRegressionOnly;
  final List<String> sportStandardRestrictionIds;
  final List<String> mustPreserveCharacteristics;
  final String? invalidWhenNotes;
  final String? explanationRefId;

  Map<String, Object?> toJson() => {
        'required_relationship_types': requiredRelationshipTypes
            .map((t) => t.wireValue)
            .toList(growable: false),
        'required_environments':
            requiredEnvironments.map((e) => e.dbValue).toList(growable: false),
        'forbidden_environments': forbiddenEnvironments
            .map((e) => e.dbValue)
            .toList(growable: false),
        'required_equipment_tokens': requiredEquipmentTokens,
        'forbidden_equipment_tokens': forbiddenEquipmentTokens,
        'emergency_or_regression_only': emergencyOrRegressionOnly,
        'sport_standard_restriction_ids': sportStandardRestrictionIds,
        'must_preserve_characteristics': mustPreserveCharacteristics,
        if (invalidWhenNotes != null) 'invalid_when_notes': invalidWhenNotes,
        if (explanationRefId != null) 'explanation_ref_id': explanationRefId,
      };

  factory SubstitutionConstraint.fromJson(Map<String, Object?> json) {
    return SubstitutionConstraint(
      requiredRelationshipTypes: _relTypes(json['required_relationship_types']),
      requiredEnvironments: _envs(json['required_environments']),
      forbiddenEnvironments: _envs(json['forbidden_environments']),
      requiredEquipmentTokens: _strings(json['required_equipment_tokens']),
      forbiddenEquipmentTokens: _strings(json['forbidden_equipment_tokens']),
      emergencyOrRegressionOnly:
          json['emergency_or_regression_only'] == true,
      sportStandardRestrictionIds:
          _strings(json['sport_standard_restriction_ids']),
      mustPreserveCharacteristics:
          _strings(json['must_preserve_characteristics']),
      invalidWhenNotes: json['invalid_when_notes']?.toString(),
      explanationRefId: json['explanation_ref_id']?.toString(),
    );
  }
}

List<String> _strings(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList(growable: false);
}

List<TrainingEnvironment> _envs(Object? raw) {
  if (raw is! List) return const [];
  final out = <TrainingEnvironment>[];
  for (final item in raw) {
    final env = TrainingEnvironmentDb.fromDb(item?.toString());
    if (env != null) out.add(env);
  }
  return List.unmodifiable(out);
}

List<ExerciseRelationshipType> _relTypes(Object? raw) {
  if (raw is! List) return const [];
  final out = <ExerciseRelationshipType>[];
  for (final item in raw) {
    final t = ExerciseRelationshipTypeCodec.tryParse(item?.toString());
    if (t != null) out.add(t);
  }
  return List.unmodifiable(out);
}
