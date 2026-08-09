import '../../adaptation/vocabulary/training_environment.dart';

/// Explicit environment suitability for an exercise definition.
///
/// Equipment alone does not fully define environmental suitability.
class EnvironmentSuitability {
  const EnvironmentSuitability({
    this.suitable = const [],
    this.unsuitable = const [],
    this.notes,
  });

  final List<TrainingEnvironment> suitable;
  final List<TrainingEnvironment> unsuitable;
  final String? notes;

  Map<String, Object?> toJson() => {
        'suitable': suitable.map((e) => e.dbValue).toList(growable: false),
        'unsuitable':
            unsuitable.map((e) => e.dbValue).toList(growable: false),
        if (notes != null) 'notes': notes,
      };

  factory EnvironmentSuitability.fromJson(Map<String, Object?> json) {
    return EnvironmentSuitability(
      suitable: _envs(json['suitable']),
      unsuitable: _envs(json['unsuitable']),
      notes: json['notes']?.toString(),
    );
  }
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
