import '../features/programme/models/programme_schedule_apply.dart';
import 's17_journey_diagnosis.dart';

/// Pure B4d.8 Undo diagnosis helpers — no hosted I/O.
///
/// Preserves the most specific safe typed repository/RPC status and code.
/// Does not invent a more specific classification without evidence.
class S17UndoApplyEvidence {
  const S17UndoApplyEvidence({
    required this.boundary,
    required this.classification,
    required this.detail,
    required this.applyReached,
    this.applyStatus,
    this.applyCode,
    this.expectedRevision,
    this.observedRevision,
    this.commandExpectedRevision,
    this.snapshotCursorBound = false,
    this.previewReady = false,
    this.commandBuilt = false,
    this.mutationMayHavePersisted = false,
    this.hostedPostStateKnown = false,
  });

  /// Earliest failed boundary label (safe, stable).
  final String boundary;
  final String classification;
  final String detail;
  final bool applyReached;
  final String? applyStatus;
  final String? applyCode;
  final int? expectedRevision;
  final int? observedRevision;
  final int? commandExpectedRevision;
  final bool snapshotCursorBound;
  final bool previewReady;
  final bool commandBuilt;
  final bool mutationMayHavePersisted;
  final bool hostedPostStateKnown;
}

/// Mandatory Skip inverse-snapshot keys (client + SQL contract).
class S17SkipInverseSchema {
  static const requiredKeys = <String>[
    'disposition_before',
    'outcome_existed_before',
    'outcome_status_before',
    'assignment_status_before',
    'assignment_completed_at_before',
    'cursor_before',
    'session_slot_id',
  ];

  static const cursorCoordinateKeys = <String>[
    'week_number',
    'day_key',
    'session_order',
  ];

  /// Returns missing top-level keys (and cursor coordinate gaps as
  /// `cursor_before.<key>`).
  static List<String> missingFields(Map<String, Object?> prior) {
    final missing = <String>[];
    for (final key in requiredKeys) {
      if (!prior.containsKey(key)) {
        missing.add(key);
      }
    }
    final cursor = prior['cursor_before'];
    if (cursor is Map) {
      final c = Map<String, Object?>.from(cursor);
      for (final key in cursorCoordinateKeys) {
        if (!c.containsKey(key) || c[key] == null) {
          missing.add('cursor_before.$key');
        }
      }
    } else if (prior.containsKey('cursor_before')) {
      missing.add('cursor_before.object');
    }
    return List.unmodifiable(missing);
  }

  static bool isComplete(Map<String, Object?> prior) =>
      missingFields(prior).isEmpty;
}

class S17UndoDiagnosis {
  static const classHarnessRecordSelection = 'HARNESS_UNDO_RECORD_SELECTION';
  static const classHarnessIdentityCorrelation =
      'HARNESS_UNDO_IDENTITY_CORRELATION';
  static const classHarnessInverseDecode = 'HARNESS_INVERSE_DECODE';
  static const classHarnessIncompleteInverse = 'HARNESS_INCOMPLETE_INVERSE';
  static const classHarnessRequestConstruction = 'HARNESS_REQUEST_CONSTRUCTION';
  static const classHarnessExpectedRevision = 'HARNESS_EXPECTED_REVISION';
  static const classHarnessTypedResultCollapsed =
      'HARNESS_TYPED_RESULT_COLLAPSED';
  static const classHarnessPostconditionMismatch =
      'HARNESS_POSTCONDITION_MISMATCH';
  static const classProductSkipUndoSnapshot =
      'PRODUCT_SKIP_UNDO_SNAPSHOT_DEFECT';
  static const classProductUndoRequestContract =
      'PRODUCT_UNDO_REQUEST_CONTRACT_DEFECT';
  static const classProductUndoRevision = 'PRODUCT_UNDO_REVISION_DEFECT';
  static const classProductUndoIdentity = 'PRODUCT_UNDO_IDENTITY_DEFECT';
  static const classProductUndoRpcValidation =
      'PRODUCT_UNDO_RPC_VALIDATION_DEFECT';
  static const classProductUndoApply = 'PRODUCT_UNDO_APPLY_DEFECT';
  static const classProductUndoReconstruction =
      'PRODUCT_UNDO_RECONSTRUCTION_DEFECT';
  static const classExpectedUndoRejection = 'EXPECTED_UNDO_REJECTION';
  static const classPersistedStateInconsistency =
      'PERSISTED_STATE_INCONSISTENCY';
  static const classInsufficientEvidence = 'INSUFFICIENT_PRESERVED_EVIDENCE';

