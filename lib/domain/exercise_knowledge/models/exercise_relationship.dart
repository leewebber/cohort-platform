import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import '../vocabulary/exercise_relationship_type.dart';
import 'substitution_constraint.dart';

/// Typed, directional relationship between two canonical exercises.
///
/// Substitution suitability does **not** imply direct comparability.
/// A [ExerciseRelationshipType.directlyComparableVariant] requires an explicit
/// [comparisonProtocolId].
class ExerciseRelationship {
  const ExerciseRelationship({
    required this.id,
    required this.sourceExerciseId,
    required this.targetExerciseId,
    required this.relationshipType,
    required this.lifecycleStatus,
    required this.version,
    this.substitutionConstraint = const SubstitutionConstraint(),
    this.comparisonProtocolId,
    this.preservesIntentNotes,
    this.explanationRefId,
    this.owner = 'founder',
    this.publishedAt,
    this.retiredAt,
  });

  final String id;
  final ExerciseId sourceExerciseId;
  final ExerciseId targetExerciseId;
  final ExerciseRelationshipType relationshipType;
  final SubstitutionConstraint substitutionConstraint;

  /// Required when [relationshipType] is [directlyComparableVariant].
  final String? comparisonProtocolId;

  final String? preservesIntentNotes;
  final String? explanationRefId;
  final ExerciseLifecycleStatus lifecycleStatus;
  final String version;
  final String owner;
  final DateTime? publishedAt;
  final DateTime? retiredAt;

  /// Dedup key: source + target + type (direction matters).
  String get uniquenessKey =>
      '${sourceExerciseId.value}>${targetExerciseId.value}:'
      '${relationshipType.wireValue}';

  bool get claimsDirectComparability =>
      relationshipType == ExerciseRelationshipType.directlyComparableVariant;

  Map<String, Object?> toJson() => {
        'id': id,
        'source_exercise_id': sourceExerciseId.value,
        'target_exercise_id': targetExerciseId.value,
        'relationship_type': relationshipType.wireValue,
        'substitution_constraint': substitutionConstraint.toJson(),
        if (comparisonProtocolId != null)
          'comparison_protocol_id': comparisonProtocolId,
        if (preservesIntentNotes != null)
          'preserves_intent_notes': preservesIntentNotes,
        if (explanationRefId != null) 'explanation_ref_id': explanationRefId,
        'lifecycle_status': lifecycleStatus.wireValue,
        'version': version,
        'owner': owner,
        if (publishedAt != null)
          'published_at': publishedAt!.toUtc().toIso8601String(),
        if (retiredAt != null)
          'retired_at': retiredAt!.toUtc().toIso8601String(),
        'uniqueness_key': uniquenessKey,
      };

  factory ExerciseRelationship.fromJson(Map<String, Object?> json) {
    return ExerciseRelationship(
      id: json['id']?.toString().trim() ?? '',
      sourceExerciseId:
          ExerciseId.parse(json['source_exercise_id']?.toString() ?? ''),
      targetExerciseId:
          ExerciseId.parse(json['target_exercise_id']?.toString() ?? ''),
      relationshipType: ExerciseRelationshipTypeCodec.tryParse(
            json['relationship_type']?.toString(),
          ) ??
          ExerciseRelationshipType.relatedNonComparable,
      substitutionConstraint: SubstitutionConstraint.fromJson(
        Map<String, Object?>.from(
          (json['substitution_constraint'] as Map?)?.cast<String, Object?>() ??
              const {},
        ),
      ),
      comparisonProtocolId: json['comparison_protocol_id']?.toString(),
      preservesIntentNotes: json['preserves_intent_notes']?.toString(),
      explanationRefId: json['explanation_ref_id']?.toString(),
      lifecycleStatus: ExerciseLifecycleStatusCodec.tryParse(
            json['lifecycle_status']?.toString(),
          ) ??
          ExerciseLifecycleStatus.draft,
      version: json['version']?.toString() ?? '1',
      owner: json['owner']?.toString() ?? 'founder',
      publishedAt: _dt(json['published_at']),
      retiredAt: _dt(json['retired_at']),
    );
  }
}

DateTime? _dt(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toUtc();
}
