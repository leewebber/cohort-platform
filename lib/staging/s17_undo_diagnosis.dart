import '../domain/programme_scheduling/models/programme_scheduling_snapshot.dart';
import '../domain/programme_scheduling/vocabulary/programme_schedule_disposition.dart';
import '../features/programme/models/programme_schedule_apply.dart';
import 's17_journey_diagnosis.dart';
import 's17_skip_diagnosis.dart';

/// Pure B4d.8/B4d.9 Undo diagnosis helpers — no hosted I/O.
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
    final rev = evidence.commandExpectedRevision;
    final revPart = rev == null ? '' : ' expected_revision=$rev';
    if (evidence.applyReached &&
        (status == null || status.isEmpty) &&
        (code == null || code.isEmpty)) {
      return '$cls typed=$typedApplyStatusUnknown '
          'apply_invoked=true apply_reached=true '
          'cursor_bound=${evidence.snapshotCursorBound}$revPart '
          'boundary=${evidence.boundary} '
          'classification=${evidence.classification} '
          '(collapsed_apply_unsuccessful_without_rpc_code)';
    }
    return '$cls typed=${typedLabelFromApply(applyStatus: status, applyCode: code)} '
        'status=${status ?? 'unknown'} code=${code ?? 'none'} '
        'apply_invoked=${evidence.applyReached} '
        'apply_reached=${evidence.applyReached} '
        'cursor_bound=${evidence.snapshotCursorBound}$revPart '
        'boundary=${evidence.boundary} '
        'classification=${evidence.classification}';
  }

  // --- B4d.9 live-cursor bind (product-parity, staging-only) ---

  static const cursorFailMissing = 'CURSOR_MISSING';
  static const cursorFailMalformed = 'CURSOR_MALFORMED';
  static const cursorFailUnresolvable = 'CURSOR_UNRESOLVABLE';
  static const cursorFailAmbiguous = 'CURSOR_AMBIGUOUS';
  static const cursorFailStale = 'CURSOR_STALE';
  static const cursorFailClosedClass = 'UNDO_CURSOR_BIND_FAILED';

  /// Resolve authoritative live assignment cursor coordinates to exactly one
  /// occurrence — same coordinate→slot rule as the product controller /
  /// Journey I (`S17SkipDiagnosis.resolveCursorSlotId`).
  ///
  /// Does not synthesize from first-uncompleted, undo-record slot, or
  /// inverse `cursor_before` alone.
  static S17UndoCursorBindResult resolveAuthoritativeLiveCursor({
    required List<S17SkipOccurrenceView> occurrences,
    required bool assignmentPresent,
    int? week,
    String? dayKey,
    int? sessionOrder,
    String? freshlySkippedSlotId,
  }) {
    if (!assignmentPresent) {
      return const S17UndoCursorBindResult(
        ok: false,
        reason: cursorFailMissing,
        detail: '$cursorFailClosedClass: $cursorFailMissing assignment',
      );
    }
    final day = dayKey?.trim() ?? '';
    if (week == null || day.isEmpty || sessionOrder == null) {
      return const S17UndoCursorBindResult(
        ok: false,
        reason: cursorFailMalformed,
        detail: '$cursorFailClosedClass: $cursorFailMalformed coordinates',
      );
    }
    final matches = occurrences
        .where(
          (o) =>
              o.weekNumber == week &&
              o.dayKey == day &&
              o.sessionOrder == sessionOrder,
        )
        .toList(growable: false);
    if (matches.isEmpty) {
      return const S17UndoCursorBindResult(
        ok: false,
        reason: cursorFailUnresolvable,
        detail: '$cursorFailClosedClass: $cursorFailUnresolvable',
      );
    }
    if (matches.length > 1) {
      return const S17UndoCursorBindResult(
        ok: false,
        reason: cursorFailAmbiguous,
        detail: '$cursorFailClosedClass: $cursorFailAmbiguous',
      );
    }
    final slot = matches.single.sessionSlotId.trim();
    if (slot.isEmpty) {
      return const S17UndoCursorBindResult(
        ok: false,
        reason: cursorFailUnresolvable,
        detail: '$cursorFailClosedClass: $cursorFailUnresolvable empty_slot',
      );
    }
    final skipped = freshlySkippedSlotId?.trim() ?? '';
    // Post-Skip cursor must have advanced off the skipped occurrence.
    if (skipped.isNotEmpty && slot == skipped) {
      return S17UndoCursorBindResult(
        ok: false,
        reason: cursorFailStale,
        detail:
            '$cursorFailClosedClass: $cursorFailStale '
            'still_on_skipped=${S17JourneyDiagnosis.redactPrefix(slot)}',
        cursorSessionSlotId: slot,
        week: week,
        dayKey: day,
        sessionOrder: sessionOrder,
      );
    }
    // Product-parity single-slot resolve (byte-identical rule to Journey I).
    final viaHelper = S17SkipDiagnosis.resolveCursorSlotId(
      occurrences: occurrences,
      week: week,
      dayKey: day,
      sessionOrder: sessionOrder,
    );
    if (viaHelper != slot) {
      return const S17UndoCursorBindResult(
        ok: false,
        reason: cursorFailAmbiguous,
        detail: '$cursorFailClosedClass: $cursorFailAmbiguous helper_mismatch',
      );
    }
    return S17UndoCursorBindResult(
      ok: true,
      reason: 'CURSOR_BOUND',
      detail:
          'Live cursor bound slot=${S17JourneyDiagnosis.redactPrefix(slot)} '
          'week=$week day=$day order=$sessionOrder',
      cursorSessionSlotId: slot,
      week: week,
      dayKey: day,
      sessionOrder: sessionOrder,
    );
  }

  /// Bind a validated cursor into a scheduling snapshot (immutable copy).
  static ProgrammeSchedulingSnapshot bindCursor({
    required ProgrammeSchedulingSnapshot snapshot,
    required String cursorSessionSlotId,
  }) {
    return ProgrammeSchedulingSnapshot(
      assignmentId: snapshot.assignmentId,
      programmeVersionId: snapshot.programmeVersionId,
      packageContentHash: snapshot.packageContentHash,
      timezone: snapshot.timezone,
      startedAt: snapshot.startedAt,
      today: snapshot.today,
      assignmentStatus: snapshot.assignmentStatus,
      projection: snapshot.projection,
      schedulingHorizonEnd: snapshot.schedulingHorizonEnd,
      preparedProgrammedSessionKeys: snapshot.preparedProgrammedSessionKeys,
      adaptedProgrammedSessionKeys: snapshot.adaptedProgrammedSessionKeys,
      pendingAdaptationProposalKeys: snapshot.pendingAdaptationProposalKeys,
      consumedAdaptationProposalIds: snapshot.consumedAdaptationProposalIds,
      cursorSessionSlotId: cursorSessionSlotId,
      policyVersion: snapshot.policyVersion,
    );
  }

  /// True when [proposedSlotId] illegally uses first-uncompleted instead of
  /// the authoritative live cursor.
  static bool isIllegalFirstUncompletedSubstitution({
    required String authoritativeCursorSlotId,
    required String? firstUncompletedSlotId,
    required String? proposedSlotId,
  }) {
    final auth = authoritativeCursorSlotId.trim();
    final first = firstUncompletedSlotId?.trim() ?? '';
    final proposed = proposedSlotId?.trim() ?? '';
    if (auth.isEmpty || proposed.isEmpty) return false;
    if (proposed == auth) return false;
    return first.isNotEmpty && proposed == first;
  }

  /// True when [proposedSlotId] illegally uses the undo-record prior slot
  /// instead of the authoritative live post-Skip cursor.
  static bool isIllegalUndoRecordSlotSubstitution({
    required String authoritativeCursorSlotId,
    required String? priorSnapshotSlotId,
    required String? proposedSlotId,
  }) {
    final auth = authoritativeCursorSlotId.trim();
    final prior = priorSnapshotSlotId?.trim() ?? '';
    final proposed = proposedSlotId?.trim() ?? '';
    if (auth.isEmpty || proposed.isEmpty) return false;
    if (proposed == auth) return false;
    return prior.isNotEmpty && proposed == prior;
  }

  /// Post-Skip expected disposition of the skipped occurrence.
  static bool isPostSkipDisposition(ProgrammeScheduleDisposition d) =>
      d == ProgrammeScheduleDisposition.skipped;

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

  /// Product Undo revision contract:
  /// `Athlete_Controlled_Programme_Scheduling_v1` +
  /// `apply_programme_schedule_undo` (`v_result_rev := v_expected_rev + 1`).
  ///
  /// Undo restores logical schedule state through a **new** authoritative
  /// schedule revision (`N→N+1`). The post-Undo revision identifier must not
  /// be required to equal the pre-Skip revision.
  static S17UndoRevisionContractEvaluation evaluateRevisionContract({
    required int preSkipRevision,
    required int postSkipRevision,
    required int expectedApplyRevision,
    int? applyResultRevision,
    int? reloadedRevision,
  }) {
    final expectedApplyOk = expectedApplyRevision == postSkipRevision;
    final resultingPresent = applyResultRevision != null;
    final resultingMatchesContract =
        resultingPresent && applyResultRevision == expectedApplyRevision + 1;
    final reloadMatchesResult =
        reloadedRevision != null &&
        applyResultRevision != null &&
        reloadedRevision == applyResultRevision;
    // Guard against the legacy rewind postcondition being treated as success.
    final legacyRewindWouldPass =
        reloadedRevision != null && reloadedRevision == preSkipRevision;
    final ok =
        expectedApplyOk &&
        resultingPresent &&
        resultingMatchesContract &&
        reloadMatchesResult;
    return S17UndoRevisionContractEvaluation(
      ok: ok,
      expectedApplyOk: expectedApplyOk,
      resultingRevisionPresent: resultingPresent,
      resultingMatchesContract: resultingMatchesContract,
      reloadMatchesResult: reloadMatchesResult,
      legacyRewindWouldPass: legacyRewindWouldPass,
      preSkipRevision: preSkipRevision,
      postSkipRevision: postSkipRevision,
      expectedApplyRevision: expectedApplyRevision,
      applyResultRevision: applyResultRevision,
      reloadedRevision: reloadedRevision,
      contractResultRevision: expectedApplyRevision + 1,
    );
  }

  /// Aggregate post-J restoration comparisons (non-short-circuiting).
  ///
  /// Null comparison fields mean unavailable/not evaluated (e.g. reload or
  /// reconstruction failed). They do not count as restoration success.
  static S17UndoPostconditionEvaluation evaluatePostUndoPostconditions({
    required bool applySucceeded,
    required bool reloadOk,
    required bool reconstructionOk,
    required S17UndoRevisionContractEvaluation revision,
    required Map<String, String> preIBaseline,
    required String targetSlotId,
    required String? preICursorSlotId,
    required String? postJCursorSlotId,
    required String expectedAssignmentId,
    required String expectedVersionId,
    required String expectedLineageCode,
    required String? observedAssignmentId,
    required String? observedVersionId,
    required String? observedLineageCode,
    Map<String, String>? postJBaseline,
  }) {
    bool? targetIdentity;
    bool? targetDisposition;
    bool? targetDate;
    bool? targetReversible;
    bool? cursorRestored;
    bool? unrelated;
    bool? assignmentOk;
    bool? versionOk;
    bool? lineageOk;

    if (reloadOk && reconstructionOk && postJBaseline != null) {
      final expectedTarget = preIBaseline[targetSlotId];
      final observedTarget = postJBaseline[targetSlotId];
      targetIdentity = observedTarget != null && expectedTarget != null;
      if (expectedTarget != null && observedTarget != null) {
        final expParts = expectedTarget.split('|');
        final obsParts = observedTarget.split('|');
        final expDate = expParts.isNotEmpty ? expParts[0] : '';
        final expDisp = expParts.length > 1 ? expParts[1] : '';
        final obsDate = obsParts.isNotEmpty ? obsParts[0] : '';
        final obsDisp = obsParts.length > 1 ? obsParts[1] : '';
        targetDate = expDate == obsDate;
        targetDisposition = expDisp == obsDisp;
        targetReversible = expectedTarget == observedTarget;
      } else {
        targetDate = false;
        targetDisposition = false;
        targetReversible = false;
      }

      final preCursor = (preICursorSlotId ?? '').trim();
      final postCursor = (postJCursorSlotId ?? '').trim();
      cursorRestored =
          preCursor.isNotEmpty &&
          postCursor.isNotEmpty &&
          preCursor == postCursor;

      unrelated =
          preIBaseline.keys.every((id) {
            if (id == targetSlotId) return true;
            return postJBaseline[id] == preIBaseline[id];
          }) &&
          postJBaseline.keys.every((id) => preIBaseline.containsKey(id));

      assignmentOk =
          observedAssignmentId != null &&
          observedAssignmentId.trim() == expectedAssignmentId.trim();
      versionOk =
          observedVersionId != null &&
          observedVersionId.trim() == expectedVersionId.trim();
      lineageOk =
          observedLineageCode != null &&
          observedLineageCode.trim() == expectedLineageCode.trim();
    }

    final completeRestorationOk =
        targetIdentity == true &&
        targetDisposition == true &&
        targetDate == true &&
        targetReversible == true &&
        cursorRestored == true &&
        unrelated == true &&
        assignmentOk == true &&
        versionOk == true &&
        lineageOk == true;

    final journeyPass =
        applySucceeded &&
        reloadOk &&
        reconstructionOk &&
        revision.ok &&
        completeRestorationOk;

    return S17UndoPostconditionEvaluation(
      applySucceeded: applySucceeded,
      reloadOk: reloadOk,
      reconstructionOk: reconstructionOk,
      revision: revision,
      targetIdentityRestored: targetIdentity,
      targetDispositionRestored: targetDisposition,
      targetDateRestored: targetDate,
      targetReversibleStateRestored: targetReversible,
      cursorRestored: cursorRestored,
      unrelatedOccurrencesUnchanged: unrelated,
      assignmentIdentityUnchanged: assignmentOk,
      programmeVersionIdentityUnchanged: versionOk,
      lineageIdentityUnchanged: lineageOk,
      completeRestorationOk: completeRestorationOk,
      journeyJPass: journeyPass,
    );
  }
}

