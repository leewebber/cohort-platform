import 'package:cohort_platform/data/repositories/session_lineage_store.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';

import 'journey_d_protocol_publication.dart';

/// Canonical live publisher: [ProtocolBuilderService.publishDraft] + lineage lookup.
///
/// Does not duplicate publication logic or use improvised SQL. Staging live
/// callers must enforce Cohort Staging + explicit live flags before invoking.
class ProtocolBuilderJourneyDPublisher implements JourneyDProtocolPublisher {
  ProtocolBuilderJourneyDPublisher({
    required this._protocolBuilderService,
    required this._sessionLineageStore,
  });

  final ProtocolBuilderService _protocolBuilderService;
  final SessionLineageStore _sessionLineageStore;

  /// Marker programme version id for fixture-only drafts (not a hosted lookup).
  static const fixtureProgrammeVersionPlaceholder =
      's17-jd-adapt-fixture-programme-version';

  @override
  Future<JourneyDProtocolPublicationResult> publish(
    JourneyDProtocolPublicationIntent intent,
  ) async {
    try {
      final draft = _draftFor(intent);
      final save = await _protocolBuilderService.publishDraft(draft);
      if (!save.published || save.protocolId != intent.protocolId) {
        return JourneyDProtocolPublicationResult(
          intent: intent,
          state: JourneyDPublicationStageState.failed,
          detail: 'publishDraft_identity_or_published_flag_failed',
          furtherMutationProhibited: true,
        );
      }

      final identity = await _sessionLineageStore.getRevisionIdentity(
        intent.protocolId,
      );
      if (identity == null || identity.sessionLineageId.trim().isEmpty) {
        return JourneyDProtocolPublicationResult(
          intent: intent,
          state: JourneyDPublicationStageState.unknown,
          detail: 'lineage_lookup_missing_after_publish',
          furtherMutationProhibited: true,
        );
      }

      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.applied,
        returnedSessionLineageId: identity.sessionLineageId,
        returnedRevisionNumber: identity.revisionNumber,
        detail: 'ProtocolBuilderService.publishDraft',
      );
    } on Object catch (error) {
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.failed,
        detail: 'publishDraft_exception:${error.runtimeType}',
        furtherMutationProhibited: true,
      );
    }
  }

  ProtocolDraft _draftFor(JourneyDProtocolPublicationIntent intent) {
    final base = programmeSession(
      protocolId: intent.protocolId,
      name: 'S17 Journey D ${intent.role}',
      programmeVersionId: fixtureProgrammeVersionPlaceholder,
      ownerId: null,
      durationMin: 45,
      primarySessionIntent: SessionIntent.lowerBodyStrength,
      minimumViableDurationMin: 25,
      blocks: [
        block(
          localId: 'block-main',
          type: SessionBlockType.strength,
          position: 1,
          title: 'Main',
          blockPriority: BlockPriority.essential,
          adaptationPolicy: BlockAdaptationPolicy(
            canRemove: false,
            canShorten: false,
            canReduceVolume: true,
            canReduceIntensity: true,
            canIncreaseRest: true,
            canSuperset: false,
            canReplaceExercises: intent.canReplaceExercises,
            canReplaceBlock: false,
            minimumViablePrescription: const MinimumViablePrescription(sets: 2),
          ),
          linkedExercises: [
            SessionBlockExerciseLink(
              localId: 'link-1',
              exerciseId: intent.exerciseId,
              position: 1,
              prescription: StrengthExercisePrescription(
                sets: 3,
                reps: StrengthRepPrescription.exact(5),
                restSeconds: 120,
              ),
            ),
          ],
        ),
      ],
    );
    return base.copyWith(revisionNumber: intent.revisionNumber);
  }
}