  /// Safe typed repository/RPC evidence labels (reporting surface).
  static const typedUndoApplied = 'undoApplied';
  static const typedNoUndoRecord = 'noUndoRecord';
  static const typedLatestNotReversible = 'latestRecordNotReversible';
  static const typedLatestNotSkip = 'latestRecordNotSkip';
  static const typedRecordIdentityMismatch = 'recordIdentityMismatch';
  static const typedIncompleteInverse = 'incompleteInverseSnapshot';
  static const typedUnsupportedInverse = 'unsupportedInverse';
  static const typedOccurrenceNotFound = 'occurrenceNotFound';
  static const typedOccurrenceIdentityMismatch = 'occurrenceIdentityMismatch';
  static const typedAssignmentMismatch = 'assignmentMismatch';
  static const typedVersionMismatch = 'versionMismatch';
  static const typedLineageMismatch = 'lineageMismatch';
  static const typedExpectedRevisionMismatch = 'expectedRevisionMismatch';
  static const typedCurrentRevisionMismatch = 'currentRevisionMismatch';
  static const typedAlreadyUndone = 'alreadyUndone';
  static const typedUndoRejected = 'undoRejected';
  static const typedRepositoryUnavailable = 'repositoryUnavailable';
  static const typedRpcTransportFailure = 'rpcTransportFailure';
  static const typedRpcMalformedResponse = 'rpcMalformedResponse';
  static const typedApplyStatusUnknown = 'applyStatusUnknown';
  static const typedApplySucceededReloadFailed = 'applySucceededReloadFailed';
  static const typedApplySucceededPostconditionFailed =
      'applySucceededPostconditionFailed';

  /// Opaque B4d.7 collapse that must never hide a known typed result.
  static bool isOpaqueCollapsedMessage(String detail) {
    final t = detail.trim().toLowerCase();
    if (t.contains('status=') || t.contains('code=')) return false;
    return t.contains('apply unsuccessful');
  }

  /// Map a known apply status/code into a stable typed evidence label.
  static String typedLabelFromApply({
    required String? applyStatus,
    required String? applyCode,
  }) {
    final status = (applyStatus ?? '').trim();
    final code = (applyCode ?? '').trim();
    if (status.isEmpty && code.isEmpty) return typedApplyStatusUnknown;
    if (status == ProgrammeScheduleApplyStatus.applied.name ||
        status == 'applied' ||
        status == ProgrammeScheduleApplyStatus.alreadyApplied.name ||
        status == 'already_applied') {
      return typedUndoApplied;
    }
    switch (code) {
      case 'operation_not_found':
        return typedNoUndoRecord;
      case 'operation_not_undoable':
        return typedLatestNotReversible;
      case 'incomplete_inverse_snapshot':
        return typedIncompleteInverse;
      case 'undo_already_consumed':
        return typedAlreadyUndone;
      case 'occurrence_not_found':
        return typedOccurrenceNotFound;
      case 'stale_schedule_revision':
        return typedCurrentRevisionMismatch;
      case 'stale_preview_fingerprint':
        return typedUndoRejected;
      case 'provenance_mismatch':
        return typedAssignmentMismatch;
      case 'undo_unavailable':
      case 'undo_expired':
      case 'undo_after_state_mismatch':
      case 'undo_state_drift':
        return typedUndoRejected;
      case 'malformed_request':
        return typedRpcMalformedResponse;
      default:
        break;
    }
    if (status == ProgrammeScheduleApplyStatus.stalePreviewFingerprint.name ||
        status == 'stalePreviewFingerprint') {
      return typedUndoRejected;
    }
    if (status == ProgrammeScheduleApplyStatus.staleScheduleRevision.name ||
        status == 'staleScheduleRevision') {
      return typedCurrentRevisionMismatch;
    }
    if (status == ProgrammeScheduleApplyStatus.incompleteInverseSnapshot.name ||
        status == 'incompleteInverseSnapshot') {
      return typedIncompleteInverse;
    }
    // Generic failed status with no code stays explicitly unknown.
    if ((status == ProgrammeScheduleApplyStatus.failed.name ||
            status == 'failed') &&
        code.isEmpty) {
      return typedApplyStatusUnknown;
    }
    return typedUndoRejected;
  }

