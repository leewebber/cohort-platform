import '../../../models/session_block_type.dart';
import '../contracts/block_adaptation_policy.dart';
import '../vocabulary/block_priority.dart';

/// Maps legacy [SessionBlockType] to canonical block semantics — no duplicate enum.
class SessionBlockTypeAdaptationPolicy {
  const SessionBlockTypeAdaptationPolicy._();

  /// Default [BlockPriority] when authored priority is absent.
  static BlockPriority defaultPriority(SessionBlockType blockType) {
    return switch (blockType) {
      SessionBlockType.strength => BlockPriority.primary,
      SessionBlockType.conditioning => BlockPriority.primary,
      SessionBlockType.skill => BlockPriority.secondary,
      SessionBlockType.accessory => BlockPriority.secondary,
      SessionBlockType.core => BlockPriority.optional,
      SessionBlockType.warmUp => BlockPriority.disposable,
      SessionBlockType.coolDown => BlockPriority.disposable,
      SessionBlockType.custom => BlockPriority.secondary,
    };
  }

  /// Suggested default adaptation policy flags per block type (author may override).
  static BlockAdaptationPolicy defaultAdaptationPolicy(
    SessionBlockType blockType,
  ) {
    return switch (blockType) {
      SessionBlockType.strength => const BlockAdaptationPolicy(
            canRemove: false,
            canShorten: false,
            canReduceVolume: true,
            canReduceIntensity: true,
            canIncreaseRest: true,
            canSuperset: false,
            canReplaceExercises: true,
            canReplaceBlock: false,
          ),
      SessionBlockType.conditioning => const BlockAdaptationPolicy(
            canRemove: true,
            canShorten: true,
            canReduceVolume: true,
            canReduceIntensity: true,
            canIncreaseRest: true,
            canSuperset: false,
            canReplaceExercises: true,
            canReplaceBlock: true,
          ),
      SessionBlockType.warmUp || SessionBlockType.coolDown => const BlockAdaptationPolicy(
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