/// Product Undo N→N+1 revision-contract evaluation (harness-only).
class S17UndoRevisionContractEvaluation {
  const S17UndoRevisionContractEvaluation({
    required this.ok,
    required this.expectedApplyOk,
    required this.resultingRevisionPresent,
    required this.resultingMatchesContract,
    required this.reloadMatchesResult,
    required this.legacyRewindWouldPass,
    required this.preSkipRevision,
    required this.postSkipRevision,
    required this.expectedApplyRevision,
    required this.applyResultRevision,
    required this.reloadedRevision,
    required this.contractResultRevision,
  });

  final bool ok;
  final bool expectedApplyOk;
  final bool resultingRevisionPresent;
  final bool resultingMatchesContract;
  final bool reloadMatchesResult;
  final bool legacyRewindWouldPass;
  final int preSkipRevision;
  final int postSkipRevision;
  final int expectedApplyRevision;
  final int? applyResultRevision;
  final int? reloadedRevision;
  final int contractResultRevision;

  Map<String, Object?> toReportFields() => {
    'revision_contract_ok': ok,
    'pre_skip_revision': preSkipRevision,
    'post_skip_revision': postSkipRevision,
    'expected_apply_revision': expectedApplyRevision,
    'apply_result_revision': applyResultRevision,
    'reloaded_revision': reloadedRevision,
    'contract_result_revision': contractResultRevision,
    'expected_apply_ok': expectedApplyOk,
    'resulting_revision_present': resultingRevisionPresent,
    'resulting_matches_contract': resultingMatchesContract,
    'reload_matches_result': reloadMatchesResult,
    'legacy_rewind_would_pass': legacyRewindWouldPass,
  };
}

