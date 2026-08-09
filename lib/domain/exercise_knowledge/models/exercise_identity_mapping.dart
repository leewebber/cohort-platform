import '../value_objects/exercise_id.dart';
import '../value_objects/transitional_exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';

/// Explicit authored mapping: transitional knowledge id → canonical `EX-*`.
///
/// Does **not** imply substitution, equivalence, comparability, or shared
/// performance history. Name/alias similarity is never sufficient provenance.
class ExerciseIdentityMapping {
  const ExerciseIdentityMapping({
    required this.id,
    required this.transitionalId,
    required this.canonicalId,
    required this.lifecycleStatus,
    required this.version,
    required this.provenance,
    this.owner = 'founder',
    this.notes,
    this.publishedAt,
    this.retiredAt,
  });

  final String id;
  final TransitionalExerciseId transitionalId;
  final ExerciseId canonicalId;
  final ExerciseLifecycleStatus lifecycleStatus;
  final String version;

  /// Why this mapping is justified (must be explicit authored reason).
  final String provenance;
  final String owner;
  final String? notes;
  final DateTime? publishedAt;
  final DateTime? retiredAt;

  /// Dedup key for active mapping uniqueness (source id).
  String get uniquenessKey => transitionalId.value;

  bool get isOperational => lifecycleStatus.isRuntimeAuthoritative;

  bool get isHistoricallyResolvable => lifecycleStatus.remainsResolvable;

  Map<String, Object?> toJson() => {
        'id': id,
        'transitional_id': transitionalId.value,
        'canonical_id': canonicalId.value,
        'lifecycle_status': lifecycleStatus.wireValue,
        'version': version,
        'provenance': provenance,
        'owner': owner,
        if (notes != null) 'notes': notes,
        if (publishedAt != null)
          'published_at': publishedAt!.toUtc().toIso8601String(),
        if (retiredAt != null)
          'retired_at': retiredAt!.toUtc().toIso8601String(),
      };

  factory ExerciseIdentityMapping.fromJson(Map<String, Object?> json) {
    return ExerciseIdentityMapping(
      id: json['id']?.toString().trim() ?? '',
      transitionalId: TransitionalExerciseId.parse(
        json['transitional_id']?.toString() ?? '',
      ),
      canonicalId: ExerciseId.parse(json['canonical_id']?.toString() ?? ''),
      lifecycleStatus: ExerciseLifecycleStatusCodec.tryParse(
            json['lifecycle_status']?.toString(),
          ) ??
          ExerciseLifecycleStatus.draft,
      version: json['version']?.toString() ?? '1',
      provenance: json['provenance']?.toString() ?? '',
      owner: json['owner']?.toString() ?? 'founder',
      notes: json['notes']?.toString(),
      publishedAt: _dt(json['published_at']),
      retiredAt: _dt(json['retired_at']),
    );
  }
}

DateTime? _dt(Object? raw) {
  if (raw == null) return null;
  return DateTime.tryParse(raw.toString())?.toUtc();
}