  /// Authoritative expected revision for Undo apply after a successful Skip
  /// that advanced revision from [preSkipRevision] to [postSkipRevision].
  ///
  /// Contract: command binds `snapshot.projection.scheduleRevision`, which
  /// after I must equal the post-Skip / resulting revision.
  static int authoritativeExpectedRevision({
    required int preSkipRevision,
    required int postSkipRevision,
  }) {
    assert(postSkipRevision == preSkipRevision + 1);
    return postSkipRevision;
  }

  /// Distinguish harness revision selection mistakes without contacting RPC.
  static String classifyRevisionSelection({
    required int commandExpectedRevision,
    required int authoritativeCurrentRevision,
    required int sourceRevision,
    required int resultingRevision,
  }) {
    if (commandExpectedRevision == authoritativeCurrentRevision &&
        commandExpectedRevision == resultingRevision) {
      return 'revision_ok_current_post_skip';
    }
    if (commandExpectedRevision == sourceRevision &&
        commandExpectedRevision != authoritativeCurrentRevision) {
      return 'harness_used_source_revision';
    }
    if (commandExpectedRevision == resultingRevision &&
        commandExpectedRevision != authoritativeCurrentRevision) {
      return 'harness_used_resulting_but_current_diverged';
    }
    if ((commandExpectedRevision - authoritativeCurrentRevision).abs() == 1) {
      return 'off_by_one_revision';
    }
    return 'revision_mismatch_other';
  }

  /// B4d.7-shaped correlation: fresh Skip after cursor-aligned I.
  static S17UndoTargetCheck correlateFreshSkip({
    required String? latestOperationType,
    required String? latestOperationId,
    required int? latestBaseRevision,
    required int? latestResultRevision,
    required int expectedBaseRevision,
    required int expectedResultRevision,
    required String expectedSkippedSlotId,
    String? priorSnapshotSlotId,
    String? recordAssignmentId,
    String? expectedAssignmentId,
    String? recordVersionId,
    String? expectedVersionId,
    String? recordLineage,
    String? expectedLineage,
  }) {
    if (expectedAssignmentId != null &&
        recordAssignmentId != null &&
        recordAssignmentId.trim() != expectedAssignmentId.trim()) {
      return S17UndoTargetCheck(
        ok: false,
        detail:
            'LATEST_SKIP_IDENTITY_MISMATCH: assignment '
            '${S17JourneyDiagnosis.redactPrefix(recordAssignmentId)}',
        expectedOperationType: 'skip',
        observedOperationType: latestOperationType,
      );
    }
    if (expectedVersionId != null &&
        recordVersionId != null &&
        recordVersionId.trim() != expectedVersionId.trim()) {
      return S17UndoTargetCheck(
        ok: false,
        detail:
            'LATEST_SKIP_IDENTITY_MISMATCH: version '
            '${S17JourneyDiagnosis.redactPrefix(recordVersionId)}',
        expectedOperationType: 'skip',
        observedOperationType: latestOperationType,
      );
    }
    if (expectedLineage != null &&
        recordLineage != null &&
        recordLineage.trim() != expectedLineage.trim()) {
      return S17UndoTargetCheck(
        ok: false,
        detail: 'LATEST_SKIP_IDENTITY_MISMATCH: lineage mismatch',
        expectedOperationType: 'skip',
        observedOperationType: latestOperationType,
      );
    }
    return S17JourneyDiagnosis.requireFreshSkipUndoTarget(
      latestOperationType: latestOperationType,
      latestOperationId: latestOperationId,
      latestBaseRevision: latestBaseRevision,
      latestResultRevision: latestResultRevision,
      expectedBaseRevision: expectedBaseRevision,
      expectedResultRevision: expectedResultRevision,
      expectedSkippedSlotId: expectedSkippedSlotId,
      priorSnapshotSlotId: priorSnapshotSlotId,
    );
  }