/// Aggregate Journey J post-Undo postconditions (non-short-circuiting).
class S17UndoPostconditionEvaluation {
  const S17UndoPostconditionEvaluation({
    required this.applySucceeded,
    required this.reloadOk,
    required this.reconstructionOk,
    required this.revision,
    required this.targetIdentityRestored,
    required this.targetDispositionRestored,
    required this.targetDateRestored,
    required this.targetReversibleStateRestored,
    required this.cursorRestored,
    required this.unrelatedOccurrencesUnchanged,
    required this.assignmentIdentityUnchanged,
    required this.programmeVersionIdentityUnchanged,
    required this.lineageIdentityUnchanged,
    required this.completeRestorationOk,
    required this.journeyJPass,
  });

  final bool applySucceeded;
  final bool reloadOk;
  final bool reconstructionOk;
  final S17UndoRevisionContractEvaluation revision;
  final bool? targetIdentityRestored;
  final bool? targetDispositionRestored;
  final bool? targetDateRestored;
  final bool? targetReversibleStateRestored;
  final bool? cursorRestored;
  final bool? unrelatedOccurrencesUnchanged;
  final bool? assignmentIdentityUnchanged;
  final bool? programmeVersionIdentityUnchanged;
  final bool? lineageIdentityUnchanged;
  final bool completeRestorationOk;
  final bool journeyJPass;

