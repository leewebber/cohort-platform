import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/features/session_builder/controllers/session_builder_editing_state.dart';
import 'package:cohort_platform/features/session_builder/models/programme_session_authoring_context.dart';
import 'package:cohort_platform/features/session_builder/models/session_builder_host_mode.dart';
import 'package:cohort_platform/features/session_builder/services/programme_session_draft_factory.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';

import 'adaptation_evaluation_test_support.dart';
import 'programme_session_authoring_test_support.dart';

PlannedSessionAdaptationInput patchBlockPlanningMetadata(
  PlannedSessionAdaptationInput input, {
  Map<String, int>? durationMinutesByBlockLocalId,
  Map<String, bool>? durationUnknownByBlockLocalId,
}) {
  return PlannedSessionAdaptationInput(
    protocolId: input.protocolId,
    primarySessionIntent: input.primarySessionIntent,
    secondarySessionIntents: input.secondarySessionIntents,
    plannedDurationMin: input.plannedDurationMin,
    minimumViableDurationMin: input.minimumViableDurationMin,
    requiredEquipmentTokens: input.requiredEquipmentTokens,
    sessionEnvironmentLabel: input.sessionEnvironmentLabel,
    hotelFriendly: input.hotelFriendly,
    indoorFriendly: input.indoorFriendly,
    physiologicalDemandLabel: input.physiologicalDemandLabel,
    sessionImpact: input.sessionImpact,
    exerciseMetadataById: input.exerciseMetadataById,
    blocks: input.blocks
        .map(
          (block) => PlannedBlockAdaptationInput(
            localId: block.localId,
            blockTypeDbValue: block.blockTypeDbValue,
            position: block.position,
            explicitPriority: block.explicitPriority,
            explicitPolicy: block.explicitPolicy,
            linkedExerciseIds: block.linkedExerciseIds,
            estimatedDurationMinutes:
                durationMinutesByBlockLocalId?[block.localId] ??
                block.estimatedDurationMinutes,
            estimatedDurationUnknown:
                durationUnknownByBlockLocalId?[block.localId] ??
                block.estimatedDurationUnknown,
            exercisePrescriptions: block.exercisePrescriptions,
            policyMinimumViablePrescription:
                block.policyMinimumViablePrescription,
          ),
        )
        .toList(growable: false),
  );
}

ProtocolDraft buildTimedPlanningSession({
  required String protocolId,
  int plannedDurationMin = 60,
  int minimumViableDurationMin = 35,
}) {
  return programmeSession(
    protocolId: protocolId,
    name: 'Timed planning session',
    programmeVersionId: testProgrammeVersionId,
    ownerId: 'dev-coach',
    durationMin: plannedDurationMin,
    primarySessionIntent: SessionIntent.upperBodyStrength,
    minimumViableDurationMin: minimumViableDurationMin,
    blocks: [
      block(
        localId: 'block-warmup',
        type: SessionBlockType.warmUp,
        position: 1,
        content: 'Prep',
      ),
      block(
        localId: 'block-strength',
        type: SessionBlockType.strength,
        position: 2,
        title: 'Main',
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
          minimumViablePrescription: MinimumViablePrescription(sets: 2),
        ),
        linkedExercises: [
          SessionBlockExerciseLink(
            localId: 'link-strength-1',
            exerciseId: 'BP-001',
            position: 1,
            prescription: StrengthExercisePrescription(
              sets: 4,
              reps: StrengthRepPrescription.exact(8),
              restSeconds: 120,
            ),
          ),
        ],
      ),
      block(
        localId: 'block-accessory',
        type: SessionBlockType.accessory,
        position: 3,
        blockPriority: BlockPriority.secondary,
        linkedExercises: [
          SessionBlockExerciseLink(
            localId: 'link-acc-1',
            exerciseId: 'ACC-001',
            position: 1,
            prescription: StrengthExercisePrescription(
              sets: 3,
              reps: StrengthRepPrescription.exact(12),
            ),
          ),
        ],
      ),
    ],
  );
}