  /// Classify Journey J Undo attempt with typed evidence preserved.
  static S17UndoApplyEvidence classifyAttempt({
    required bool hasUndoRecord,
    required bool latestIsSkip,
    required bool freshSkipCorrelated,
    required bool inverseDecodable,
    required bool inverseComplete,
    required bool previewReached,
    required bool previewReady,
    String? previewCode,
    required bool commandBuilt,
    required bool applyReached,
    bool? applySucceeded,
    String? applyStatus,
    String? applyCode,
    required bool reloadOk,
    required bool revisionRestored,
    required bool stateRestored,
    required bool snapshotCursorBound,
    int? commandExpectedRevision,
    int? authoritativeCurrentRevision,
    int? sourceRevision,
    int? resultingRevision,
    bool transportFailure = false,
    bool malformedResponse = false,
    bool unsupportedInverse = false,
  }) {
    if (!hasUndoRecord) {
      return const S17UndoApplyEvidence(
        boundary: 'fresh_skip_record_correlation',
        classification: classHarnessRecordSelection,
        detail: 'NO_UNDO_RECORD',
        applyReached: false,
      );
    }
    if (!latestIsSkip) {
      return const S17UndoApplyEvidence(
        boundary: 'fresh_skip_record_correlation',
        classification: classHarnessRecordSelection,
        detail: 'LATEST_NOT_SKIP',
        applyReached: false,
      );
    }
    if (!freshSkipCorrelated) {
      return const S17UndoApplyEvidence(
        boundary: 'fresh_skip_record_correlation',
        classification: classHarnessIdentityCorrelation,
        detail: 'LATEST_SKIP_IDENTITY_MISMATCH',
        applyReached: false,
      );
    }
    if (!inverseDecodable) {
      return const S17UndoApplyEvidence(
        boundary: 'inverse_snapshot_decoding',
        classification: classHarnessInverseDecode,
        detail: 'INVERSE_DECODE_FAILED',
        applyReached: false,
      );
    }
    if (!inverseComplete) {
      return const S17UndoApplyEvidence(
        boundary: 'inverse_snapshot_decoding',
        classification: classHarnessIncompleteInverse,
        detail: 'INCOMPLETE_INVERSE_SNAPSHOT',
        applyReached: false,
      );
    }
    if (unsupportedInverse) {
      return const S17UndoApplyEvidence(
        boundary: 'inverse_snapshot_decoding',
        classification: classExpectedUndoRejection,
        detail: 'UNSUPPORTED_INVERSE',
        applyReached: false,
      );
    }
    if (!previewReached) {
      return S17UndoApplyEvidence(
        boundary: 'undo_request_construction',
        classification: classHarnessRequestConstruction,
        detail: 'UNDO_PREVIEW_NOT_INVOKED cursor_bound=$snapshotCursorBound',
        applyReached: false,
        snapshotCursorBound: snapshotCursorBound,
      );
    }
    if (!previewReady) {
      return S17UndoApplyEvidence(
        boundary: 'undo_request_construction',
        classification: classHarnessRequestConstruction,
        detail:
            'UNDO_PREVIEW_NOT_READY code=${previewCode ?? 'unknown'} '
            'cursor_bound=$snapshotCursorBound',
        applyReached: false,
        previewReady: false,
        snapshotCursorBound: snapshotCursorBound,
      );
    }
    if (!commandBuilt) {
      return S17UndoApplyEvidence(
        boundary: 'undo_request_construction',
        classification: classHarnessRequestConstruction,
        detail: 'UNDO_COMMAND_UNAVAILABLE cursor_bound=$snapshotCursorBound',
        applyReached: false,
        previewReady: true,
        snapshotCursorBound: snapshotCursorBound,
      );
    }
    if (commandExpectedRevision != null &&
        authoritativeCurrentRevision != null &&
        sourceRevision != null &&
        resultingRevision != null) {
      final revClass = classifyRevisionSelection(
        commandExpectedRevision: commandExpectedRevision,
        authoritativeCurrentRevision: authoritativeCurrentRevision,
        sourceRevision: sourceRevision,
        resultingRevision: resultingRevision,
      );
      if (revClass != 'revision_ok_current_post_skip') {
        return S17UndoApplyEvidence(
          boundary: 'expected_revision_selection',
          classification: classHarnessExpectedRevision,
          detail:
              'REVISION_SELECTION=$revClass '
              'sent=$commandExpectedRevision '
              'authoritative=$authoritativeCurrentRevision '
              'source=$sourceRevision resulting=$resultingRevision',
          applyReached: false,
          previewReady: true,
          commandBuilt: true,
          commandExpectedRevision: commandExpectedRevision,
          expectedRevision: authoritativeCurrentRevision,
          snapshotCursorBound: snapshotCursorBound,
        );
      }
    }
    if (!applyReached) {
      return S17UndoApplyEvidence(
        boundary: 'repository_rpc_invocation',
        classification: classHarnessRequestConstruction,
        detail: 'UNDO_APPLY_NOT_INVOKED',
        applyReached: false,
        previewReady: true,
        commandBuilt: true,
        snapshotCursorBound: snapshotCursorBound,
        commandExpectedRevision: commandExpectedRevision,
      );
    }
    if (transportFailure) {
      return S17UndoApplyEvidence(
        boundary: 'repository_rpc_invocation',
        classification: classInsufficientEvidence,
        detail: 'RPC_TRANSPORT_FAILURE typed=$typedRpcTransportFailure',
        applyReached: true,
        previewReady: true,
        commandBuilt: true,
        applyStatus: applyStatus,
        applyCode: applyCode,
        mutationMayHavePersisted: true,
        hostedPostStateKnown: false,
        snapshotCursorBound: snapshotCursorBound,
      );
    }
    if (malformedResponse) {
      return S17UndoApplyEvidence(
        boundary: 'server_validation',
        classification: classInsufficientEvidence,
        detail: 'RPC_MALFORMED_RESPONSE typed=$typedRpcMalformedResponse',
        applyReached: true,
        previewReady: true,
        commandBuilt: true,
        applyStatus: applyStatus,
        applyCode: applyCode,
        mutationMayHavePersisted: true,
        hostedPostStateKnown: false,
        snapshotCursorBound: snapshotCursorBound,
      );
    }
    if (applySucceeded != true) {
      final typed = typedLabelFromApply(
        applyStatus: applyStatus,
        applyCode: applyCode,
      );
      final status = (applyStatus ?? '').trim();
      final code = (applyCode ?? '').trim();
      // B4d.7 collapsed path: apply invoked, unsuccessful, no typed code.
      if (status.isEmpty && code.isEmpty) {
        return S17UndoApplyEvidence(
          boundary: 'server_validation',
          classification: classInsufficientEvidence,
          detail:
              'UNDO_REJECTED typed=$typedApplyStatusUnknown '
              'cursor_bound=$snapshotCursorBound '
              '(B4d.7 collapsed apply unsuccessful; RPC code not preserved)',
          applyReached: true,
          previewReady: true,
          commandBuilt: true,
          snapshotCursorBound: snapshotCursorBound,
          commandExpectedRevision: commandExpectedRevision,
          mutationMayHavePersisted: true,
          hostedPostStateKnown: false,
        );
      }
      final fingerprintReject =
          code == 'stale_preview_fingerprint' ||
          status == ProgrammeScheduleApplyStatus.stalePreviewFingerprint.name ||
          status == 'stalePreviewFingerprint';
      if (fingerprintReject && !snapshotCursorBound) {
        return S17UndoApplyEvidence(
          boundary: 'server_validation',
          classification: classHarnessRequestConstruction,
          detail:
              'UNDO_REJECTED typed=$typed status=$status code=$code '
              'cursor_bound=false '
              '(null-cursor snapshot fingerprint vs live server cursor)',
          applyReached: true,
          previewReady: true,
          commandBuilt: true,
          applyStatus: status,
          applyCode: code,
          snapshotCursorBound: false,
          commandExpectedRevision: commandExpectedRevision,
          mutationMayHavePersisted: false,
          hostedPostStateKnown: true,
        );
      }
      final classification = fingerprintReject
          ? classProductUndoRpcValidation
          : (typed == typedIncompleteInverse
                ? classProductSkipUndoSnapshot
                : classProductUndoApply);
      return S17UndoApplyEvidence(
        boundary: 'server_validation',
        classification: classification,
        detail:
            'UNDO_REJECTED typed=$typed '
            'status=${status.isEmpty ? 'unknown' : status} '
            'code=${code.isEmpty ? 'none' : code} '
            'cursor_bound=$snapshotCursorBound',
        applyReached: true,
        previewReady: true,
        commandBuilt: true,
        applyStatus: status.isEmpty ? null : status,
        applyCode: code.isEmpty ? null : code,
        snapshotCursorBound: snapshotCursorBound,
        commandExpectedRevision: commandExpectedRevision,
        mutationMayHavePersisted: false,
        hostedPostStateKnown: true,
      );
    }
    if (!reloadOk) {
      return S17UndoApplyEvidence(
        boundary: 'projection_reconstruction',
        classification: classProductUndoReconstruction,
        detail:
            'APPLY_SUCCEEDED_RELOAD_FAILED '
            'typed=$typedApplySucceededReloadFailed '
            'status=${applyStatus ?? 'applied'} code=${applyCode ?? 'none'}',
        applyReached: true,
        previewReady: true,
        commandBuilt: true,
        applyStatus: applyStatus,
        applyCode: applyCode,
        mutationMayHavePersisted: true,
        hostedPostStateKnown: false,
        snapshotCursorBound: snapshotCursorBound,
      );
    }
    if (!revisionRestored || !stateRestored) {
      return S17UndoApplyEvidence(
        boundary: 'restoration_postcondition',
        classification: classHarnessPostconditionMismatch,
        detail:
            'APPLY_SUCCEEDED_POSTCONDITION_FAILED '
            'typed=$typedApplySucceededPostconditionFailed '
            'rev_ok=$revisionRestored state_ok=$stateRestored '
            'status=${applyStatus ?? 'applied'} code=${applyCode ?? 'none'}',
        applyReached: true,
        previewReady: true,
        commandBuilt: true,
        applyStatus: applyStatus,
        applyCode: applyCode,
        mutationMayHavePersisted: true,
        hostedPostStateKnown: true,
        snapshotCursorBound: snapshotCursorBound,
        expectedRevision: authoritativeCurrentRevision,
      );
    }
    return S17UndoApplyEvidence(
      boundary: 'restoration_postcondition',
      classification: typedUndoApplied,
      detail:
          'UNDO_APPLIED typed=$typedUndoApplied '
          'status=${applyStatus ?? 'applied'} code=${applyCode ?? 'none'}',
      applyReached: true,
      previewReady: true,
      commandBuilt: true,
      applyStatus: applyStatus,
      applyCode: applyCode,
      snapshotCursorBound: snapshotCursorBound,
      commandExpectedRevision: commandExpectedRevision,
      mutationMayHavePersisted: true,
      hostedPostStateKnown: true,
    );
  }