  /// `revisionRestored` compatibility alias for [classifyAttempt]: means
  /// revision **contract** ok, not pre-Skip revision rewind.
  bool get revisionContractOk => revision.ok;

  List<String> get failedPostconditions {
    final failed = <String>[];
    if (!applySucceeded) failed.add('apply_succeeded');
    if (!reloadOk) failed.add('reload_ok');
    if (!reconstructionOk) failed.add('reconstruction_ok');
    if (!revision.ok) failed.add('revision_contract_ok');
    void addBool(String name, bool? v) {
      if (v != true) failed.add(name);
    }

    addBool('target_identity_restored', targetIdentityRestored);
    addBool('target_disposition_restored', targetDispositionRestored);
    addBool('target_date_restored', targetDateRestored);
    addBool('target_reversible_state_restored', targetReversibleStateRestored);
    addBool('cursor_restored', cursorRestored);
    addBool('unrelated_occurrences_unchanged', unrelatedOccurrencesUnchanged);
    addBool('assignment_identity_unchanged', assignmentIdentityUnchanged);
    addBool(
      'programme_version_identity_unchanged',
      programmeVersionIdentityUnchanged,
    );
    addBool('lineage_identity_unchanged', lineageIdentityUnchanged);
    if (!completeRestorationOk) failed.add('complete_restoration_ok');
    return failed;
  }

