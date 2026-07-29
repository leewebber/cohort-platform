import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/models/protocol.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/protocol_metadata_vocabulary.dart';

import 'planned_session_adaptation_input_adapter.dart';

/// Merges persisted [Protocol] row metadata into draft-derived evaluation input.
///
/// Home loads a full protocol row plus a builder draft; legacy evaluate-only
/// gating used both. Coach Brain evaluation receives a single merged snapshot.
class PlannedSessionProtocolMetadataMerge {
  const PlannedSessionProtocolMetadataMerge._();

  static PlannedSessionAdaptationInput merge({
    required ProtocolDraft draft,
    required Protocol protocol,
  }) {
    final fromDraft = PlannedSessionAdaptationInputAdapter.fromProtocolDraft(
      draft,
    );
    final protocolEquipment = ProtocolMetadataVocabulary.parseCommaSeparated(
      protocol.requiredEquipment,
    );

    return PlannedSessionAdaptationInput(
      protocolId: fromDraft.protocolId,
      primarySessionIntent:
          fromDraft.primarySessionIntent ?? protocol.primarySessionIntent,
      secondarySessionIntents: fromDraft.secondarySessionIntents.isNotEmpty
          ? fromDraft.secondarySessionIntents
          : protocol.secondarySessionIntents,
      plannedDurationMin: fromDraft.plannedDurationMin ?? protocol.durationMin,
      minimumViableDurationMin:
          fromDraft.minimumViableDurationMin ??
          protocol.minimumViableDurationMin,
      requiredEquipmentTokens: fromDraft.requiredEquipmentTokens.isNotEmpty
          ? fromDraft.requiredEquipmentTokens
          : protocolEquipment.toSet(),
      sessionEnvironmentLabel:
          _nonEmpty(fromDraft.sessionEnvironmentLabel) ??
          _nonEmpty(protocol.environment),
      hotelFriendly: fromDraft.hotelFriendly ?? protocol.hotelFriendly,
      indoorFriendly: fromDraft.indoorFriendly ?? protocol.indoorFriendly,
      physiologicalDemandLabel:
          _nonEmpty(fromDraft.physiologicalDemandLabel) ??
          _nonEmpty(protocol.demand),
      recoveryCostLabel: _nonEmpty(protocol.recovery),
      sessionImpact: fromDraft.sessionImpact,
      blocks: fromDraft.blocks,
      exerciseMetadataById: fromDraft.exerciseMetadataById,
    );
  }

  static String? _nonEmpty(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}