  /// Format Journey J failure detail — never collapse known typed results.
  static String formatFailureDetail({
    required S17UndoApplyEvidence evidence,
    String? journeyClass,
  }) {
    final cls = journeyClass ?? S17JourneyDiagnosis.undoClassRejected;
    final status = evidence.applyStatus;
    final code = evidence.applyCode;
    if (evidence.applyReached &&
        (status == null || status.isEmpty) &&
        (code == null || code.isEmpty)) {
      return '$cls typed=$typedApplyStatusUnknown '
          'apply_reached=true cursor_bound=${evidence.snapshotCursorBound} '
          'boundary=${evidence.boundary} '
          'classification=${evidence.classification} '
          '(collapsed_apply_unsuccessful_without_rpc_code)';
    }
    return '$cls typed=${typedLabelFromApply(applyStatus: status, applyCode: code)} '
        'status=${status ?? 'unknown'} code=${code ?? 'none'} '
        'apply_reached=${evidence.applyReached} '
        'cursor_bound=${evidence.snapshotCursorBound} '
        'boundary=${evidence.boundary} '
        'classification=${evidence.classification}';
  }

  /// Primary B4d.8 classification from preserved B4d.7 evidence + local proof.
  ///
  /// B4d.7 lost RPC status/code. Local proof: Journey J `reloadSnapshot()` omits
  /// cursor; Undo-Skip fingerprints live `cursorBefore`; server binds assignment
  /// cursor → `stale_preview_fingerprint` when client cursor is null after Skip.
  static String primaryClassificationForB4d7({
    required bool freshSkipCorrelated,
    required bool inverseComplete,
    required bool previewReady,
    required bool commandBuilt,
    required bool applyReached,
    required bool applySucceeded,
    String? preservedApplyStatus,
    String? preservedApplyCode,
    required bool journeyJReloadOmitsCursor,
  }) {
    if (!freshSkipCorrelated) return classHarnessIdentityCorrelation;
    if (!inverseComplete) return classHarnessIncompleteInverse;
    if (!previewReady || !commandBuilt) return classHarnessRequestConstruction;
    if (!applyReached) return classHarnessRequestConstruction;
    if (applySucceeded) return classHarnessPostconditionMismatch;
    final status = (preservedApplyStatus ?? '').trim();
    final code = (preservedApplyCode ?? '').trim();
    if (code == 'stale_preview_fingerprint' && journeyJReloadOmitsCursor) {
      return classHarnessRequestConstruction;
    }
    if (status.isEmpty && code.isEmpty && journeyJReloadOmitsCursor) {
      // Earliest locally provable causal defect matching ready→apply-fail.
      return classHarnessRequestConstruction;
    }
    if (status.isEmpty && code.isEmpty) {
      return classInsufficientEvidence;
    }
    return classProductUndoApply;
  }

  /// Secondary reporting weakness always present in B4d.7 J path.
  static const secondaryB4d7ReportingWeakness =
      classHarnessTypedResultCollapsed;
}
