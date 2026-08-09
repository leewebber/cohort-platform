import '../../adaptation/vocabulary/movement_pattern.dart';
import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_impact_level.dart';
import '../vocabulary/exercise_laterality.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import '../vocabulary/exercise_modality.dart';
import '../vocabulary/exercise_technical_complexity.dart';
import '../vocabulary/performance_dimension.dart';
import 'equipment_requirement.dart';
import 'environment_suitability.dart';
import 'knowledge_reference.dart';

/// Reusable definition of a movement or activity.
///
/// Owns identity, classification, equipment/environment suitability, valid
/// dimensions, and references. Does **not** store sets, reps, load, tempo,
/// rest, scheduling, session position, or athlete-entered results.
class ExerciseDefinition {
  const ExerciseDefinition({
    required this.id,
    required this.canonicalName,
    required this.modality,
    required this.lifecycleStatus,
    required this.version,
    this.aliases = const [],
    this.familyId,
    this.movementPatterns = const [],
    this.laterality = ExerciseLaterality.notApplicable,
    this.technicalComplexity = ExerciseTechnicalComplexity.unknown,
    this.impactLevel = ExerciseImpactLevel.unknown,
    this.validPrescriptionDimensions = const [],
    this.validCompletedPerformanceDimensions = const [],
    this.equipment = const EquipmentRequirement(),
    this.environments = const EnvironmentSuitability(),
    this.coachingContentRefs = const [],
    this.mediaRefs = const [],
    this.movementStandardRefs = const [],
    this.sportStandardRefs = const [],
    this.transitionalAliasIds = const [],
    this.owner = 'founder',
    this.publishedAt,
    this.retiredAt,
  });

  final ExerciseId id;
  final String canonicalName;
  final List<String> aliases;
  final ExerciseModality modality;
  final String? familyId;
  final List<MovementPattern> movementPatterns;
  final ExerciseLaterality laterality;
  final ExerciseTechnicalComplexity technicalComplexity;
  final ExerciseImpactLevel impactLevel;
  final List<PerformanceDimension> validPrescriptionDimensions;
  final List<PerformanceDimension> validCompletedPerformanceDimensions;
  final EquipmentRequirement equipment;
  final EnvironmentSuitability environments;
  final List<CoachingContentRef> coachingContentRefs;
  final List<MediaReference> mediaRefs;
  final List<MovementStandardRef> movementStandardRefs;
  final List<SportStandardRef> sportStandardRefs;

  /// Transitional `cohort.exercise.*` aliases — never canonical.
  final List<String> transitionalAliasIds;

  final ExerciseLifecycleStatus lifecycleStatus;
  final String version;
  final String owner;
  final DateTime? publishedAt;
  final DateTime? retiredAt;

  Map<String, Object?> toJson() => {
        'id': id.value,
        'canonical_name': canonicalName,
        'aliases': aliases,
        'modality': modality.wireValue,
        if (familyId != null) 'family_id': familyId,
        'movement_patterns':
            movementPatterns.map((p) => p.dbValue).toList(growable: false),
        'laterality': laterality.wireValue,
        'technical_complexity': technicalComplexity.wireValue,
        'impact_level': impactLevel.wireValue,
        'valid_prescription_dimensions': validPrescriptionDimensions
            .map((d) => d.wireValue)
            .toList(growable: false),
        'valid_completed_performance_dimensions':
            validCompletedPerformanceDimensions
                .map((d) => d.wireValue)
                .toList(growable: false),
        'equipment': equipment.toJson(),
        'environments': environments.toJson(),
        'coaching_content_refs':
            coachingContentRefs.map((r) => r.toJson()).toList(growable: false),
        'media_refs': mediaRefs.map((r) => r.toJson()).toList(growable: false),
        'movement_standard_refs': movementStandardRefs
            .map((r) => r.toJson())
            .toList(growable: false),
        'sport_standard_refs':
            sportStandardRefs.map((r) => r.toJson()).toList(growable: false),
        'transitional_alias_ids': transitionalAliasIds,
        'lifecycle_status': lifecycleStatus.wireValue,
        'version': version,
        'owner': owner,
        if (publishedAt != null)
          'published_at': publishedAt!.toUtc().toIso8601String(),
        if (retiredAt != null)
          'retired_at': retiredAt!.toUtc().toIso8601String(),
      };

  factory ExerciseDefinition.fromJson(Map<String, Object?> json) {
    return ExerciseDefinition(
      id: ExerciseId.parse(json['id']?.toString() ?? ''),
      canonicalName: json['canonical_name']?.toString() ?? '',
      aliases: _strings(json['aliases']),
      modality: ExerciseModalityCodec.tryParse(json['modality']?.toString()) ??
          ExerciseModality.other,
      familyId: json['family_id']?.toString(),
      movementPatterns: _patterns(json['movement_patterns']),
      laterality:
          ExerciseLateralityCodec.tryParse(json['laterality']?.toString()) ??
              ExerciseLaterality.notApplicable,
      technicalComplexity: ExerciseTechnicalComplexityCodec.tryParse(
            json['technical_complexity']?.toString(),
          ) ??
          ExerciseTechnicalComplexity.unknown,
      impactLevel: ExerciseImpactLevelCodec.tryParse(
            json['impact_level']?.toString(),
          ) ??
          ExerciseImpactLevel.unknown,
      validPrescriptionDimensions:
          _dims(json['valid_prescription_dimensions']),
      validCompletedPerformanceDimensions:
          _dims(json['valid_completed_performance_dimensions']),
      equipment: EquipmentRequirement.fromJson(
        Map<String, Object?>.from(
          (json['equipment'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
      ),
      environments: EnvironmentSuitability.fromJson(
        Map<String, Object?>.from(
          (json['environments'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
      ),
      coachingContentRefs: _mapList(
        json['coaching_content_refs'],
        CoachingContentRef.fromJson,
      ),
      mediaRefs: _mapList(json['media_refs'], MediaReference.fromJson),
      movementStandardRefs: _mapList(
        json['movement_standard_refs'],
        MovementStandardRef.fromJson,
      ),
      sportStandardRefs: _mapList(
        json['sport_standard_refs'],
        SportStandardRef.fromJson,
      ),
      transitionalAliasIds: _strings(json['transitional_alias_ids']),
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

List<String> _strings(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList(growable: false);
}

List<MovementPattern> _patterns(Object? raw) {
  if (raw is! List) return const [];
  final out = <MovementPattern>[];
  for (final item in raw) {
    final p = MovementPatternDb.fromDb(item?.toString());
    if (p != null) out.add(p);
  }
  return List.unmodifiable(out);
}

List<PerformanceDimension> _dims(Object? raw) {
  if (raw is! List) return const [];
  final out = <PerformanceDimension>[];
  for (final item in raw) {
    final d = PerformanceDimensionCodec.tryParse(item?.toString());
    if (d != null) out.add(d);
  }
  return List.unmodifiable(out);
}

List<T> _mapList<T>(
  Object? raw,
  T Function(Map<String, Object?>) fromJson,
) {
  if (raw is! List) return const [];
  final out = <T>[];
  for (final item in raw) {
    if (item is Map) {
      out.add(fromJson(Map<String, Object?>.from(item.cast<String, Object?>())));
    }
  }
  return List.unmodifiable(out);
}

DateTime? _dt(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toUtc();
}
