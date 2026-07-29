import '../contracts/block_adaptation_policy.dart';
import '../vocabulary/adaptation_block_type.dart';
import '../vocabulary/block_priority.dart';

/// Default block priority and adaptation policy derived from block type.
class SessionBlockTypeAdaptationPolicy {
  const SessionBlockTypeAdaptationPolicy._();

  /// Default [BlockPriority] when authored priority is absent.
  static BlockPriority defaultPriority(AdaptationBlockType blockType) {
    return switch (blockType) {
      AdaptationBlockType.strength => BlockPriority.primary,
      AdaptationBlockType.conditioning => BlockPriority.primary,
      AdaptationBlockType.skill => BlockPriority.secondary,
      AdaptationBlockType.accessory => BlockPriority.secondary,
      AdaptationBlockType.core => BlockPriority.optional,
      AdaptationBlockType.warmUp => BlockPriority.disposable,
      AdaptationBlockType.coolDown => BlockPriority.disposable,
      AdaptationBlockType.custom => BlockPriority.secondary,
    };
  }

  /// Suggested default adaptation policy flags per block type (author may override).
  static BlockAdaptationPolicy defaultAdaptationPolicy(
    AdaptationBlockType blockType,
  ) {
    return switch (blockType) {
      AdaptationBlockType.strength => const BlockAdaptationPolicy(
        canRemove: false,
        canShorten: false,
        canReduceVolume: true,
        canReduceIntensity: true,
        canIncreaseRest: true,
        canSuperset: false,
        canReplaceExercises: true,
        canReplaceBlock: false,
      ),
      AdaptationBlockType.conditioning => const BlockAdaptationPolicy(
        canRemove: true,
        canShorten: true,
        canReduceVolume: true,
        canReduceIntensity: true,
        canIncreaseRest: true,
        canSuperset: false,
        canReplaceExercises: true,
        canReplaceBlock: true,
      ),
      AdaptationBlockType.warmUp ||
      AdaptationBlockType.coolDown => const BlockAdaptationPolicy(
        canRemove: true,
        canShorten: true,
        canReduceVolume: true,
        canReduceIntensity: true,
        canIncreaseRest: true,
        canSuperset: false,
        canReplaceExercises: true,
        canReplaceBlock: true,
      ),
      _ => const BlockAdaptationPolicy(
        canRemove: true,
        canShorten: true,
        canReduceVolume: true,
        canReduceIntensity: true,
        canIncreaseRest: true,
        canSuperset: true,
        canReplaceExercises: true,
        canReplaceBlock: true,
      ),
    };
  }
}