/// Builder-authored twin of [buildTimedPlanningSession] for equivalence tests.
ProtocolDraft buildTimedPlanningSessionViaBuilder({
  required String protocolId,
  int plannedDurationMin = 60,
  int minimumViableDurationMin = 35,
}) {
  final context = ProgrammeSessionAuthoringContext(
    programmeVersionId: testProgrammeVersionId,
    weekLocalId: testWeekLocalId,
    dayLocalId: testDayLocalId,
    slotLocalId: testSlotLocalId,
    weekNumber: 2,
    dayLabel: 'Tuesday',
    slotDisplayLabel: 'Morning',
    authoringIntent: ProgrammeSessionAuthoringIntent.createBlank,
  );

  final editing = SessionBuilderEditingState(
    draft:
        ProgrammeSessionDraftFactory.createBlankProgrammeSessionDraft(
          context,
        ).copyWith(
          protocolId: protocolId,
          name: 'Timed planning session',
          sessionFormat: 'structured_strength',
          programmeVersionId: testProgrammeVersionId,
        ),
  );
  editing.setPrimarySessionIntent(SessionIntent.upperBodyStrength);
  editing.setMinimumViableDurationMin(minimumViableDurationMin);
  editing.durationMin = plannedDurationMin;

  editing.blocks = [
    block(
      localId: 'block-warmup',
      type: SessionBlockType.warmUp,
      position: 1,
      content: 'Prep',
    ),
    block(
      localId: 'block-strength',
      type: SessionBlockType.strength,
      position: 2,
      title: 'Main',
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
        minimumViablePrescription: MinimumViablePrescription(sets: 2),
      ),
      linkedExercises: [
        SessionBlockExerciseLink(
          localId: 'link-strength-1',
          exerciseId: 'BP-001',
          position: 1,
          prescription: StrengthExercisePrescription(
            sets: 4,
            reps: StrengthRepPrescription.exact(8),
            restSeconds: 120,
          ),
        ),
      ],
    ),
    block(
      localId: 'block-accessory',
      type: SessionBlockType.accessory,
      position: 3,
      blockPriority: BlockPriority.secondary,
      linkedExercises: [
        SessionBlockExerciseLink(
          localId: 'link-acc-1',
          exerciseId: 'ACC-001',
          position: 1,
          prescription: StrengthExercisePrescription(
            sets: 3,
            reps: StrengthRepPrescription.exact(12),
          ),
        ),
      ],
    ),
  ];

  return editing.buildDraft();
}

PlannedSessionAdaptationInput timedPlanningInputFromDraft(ProtocolDraft draft) {
  final base = PlannedSessionAdaptationInputFactory.fromProtocolDraft(
    draft,
    exerciseMetadataById: benchPressMetadata(),
  );
  return patchBlockPlanningMetadata(
    base,
    durationMinutesByBlockLocalId: {
      'block-warmup': 10,
      'block-strength': 32,
      'block-accessory': 18,
    },
    durationUnknownByBlockLocalId: {
      'block-warmup': false,
      'block-strength': false,
      'block-accessory': false,
    },
  );
}

AdaptationPlanResult planDraft(
  ProtocolDraft draft, {
  required AdaptationConstraintContext constraints,
  PlannedSessionAdaptationInput? input,
}) {
  const planner = SessionAdaptationPlanner();
  final session = input ?? timedPlanningInputFromDraft(draft);
  return planner.plan(session: session, constraints: constraints);
}

bool planEquivalent(AdaptationPlanResult a, AdaptationPlanResult b) {
  if (a.status != b.status) return false;
  if (a.isApplicable != b.isApplicable) return false;
  if (a.steps.length != b.steps.length) return false;
  for (var i = 0; i < a.steps.length; i++) {
    final sa = a.steps[i];
    final sb = b.steps[i];
    if (sa.actionType != sb.actionType) return false;
    if (sa.targetId != sb.targetId) return false;
    if (sa.rationaleCode != sb.rationaleCode) return false;
    if (sa.policySource != sb.policySource) return false;
  }
  return a.planFindings.toSet().containsAll(b.planFindings.toSet()) &&
      b.planFindings.toSet().containsAll(a.planFindings.toSet());
}