  Map<String, Object?> toReportFields() => {
    ...revision.toReportFields(),
    'target_identity_restored': targetIdentityRestored,
    'target_disposition_restored': targetDispositionRestored,
    'target_date_restored': targetDateRestored,
    'target_reversible_state_restored': targetReversibleStateRestored,
    'cursor_restored': cursorRestored,
    'unrelated_occurrences_unchanged': unrelatedOccurrencesUnchanged,
    'assignment_identity_unchanged': assignmentIdentityUnchanged,
    'programme_version_identity_unchanged': programmeVersionIdentityUnchanged,
    'lineage_identity_unchanged': lineageIdentityUnchanged,
    'complete_restoration_ok': completeRestorationOk,
    'failed_postconditions': failedPostconditions.join(','),
  };

  String formatDetail({
    required String typed,
    required String applyStatus,
    required String applyCode,
    required bool applyInvoked,
    required bool cursorBound,
  }) {
    final fields = toReportFields().entries
        .map((e) => '${e.key}=${e.value}')
        .join(' ');
    return 'typed=$typed '
        'apply_status=$applyStatus apply_code=$applyCode '
        'apply_invoked=$applyInvoked cursor_bound=$cursorBound '
        '$fields';
  }
}

/// Result of B4d.9 authoritative live-cursor resolution for Journey J.
class S17UndoCursorBindResult {
  const S17UndoCursorBindResult({
    required this.ok,
    required this.reason,
    required this.detail,
    this.cursorSessionSlotId,
    this.week,
    this.dayKey,
    this.sessionOrder,
  });

  final bool ok;
  final String reason;
  final String detail;
  final String? cursorSessionSlotId;
  final int? week;
  final String? dayKey;
  final int? sessionOrder;
}
