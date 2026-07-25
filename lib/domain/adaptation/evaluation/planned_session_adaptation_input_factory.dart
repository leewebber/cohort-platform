import '../../../models/protocol_draft.dart';
import '../../../models/protocol_metadata_vocabulary.dart';
import '../../../models/session_block.dart';
import '../../../models/session_block_type.dart';
import '../contracts/adaptation_metadata_contracts.dart';
import '../planning/planned_block_duration_estimator.dart';
import '../vocabulary/impact_level.dart';
import 'adaptation_evaluation_result.dart';

/// Maps runtime [ProtocolDraft] / [SessionBlock] rows into evaluation snapshots.
class PlannedSessionAdaptationInputFactory {
  const PlannedSessionAdaptationInputFactory._();

  static PlannedSessionAdaptationInput fromProtocolDraft(
    ProtocolDraft draft, {
    List<SessionBlock>? blocks,
    Map<String, ExerciseAdaptationMetadataForEvaluation>? exerciseMetadataById,
  }) {
    final resolvedBlocks = blocks ?? draft.blocks;
    return PlannedSessionAdaptationInput(
      protocolId: draft.protocolId,
      primarySessionIntent: draft.primarySessionIntent,
      secondarySessionIntents: draft.secondarySessionIntents,
      plannedDurationMin: draft.durationMin,
      minimumViableDurationMin: draft.minimumViableDurationMin,
      requiredEquipmentTokens: ProtocolMetadataVocabulary.parseCommaSeparated(
        draft.requiredEquipment,
      ),
      sessionEnvironmentLabel: draft.environment,
      hotelFriendly: draft.hotelFriendly,
      indoorFriendly: draft.indoorFriendly,
      physiologicalDemandLabel: draft.physiologicalDemand,
      sessionImpact: _impactFromDemandLabel(draft.physiologicalDemand),
      blocks: resolvedBlocks
          .map(
            (block) => PlannedBlockAdaptationInput(
              localId: block.localId,
              blockTypeDbValue: block.blockType.name,
              position: block.position,
              explicitPriority: block.blockPriority,
              explicitPolicy: block.adaptationPolicy,
              linkedExerciseIds: block.linkedExercises
                  .map((link) => link.exerciseId)
                  .toList(growable: false),
              estimatedDurationMinutes:
                  PlannedBlockDurationEstimator.estimatedMinutesFromBlock(block),
              estimatedDurationUnknown:
                  PlannedBlockDurationEstimator.estimatedMinutesFromBlock(block) ==
                      null,
              exercisePrescriptions:
                  PlannedBlockDurationEstimator.prescriptionsFromBlock(block),
              policyMinimumViablePrescription:
                  block.adaptationPolicy?.minimumViablePrescription,
            ),
          )
          .toList(growable: false),
      exerciseMetadataById: exerciseMetadataById ?? const {},
    );
  }

  static ExerciseAdaptationMetadataForEvaluation fromExerciseMetadata(
    ExerciseAdaptationMetadata metadata,
  ) {
    return ExerciseAdaptationMetadataForEvaluation(
      exerciseId: metadata.exerciseId,
      movementPatterns: metadata.movementPatterns,
      bodyRegion: null,
      impact: metadata.impact,
      equipment: metadata.equipment.toSet(),
    );
  }

  static ImpactLevel? _impactFromDemandLabel(String? demand) {
    if (demand == null || demand.trim().isEmpty) return null;
    final lower = demand.trim().toLowerCase();
    if (lower.contains('very high')) return ImpactLevel.veryHigh;
    if (lower.contains('high')) return ImpactLevel.high;
    if (lower.contains('moderate') || lower.contains('medium')) {
      return ImpactLevel.moderate;
    }
    if (lower.contains('very low')) return ImpactLevel.veryLow;
    if (lower.contains('low') || lower.contains('light')) return ImpactLevel.low;
    return null;
  }

  static SessionBlockType blockTypeFromDb(String dbValue) {
    return SessionBlockType.values.firstWhere(
      (type) => type.name == dbValue,
      orElse: () => SessionBlockType.custom,
    );
  }
}
