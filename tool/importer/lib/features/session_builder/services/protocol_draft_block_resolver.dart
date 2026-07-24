import 'package:founder_importer/models/protocol_draft.dart';
import 'package:founder_importer/models/protocol_step_draft.dart';
import 'package:founder_importer/models/session_block.dart';
import 'package:founder_importer/features/session_builder/services/block_to_legacy_step_projector.dart';
import 'package:founder_importer/features/session_builder/services/legacy_step_to_block_converter.dart';

/// Resolves block/step source-of-truth for [ProtocolDraft] during M6 transition.
class ProtocolDraftBlockResolver {
  const ProtocolDraftBlockResolver({
    LegacyStepToBlockConverter? legacyConverter,
    BlockToLegacyStepProjector? stepProjector,
  })  : _legacyConverter = legacyConverter ?? const LegacyStepToBlockConverter(),
        _stepProjector = stepProjector ?? const BlockToLegacyStepProjector();

  final LegacyStepToBlockConverter _legacyConverter;
  final BlockToLegacyStepProjector _stepProjector;

  List<SessionBlock> resolveBlocks(ProtocolDraft draft) {
    if (draft.blocks.isNotEmpty) {
      return _orderedBlocks(draft.blocks);
    }

    return _legacyConverter.convertStepsToBlocks(draft.steps);
  }

  List<ProtocolStepDraft> resolveSteps(ProtocolDraft draft) {
    final blocks = resolveBlocks(draft);
    if (blocks.isEmpty) {
      return _orderedSteps(draft.steps);
    }

    return _stepProjector.projectBlocksToSteps(blocks);
  }

  ProtocolDraft withResolvedBlocks(ProtocolDraft draft) {
    if (draft.blocks.isNotEmpty) {
      return draft;
    }

    return draft.copyWith(blocks: resolveBlocks(draft));
  }

  ProtocolDraft withSyncedStepsFromBlocks(ProtocolDraft draft) {
    final blocks = resolveBlocks(draft);
    if (blocks.isEmpty) {
      return draft;
    }

    return draft.copyWith(
      blocks: blocks,
      steps: _stepProjector.projectBlocksToSteps(blocks),
    );
  }

  List<SessionBlock> _orderedBlocks(List<SessionBlock> blocks) {
    final ordered = List<SessionBlock>.from(blocks)
      ..sort((a, b) => a.position.compareTo(b.position));
    return ordered;
  }

  List<ProtocolStepDraft> _orderedSteps(List<ProtocolStepDraft> steps) {
    final ordered = List<ProtocolStepDraft>.from(steps)
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));
    return ordered;
  }
}
