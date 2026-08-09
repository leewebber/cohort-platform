import '../value_objects/exercise_id.dart';
import '../vocabulary/performance_dimension.dart';

/// Authored protocol governing like-for-like performance comparison.
///
/// Does not contain athlete results. Substitution alone never grants
/// compatibility with a protocol.
class ComparisonProtocol {
  const ComparisonProtocol({
    required this.id,
    required this.version,
    required this.exerciseId,
    required this.validDimensions,
    this.setupKey,
    this.standardRefId,
    this.label,
    this.requiresSameSetup = true,
  });

  final String id;
  final String version;
  final ExerciseId exerciseId;
  final List<PerformanceDimension> validDimensions;

  /// Optional setup/standard discriminator (e.g. outdoor vs treadmill).
  final String? setupKey;
  final String? standardRefId;
  final String? label;
  final bool requiresSameSetup;

  /// Stable comparison-series key (exercise + protocol + version + setup).
  String get comparisonSeriesKey {
    final setup = setupKey?.trim().isEmpty ?? true ? '_' : setupKey!.trim();
    return 'cmp:${exerciseId.value}:$id:v$version:$setup';
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'version': version,
        'exercise_id': exerciseId.value,
        'valid_dimensions':
            validDimensions.map((d) => d.wireValue).toList(growable: false),
        if (setupKey != null) 'setup_key': setupKey,
        if (standardRefId != null) 'standard_ref_id': standardRefId,
        if (label != null) 'label': label,
        'requires_same_setup': requiresSameSetup,
        'comparison_series_key': comparisonSeriesKey,
      };

  factory ComparisonProtocol.fromJson(Map<String, Object?> json) {
    final dims = <PerformanceDimension>[];
    final rawDims = json['valid_dimensions'];
    if (rawDims is List) {
      for (final item in rawDims) {
        final dim = PerformanceDimensionCodec.tryParse(item?.toString());
        if (dim != null) dims.add(dim);
      }
    }
    return ComparisonProtocol(
      id: json['id']?.toString().trim() ?? '',
      version: json['version']?.toString().trim() ?? '',
      exerciseId: ExerciseId.parse(json['exercise_id']?.toString() ?? ''),
      validDimensions: List.unmodifiable(dims),
      setupKey: json['setup_key']?.toString(),
      standardRefId: json['standard_ref_id']?.toString(),
      label: json['label']?.toString(),
      requiresSameSetup: json['requires_same_setup'] != false,
    );
  }
}

/// Comparison identity for a performance series — never embeds results.
class ComparisonIdentity {
  const ComparisonIdentity({
    required this.exerciseId,
    required this.protocol,
  });

  final ExerciseId exerciseId;
  final ComparisonProtocol protocol;

  String get seriesKey => protocol.comparisonSeriesKey;

  Map<String, Object?> toJson() => {
        'exercise_id': exerciseId.value,
        'protocol': protocol.toJson(),
        'series_key': seriesKey,
      };
}
