import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/models/block_performance_capture_mode.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_type.dart';

/// Fully adaptation-tagged upper body strength session for founder-style code authoring.
ProtocolDraft fullyTaggedUpperBodyStrengthSession({
  required String protocolId,
  required String programmeVersionId,
}) {
  return programmeSession(
    protocolId: protocolId,
    name: 'Upper Body Strength',
    programmeVersionId: programmeVersionId,
    ownerId: 'dev-coach',
    sessionFormat: 'structured_strength',
    durationMin: 60,
    primarySessionIntent: SessionIntent.upperBodyStrength,
    secondarySessionIntents: const [SessionIntent.upperBodyHypertrophy],
    minimumViableDurationMin: 35,
    blocks: [
      block(
        type: SessionBlockType.warmUp,
        content: 'Row and shoulder prep',
        performanceCaptureMode: BlockPerformanceCaptureMode.completion,
      ),
      block(
        type: SessionBlockType.strength,
        title: 'Main strength',
        blockPriority: BlockPriority.essential,
        adaptationPolicy: const BlockAdaptationPolicy(
          canRemove: false,
          canShorten: false,
          canReduceVolume: true,
          canReduceIntensity: true,
          canIncreaseRest: true,
          canSuperset: false,
          canReplaceExercises: true,
          canReplaceBlock: false,
        ),
        linkedExercises: [exerciseLink(exerciseId: 'BP-001', position: 1)],
      ),
      block(
        type: SessionBlockType.accessory,
        blockPriority: BlockPriority.secondary,
      ),
    ],
  );
}
