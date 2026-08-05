import 'dart:async';

import 'package:cohort_platform/data/repositories/session_lineage_store.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/programme_builder/authoring/programme_code_authoring.dart';
import 'package:cohort_platform/models/protocol_draft.dart';
import 'package:cohort_platform/models/session_block_exercise_link.dart';
import 'package:cohort_platform/models/session_block_type.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';

import 'journey_d_protocol_publication.dart';
import 'journey_d_write_accounting.dart';

/// Canonical live publisher: [ProtocolBuilderService.publishDraft] + lineage lookup.
///
/// Does not duplicate publication logic or use improvised SQL. Staging live
/// callers must enforce Cohort Staging + explicit live flags before invoking.
class ProtocolBuilderJourneyDPublisher implements JourneyDProtocolPublisher {
  ProtocolBuilderJourneyDPublisher({
    required ProtocolBuilderService protocolBuilderService,
    required SessionLineageStore sessionLineageStore,
    this.publishTimeout = const Duration(seconds: 90),
  }) : _protocolBuilderService = protocolBuilderService,
       _sessionLineageStore = sessionLineageStore;

  final ProtocolBuilderService _protocolBuilderService;
  final SessionLineageStore _sessionLineageStore;
  final Duration publishTimeout;

  /// Marker programme version id for fixture-only drafts (not a hosted lookup).
  static const fixtureProgrammeVersionPlaceholder =
      's17-jd-adapt-fixture-programme-version';

  /// Canonical Journey D fixture session format for ProtocolBuilder drafts.
  static const fixtureSessionFormat = 'structured_strength';

  /// Builds the production ProtocolDraft for a fixture publication intent.
  ///
  /// Used by mutation-free preflight and by [publish] so both paths share one
  /// translation.
  static ProtocolDraft draftFor(JourneyDProtocolPublicationIntent intent) {
    final base = programmeSession(
      protocolId: intent.protocolId,
      name: 'S17 Journey D ${intent.role}',
      programmeVersionId: fixtureProgrammeVersionPlaceholder,
      ownerId: null,
      sessionFormat: fixtureSessionFormat,
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

  /// Mutation-free validation through the production builder invariants.
  void validateDraftLocally(ProtocolDraft draft) {
    _protocolBuilderService.validateDraft(draft);
  }

  @override
  Future<JourneyDProtocolPublicationResult> publish(
    JourneyDProtocolPublicationIntent intent,
  ) async {
    final draft = draftFor(intent);

    // Pre-network builder gate — definite source failure, not uncertain.
    try {
      validateDraftLocally(draft);
    } on ProtocolBuilderException catch (error) {
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.failed,
        detail: _redactBuilderDetail(
          'builder_validation',
          error.message,
        ),
        furtherMutationProhibited: true,
        writeAccounting: JourneyDWriteAccounting.preNetworkSourceFailure,
      );
    }

    var requestDispatched = false;
    try {
      requestDispatched = true;
      final save = await _protocolBuilderService
          .publishDraft(draft)
          .timeout(publishTimeout);
      if (!save.published || save.protocolId != intent.protocolId) {
        return JourneyDProtocolPublicationResult(
          intent: intent,
          state: JourneyDPublicationStageState.failed,
          detail: 'publishDraft_identity_or_published_flag_failed',
          furtherMutationProhibited: true,
          writeAccounting: JourneyDWriteAccounting(
            invocationAttempted: true,
            requestDispatched: true,
            responseReceived: true,
          ),
        );
      }

      final identity = await _sessionLineageStore
          .getRevisionIdentity(intent.protocolId)
          .timeout(publishTimeout);
      if (identity == null || identity.sessionLineageId.trim().isEmpty) {
        return JourneyDProtocolPublicationResult(
          intent: intent,
          state: JourneyDPublicationStageState.unknown,
          detail: 'lineage_lookup_missing_after_publish',
          furtherMutationProhibited: true,
          writeAccounting: const JourneyDWriteAccounting(
            invocationAttempted: true,
            requestDispatched: true,
            responseReceived: true,
            mutationConfirmed: true,
            outcomeUncertain: true,
          ),
        );
      }

      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.applied,
        returnedSessionLineageId: identity.sessionLineageId,
        returnedRevisionNumber: identity.revisionNumber,
        detail: 'ProtocolBuilderService.publishDraft',
        writeAccounting: JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          responseReceived: true,
          mutationConfirmed: true,
          objectObservedPostAttempt: true,
        ),
      );
    } on TimeoutException {
      // publishDraft may have already mutated — never report as definite miss.
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.unknown,
        detail: 'publishDraft_timed_out_dispatched',
        furtherMutationProhibited: true,
        writeAccounting: JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: requestDispatched,
          outcomeUncertain: true,
        ),
      );
    } on ProtocolBuilderException catch (error) {
      // Validation already passed; this is adapter/persistence after dispatch.
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.unknown,
        detail: _redactBuilderDetail(
          'publishDraft_adapter_error',
          error.message,
        ),
        furtherMutationProhibited: true,
        writeAccounting: JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          outcomeUncertain: true,
        ),
      );
    } on Object catch (error) {
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.failed,
        detail: 'publishDraft_exception:${error.runtimeType}',
        furtherMutationProhibited: true,
        writeAccounting: JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: requestDispatched,
          outcomeUncertain: requestDispatched,
        ),
      );
    }
  }

  static String _redactBuilderDetail(String prefix, String message) {
    var redacted = message.trim();
    redacted = redacted.replaceAll(
      RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
      '***email***',
    );
    redacted = redacted.replaceAll(
      RegExp(
        r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
        r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
      ),
      '***id***',
    );
    redacted = redacted.replaceAll(
      RegExp(r'(password|token|secret|apikey|api_key)\s*[:=]\s*\S+',
          caseSensitive: false),
      '***secret***',
    );
    if (redacted.length > 240) {
      redacted = '${redacted.substring(0, 240)}…';
    }
    return '$prefix:$redacted';
  }
}
