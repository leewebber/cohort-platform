import 'minimum_viable_prescription.dart';

/// Authoring policy for how a block may be adapted under constraints.
class BlockAdaptationPolicy {
  const BlockAdaptationPolicy({
    required this.canRemove,
    required this.canShorten,
    required this.canReduceVolume,
    required this.canReduceIntensity,
    required this.canIncreaseRest,
    required this.canSuperset,
    required this.canReplaceExercises,
    required this.canReplaceBlock,
    this.minimumViablePrescription,
    this.dependsOnBlockIds = const [],
  });

  final bool canRemove;
  final bool canShorten;
  final bool canReduceVolume;
  final bool canReduceIntensity;
  final bool canIncreaseRest;
  final bool canSuperset;
  final bool canReplaceExercises;
  final bool canReplaceBlock;
  final MinimumViablePrescription? minimumViablePrescription;
  final List<String> dependsOnBlockIds;

  Map<String, dynamic> toJson() {
    return {
      'can_remove': canRemove,
      'can_shorten': canShorten,
      'can_reduce_volume': canReduceVolume,
      'can_reduce_intensity': canReduceIntensity,
      'can_increase_rest': canIncreaseRest,
      'can_superset': canSuperset,
      'can_replace_exercises': canReplaceExercises,
      'can_replace_block': canReplaceBlock,
      if (minimumViablePrescription != null &&
          !minimumViablePrescription!.isEmpty)
        'minimum_viable_prescription': minimumViablePrescription!.toJson(),
      if (dependsOnBlockIds.isNotEmpty) 'depends_on_block_ids': dependsOnBlockIds,
    };
  }

  factory BlockAdaptationPolicy.fromJson(Map<String, dynamic> json) {
    final mvpRaw = json['minimum_viable_prescription'];
    MinimumViablePrescription? mvp;
    if (mvpRaw is Map<String, dynamic>) {
      mvp = MinimumViablePrescription.fromJson(mvpRaw);
    } else if (mvpRaw is Map) {
      mvp = MinimumViablePrescription.fromJson(Map<String, dynamic>.from(mvpRaw));
    }

    return BlockAdaptationPolicy(
      canRemove: json['can_remove'] == true,
      canShorten: json['can_shorten'] == true,
      canReduceVolume: json['can_reduce_volume'] == true,
      canReduceIntensity: json['can_reduce_intensity'] == true,
      canIncreaseRest: json['can_increase_rest'] == true,
      canSuperset: json['can_superset'] == true,
      canReplaceExercises: json['can_replace_exercises'] == true,
      canReplaceBlock: json['can_replace_block'] == true,
      minimumViablePrescription: mvp,
      dependsOnBlockIds: _stringList(json['depends_on_block_ids']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
