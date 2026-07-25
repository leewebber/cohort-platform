import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/features/session_builder/controllers/session_builder_editing_state.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/features/session_builder/services/programme_session_draft_factory.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:flutter_test/flutter_test.dart';

import 'programme_code_authoring_fixtures.dart';
import 'programme_session_authoring_test_support.dart';

const canonicalMinDuration = 35;
const canonicalPlannedDuration = 60;

const explicitStrengthPolicy = BlockAdaptationPolicy(
  canRemove: false,
  canShorten: false,
  canReduceVolume: true,
  canReduceIntensity: true,
  canIncreaseRest: true,
  canSuperset: false,
  canReplaceExercises: true,
  canReplaceBlock: false,
);

ProtocolDraft buildTaggedSessionViaCode({
  required String protocolId,
  required String programmeVersionId,
}) {
  return fullyTaggedUpperBodyStrengthSession(
    protocolId: protocolId,
    programmeVersionId: programmeVersionId,
  );
}

ProtocolDraft buildTaggedSessionViaVisualBuilder({
  required String protocolId,
  required String programmeVersionId,
}) {
  final context = ProgrammeSessionAuthoringContext(
    programmeVersionId: programmeVersionId,
    weekLocalId: testWeekLocalId,
    dayLocalId: testDayLocalId,
    slotLocalId: testSlotLocalId,
    weekNumber: 2,
    dayLabel: 'Tuesday',
    slotDisplayLabel: 'Morning',
    authoringIntent: ProgrammeSessionAuthoringIntent.createBlank,
  );

  final blank =
      ProgrammeSessionDraftFactory.createBlankProgrammeSessionDraft(context)
          .copyWith(
    protocolId: protocolId,
    name: 'Upper Body Strength',
    sessionFormat: 'structured_strength',
    programmeVersionId: programmeVersionId,
  );

  final editing = SessionBuilderEditingState(draft: blank);
  editing.setPrimarySessionIntent(SessionIntent.upperBodyStrength);
  editing.setSecondarySessionIntents(const [SessionIntent.upperBodyHypertrophy]);
  editing.setMinimumViableDurationMin(canonicalMinDuration);
  editing.durationMin = canonicalPlannedDuration;

  editing.blocks = [
    block(
      type: SessionBlockType.warmUp,
      content: 'Row and shoulder prep',
    ),
    block(
      type: SessionBlockType.strength,
      title: 'Main strength',
      blockPriority: BlockPriority.essential,
      adaptationPolicy: explicitStrengthPolicy,
      linkedExercises: [exerciseLink(exerciseId: 'BP-001', position: 1)],
    ),
    block(
      type: SessionBlockType.accessory,
      blockPriority: BlockPriority.secondary,
    ),
  ];

  return editing.buildDraft();
}

Map<String, ExerciseAdaptationMetadataForEvaluation> benchPressMetadata({
  List<MovementPattern> patterns = const [MovementPattern.horizontalPush],
  String? bodyRegion = 'shoulder',
}) {
  return {
    'BP-001': ExerciseAdaptationMetadataForEvaluation(
      exerciseId: 'BP-001',
      movementPatterns: patterns,
      bodyRegion: bodyRegion,
    ),
  };
}

PlannedSessionAdaptationInput plannedInputFromDraft(
  ProtocolDraft draft, {
  Map<String, ExerciseAdaptationMetadataForEvaluation>? exerciseMetadataById,
}) {
  return PlannedSessionAdaptationInputFactory.fromProtocolDraft(
    draft,
    exerciseMetadataById: exerciseMetadataById ?? benchPressMetadata(),
  );
}

SessionAdaptationEvaluationResult evaluateDraft(
  ProtocolDraft draft, {
  required AdaptationConstraintContext constraints,
  Map<String, ExerciseAdaptationMetadataForEvaluation>? exerciseMetadataById,
}) {
  const evaluator = SessionAdaptationReadOnlyEvaluator();
  return evaluator.evaluate(
    session: plannedInputFromDraft(
      draft,
      exerciseMetadataById: exerciseMetadataById,
    ),
    constraints: constraints,
  );
}

bool resultEquivalent(
  SessionAdaptationEvaluationResult a,
  SessionAdaptationEvaluationResult b,
) {
  if (a.outcome != b.outcome) return false;
  if (a.primaryIntentKnown != b.primaryIntentKnown) return false;
  if (a.primaryIntentPreservable != b.primaryIntentPreservable) return false;
  if (a.minimumScope != b.minimumScope) return false;
  if (a.expectedFidelity != b.expectedFidelity) return false;
  if (a.adaptationConfidence != b.adaptationConfidence) return false;
  if (a.missingMetadata.length != b.missingMetadata.length) return false;
  for (var i = 0; i < a.missingMetadata.length; i++) {
    if (a.missingMetadata[i] != b.missingMetadata[i]) return false;
  }
  final aCodes = a.findings.map((f) => f.code).toSet();
  final bCodes = b.findings.map((f) => f.code).toSet();
  if (aCodes.length != bCodes.length || !aCodes.containsAll(bCodes)) {
    return false;
  }
  final aConfidence = a.confidenceFindings.toSet();
  final bConfidence = b.confidenceFindings.toSet();
  return aConfidence.length == bConfidence.length &&
      aConfidence.containsAll(bConfidence);
}
