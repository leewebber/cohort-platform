import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/protocol_metadata_vocabulary.dart';
import 'package:cohort_platform/models/session_block.dart';
import 'package:cohort_platform/models/session_block_type.dart';

import 'planned_block_duration_adapter.dart';

/// Maps runtime [ProtocolDraft] / [SessionBlock] rows into domain evaluation input.
class PlannedSessionAdaptationInputAdapter {
  const PlannedSessionAdaptationInputAdapter._();

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
                  PlannedBlockDurationAdapter.estimatedMinutesFromBlock(block),
              estimatedDurationUnknown:
                  PlannedBlockDurationAdapter.estimatedMinutesFromBlock(
                    block,
                  ) ==
                  null,
              exercisePrescriptions:
                  PlannedBlockDurationAdapter.prescriptionsFromBlock(block),
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
    if (lower.contains('low') || lower.contains('light')) {
      return ImpactLevel.low;
    }
    return null;
  }

  /// Parses [PlannedBlockAdaptationInput.blockTypeDbValue] from authoring.
  static SessionBlockType blockTypeFromDb(String dbValue) {
    return SessionBlockType.values.firstWhere(
      (type) => type.name == dbValue,
      orElse: () => SessionBlockType.custom,
    );
  }
}

/// Back-compat alias for tests and callers migrating from domain factory.
typedef PlannedSessionAdaptationInputFactory =
    PlannedSessionAdaptationInputAdapter;
