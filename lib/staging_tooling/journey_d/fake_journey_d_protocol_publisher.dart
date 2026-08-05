import 'package:cohort_platform/core/utils/database_uuid.dart';

import 'journey_d_protocol_publication.dart';
import 'journey_d_write_accounting.dart';

/// Local-only fake of [JourneyDProtocolPublisher] for B4d.21b tests.
///
/// Mimics the canonical publishDraft contract: success yields a UUID lineage
/// attributed by protocol_id. Never contacts a hosted environment.
class FakeJourneyDProtocolPublisher implements JourneyDProtocolPublisher {
  FakeJourneyDProtocolPublisher({
    Map<String, String>? lineageByProtocolId,
    this.failProtocolIds = const {},
    this.ambiguousProtocolIds = const {},
    this.wrongProtocolIdReturns = const {},
    this.malformedLineageByProtocolId = const {},
    this.wrongRevisionByProtocolId = const {},
  }) : lineageByProtocolId = Map.unmodifiable(lineageByProtocolId ?? const {});

  /// protocol_id → canonical session_lineage_id UUID
  final Map<String, String> lineageByProtocolId;
  final Set<String> failProtocolIds;
  final Set<String> ambiguousProtocolIds;

  /// protocol_id → wrong protocol_id claimed in result
  final Map<String, String> wrongProtocolIdReturns;

  /// protocol_id → non-UUID lineage string
  final Map<String, String> malformedLineageByProtocolId;

  /// protocol_id → unexpected revision
  final Map<String, int> wrongRevisionByProtocolId;

  final List<String> publishedProtocolIds = [];

  @override
  Future<JourneyDProtocolPublicationResult> publish(
    JourneyDProtocolPublicationIntent intent,
  ) async {
    publishedProtocolIds.add(intent.protocolId);

    if (failProtocolIds.contains(intent.protocolId)) {
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.failed,
        detail: 'fake_publication_failed',
        furtherMutationProhibited: true,
        writeAccounting: const JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          responseReceived: true,
        ),
      );
    }
    if (ambiguousProtocolIds.contains(intent.protocolId)) {
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.unknown,
        detail: 'fake_publication_ambiguous',
        furtherMutationProhibited: true,
        writeAccounting: const JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          outcomeUncertain: true,
        ),
      );
    }

    final malformed = malformedLineageByProtocolId[intent.protocolId];
    if (malformed != null) {
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.applied,
        returnedSessionLineageId: malformed,
        returnedRevisionNumber: intent.revisionNumber,
        detail: 'fake_malformed_lineage',
        writeAccounting: const JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          responseReceived: true,
          mutationConfirmed: true,
        ),
      );
    }

    final lineage = lineageByProtocolId[intent.protocolId];
    if (lineage == null) {
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.failed,
        detail: 'fake_missing_lineage_mapping',
        furtherMutationProhibited: true,
        writeAccounting: const JourneyDWriteAccounting(
          invocationAttempted: true,
        ),
      );
    }
    if (!DatabaseUuid.isValidDatabaseUuid(lineage)) {
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.failed,
        detail: 'fake_configured_non_uuid',
        furtherMutationProhibited: true,
        writeAccounting: const JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          responseReceived: true,
        ),
      );
    }

    final claimedProtocol =
        wrongProtocolIdReturns[intent.protocolId] ?? intent.protocolId;
    // Attribution is by intent.protocolId correlation; a wrong claimed id is
    // represented by returning applied with lineage but pipeline validates
    // protocol identity separately via intent (publisher must not rewrite intent).
    if (claimedProtocol != intent.protocolId) {
      return JourneyDProtocolPublicationResult(
        intent: intent,
        state: JourneyDPublicationStageState.failed,
        detail: 'fake_wrong_protocol_identity:$claimedProtocol',
        furtherMutationProhibited: true,
        writeAccounting: const JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: true,
          responseReceived: true,
        ),
      );
    }

    final revision =
        wrongRevisionByProtocolId[intent.protocolId] ?? intent.revisionNumber;

    return JourneyDProtocolPublicationResult(
      intent: intent,
      state: JourneyDPublicationStageState.applied,
      returnedSessionLineageId: lineage,
      returnedRevisionNumber: revision,
      detail: 'fake_publishDraft_ok',
      writeAccounting: const JourneyDWriteAccounting(
        invocationAttempted: true,
        requestDispatched: true,
        responseReceived: true,
        mutationConfirmed: true,
        objectObservedPostAttempt: true,
      ),
    );
  }
}
