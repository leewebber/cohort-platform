import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';

import 'value_objects/session_occurrence_audit_entry.dart';
import 'value_objects/session_occurrence_date.dart';
import 'value_objects/session_occurrence_reschedule_entry.dart';
import 'vocabulary/session_occurrence_completion_status.dart';
import 'vocabulary/session_occurrence_lifecycle_state.dart';
import 'session_occurrence_transition_result.dart';

/// A single scheduled workout on an athlete calendar — not the reusable definition.
class SessionOccurrence {
  const SessionOccurrence({
    required this.occurrenceId,
    required this.sourceSessionId,
    required this.originalPlannedDate,
    required this.plannedDate,
    required this.currentDate,
    required this.lifecycleState,
    required this.completionStatus,
    required this.rescheduleHistory,
    required this.auditTrail,
    this.programmeAssignmentId,
    this.programmeSessionSlotId,
    this.executionSnapshot,
    this.completedAt,
    this.notes,
  });

  final String occurrenceId;
  final String sourceSessionId;

  /// References [ProgrammeAssignment.id] — no programme state duplicated.
  final String? programmeAssignmentId;

  /// References [ProgrammeVersionSessionSlot.id] / [ProgrammeSlotOutcome.sessionSlotId].
  final String? programmeSessionSlotId;
  final SessionOccurrenceDate originalPlannedDate;
  final SessionOccurrenceDate plannedDate;
  final SessionOccurrenceDate currentDate;
  final SessionOccurrenceLifecycleState lifecycleState;
  final SessionOccurrenceCompletionStatus completionStatus;
  final AdaptedSessionExecutionSnapshot? executionSnapshot;
  final DateTime? completedAt;
  final List<SessionOccurrenceRescheduleEntry> rescheduleHistory;
  final String? notes;
  final List<SessionOccurrenceAuditEntry> auditTrail;

  bool get isTerminal => lifecycleState.isTerminal;

  bool get hasAdaptation => executionSnapshot != null;

  bool get hasProgrammeSlotReference =>
      programmeAssignmentId != null && programmeSessionSlotId != null;

  factory SessionOccurrence.schedule({
    required String occurrenceId,
    required String sourceSessionId,
    required SessionOccurrenceDate plannedDate,
    SessionOccurrenceDate? currentDate,
    required DateTime recordedAt,
    String? notes,
  }) {
    if (occurrenceId.trim().isEmpty) {
      throw ArgumentError.value(
        occurrenceId,
        'occurrenceId',
        'must not be empty',
      );
    }
    if (sourceSessionId.trim().isEmpty) {
      throw ArgumentError.value(
        sourceSessionId,
        'sourceSessionId',
        'must not be empty',
      );
    }
    final resolvedCurrent = currentDate ?? plannedDate;
    return SessionOccurrence(
      occurrenceId: occurrenceId.trim(),
      sourceSessionId: sourceSessionId.trim(),
      programmeAssignmentId: null,
      programmeSessionSlotId: null,
      originalPlannedDate: plannedDate,
      plannedDate: plannedDate,
      currentDate: resolvedCurrent,
      lifecycleState: SessionOccurrenceLifecycleState.scheduled,
      completionStatus: SessionOccurrenceCompletionStatus.pending,
      rescheduleHistory: const [],
      auditTrail: [
        SessionOccurrenceAuditEntry(
          eventType: SessionOccurrenceAuditEventType.scheduled,
          recordedAt: recordedAt,
        ),
      ],
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
    );
  }

  SessionOccurrenceTransitionResult attachAdaptation({
    required AdaptedSessionExecutionSnapshot executionSnapshot,
    required DateTime recordedAt,
  }) {
    if (isTerminal) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.terminalState,
      );
    }
    if (!lifecycleState.allowsExecutionSnapshotAttachment) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.invalidLifecycleState,
        detail: lifecycleState.name,
      );
    }
    if (executionSnapshot.sourceProtocolId.trim() != sourceSessionId.trim()) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.snapshotSourceMismatch,
      );
    }

    final replacing = lifecycleState == SessionOccurrenceLifecycleState.adapted;
    return SessionOccurrenceTransitionResult.success(
      _copyWith(
        lifecycleState: SessionOccurrenceLifecycleState.adapted,
        executionSnapshot: executionSnapshot,
        auditTrail: [
          ...auditTrail,
          SessionOccurrenceAuditEntry(
            eventType: replacing
                ? SessionOccurrenceAuditEventType.adaptationReplaced
                : SessionOccurrenceAuditEventType.adaptationAttached,
            recordedAt: recordedAt,
            detail: executionSnapshot.snapshotId,
          ),
        ],
      ),
    );
  }

  SessionOccurrenceTransitionResult startInProgress({
    required DateTime recordedAt,
  }) {
    if (isTerminal) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.terminalState,
      );
    }
    return switch (lifecycleState) {
      SessionOccurrenceLifecycleState.scheduled ||
      SessionOccurrenceLifecycleState.adapted =>
        SessionOccurrenceTransitionResult.success(
          _copyWith(
            lifecycleState: SessionOccurrenceLifecycleState.inProgress,
            auditTrail: [
              ...auditTrail,
              SessionOccurrenceAuditEntry(
                eventType: SessionOccurrenceAuditEventType.started,
                recordedAt: recordedAt,
              ),
            ],
          ),
        ),
      _ => SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.invalidLifecycleState,
        detail: lifecycleState.name,
      ),
    };
  }

  SessionOccurrenceTransitionResult complete({required DateTime completedAt}) {
    if (lifecycleState != SessionOccurrenceLifecycleState.inProgress) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.invalidLifecycleState,
        detail: lifecycleState.name,
      );
    }
    return SessionOccurrenceTransitionResult.success(
      _copyWith(
        lifecycleState: SessionOccurrenceLifecycleState.completed,
        completionStatus: SessionOccurrenceCompletionStatus.completed,
        completedAt: completedAt,
        auditTrail: [
          ...auditTrail,
          SessionOccurrenceAuditEntry(
            eventType: SessionOccurrenceAuditEventType.completed,
            recordedAt: completedAt,
          ),
        ],
      ),
    );
  }

  SessionOccurrenceTransitionResult skip({
    required DateTime recordedAt,
    String? reason,
  }) {
    if (isTerminal) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.terminalState,
      );
    }
    return switch (lifecycleState) {
      SessionOccurrenceLifecycleState.scheduled ||
      SessionOccurrenceLifecycleState.adapted =>
        SessionOccurrenceTransitionResult.success(
          _copyWith(
            lifecycleState: SessionOccurrenceLifecycleState.skipped,
            completionStatus: SessionOccurrenceCompletionStatus.skipped,
            auditTrail: [
              ...auditTrail,
              SessionOccurrenceAuditEntry(
                eventType: SessionOccurrenceAuditEventType.skipped,
                recordedAt: recordedAt,
                detail: reason,
              ),
            ],
          ),
        ),
      _ => SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.invalidLifecycleState,
        detail: lifecycleState.name,
      ),
    };
  }

  SessionOccurrenceTransitionResult cancel({
    required DateTime recordedAt,
    String? reason,
  }) {
    if (isTerminal) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.terminalState,
      );
    }
    return switch (lifecycleState) {
      SessionOccurrenceLifecycleState.scheduled ||
      SessionOccurrenceLifecycleState.adapted ||
      SessionOccurrenceLifecycleState.inProgress =>
        SessionOccurrenceTransitionResult.success(
          _copyWith(
            lifecycleState: SessionOccurrenceLifecycleState.cancelled,
            completionStatus: SessionOccurrenceCompletionStatus.cancelled,
            auditTrail: [
              ...auditTrail,
              SessionOccurrenceAuditEntry(
                eventType: SessionOccurrenceAuditEventType.cancelled,
                recordedAt: recordedAt,
                detail: reason,
              ),
            ],
          ),
        ),
      _ => SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.invalidLifecycleState,
        detail: lifecycleState.name,
      ),
    };
  }

  SessionOccurrenceTransitionResult reschedule({
    required SessionOccurrenceDate toDate,
    required DateTime recordedAt,
    String? reason,
  }) {
    if (isTerminal) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.terminalState,
      );
    }
    if (lifecycleState == SessionOccurrenceLifecycleState.inProgress) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.invalidLifecycleState,
        detail: lifecycleState.name,
      );
    }
    if (toDate == plannedDate) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.invalidRescheduleTarget,
      );
    }

    final entry = SessionOccurrenceRescheduleEntry(
      fromDate: plannedDate,
      toDate: toDate,
      recordedAt: recordedAt,
      reason: reason,
    );

    return SessionOccurrenceTransitionResult.success(
      _copyWith(
        plannedDate: toDate,
        currentDate: toDate,
        rescheduleHistory: [...rescheduleHistory, entry],
        auditTrail: [
          ...auditTrail,
          SessionOccurrenceAuditEntry(
            eventType: SessionOccurrenceAuditEventType.rescheduled,
            recordedAt: recordedAt,
            detail: '$plannedDate→$toDate',
          ),
        ],
      ),
    );
  }

  SessionOccurrenceTransitionResult updateNotes({
    required String? notes,
    required DateTime recordedAt,
  }) {
    if (isTerminal) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.terminalState,
      );
    }
    final normalized = notes?.trim().isEmpty == true ? null : notes?.trim();
    return SessionOccurrenceTransitionResult.success(
      _copyWith(
        notes: normalized,
        auditTrail: [
          ...auditTrail,
          SessionOccurrenceAuditEntry(
            eventType: SessionOccurrenceAuditEventType.notesUpdated,
            recordedAt: recordedAt,
          ),
        ],
      ),
    );
  }

  SessionOccurrenceTransitionResult updateCurrentDate({
    required SessionOccurrenceDate currentDate,
    required DateTime recordedAt,
  }) {
    if (isTerminal) {
      return SessionOccurrenceTransitionResult.singleFailure(
        SessionOccurrenceTransitionIssueCode.terminalState,
      );
    }
    if (currentDate == this.currentDate) {
      return SessionOccurrenceTransitionResult.success(this);
    }
    return SessionOccurrenceTransitionResult.success(
      _copyWith(
        currentDate: currentDate,
        auditTrail: [
          ...auditTrail,
          SessionOccurrenceAuditEntry(
            eventType: SessionOccurrenceAuditEventType.currentDateUpdated,
            recordedAt: recordedAt,
          ),
        ],
      ),
    );
  }

  SessionOccurrence _copyWith({
    SessionOccurrenceDate? plannedDate,
    SessionOccurrenceDate? currentDate,
    SessionOccurrenceLifecycleState? lifecycleState,
    SessionOccurrenceCompletionStatus? completionStatus,
    AdaptedSessionExecutionSnapshot? executionSnapshot,
    DateTime? completedAt,
    List<SessionOccurrenceRescheduleEntry>? rescheduleHistory,
    String? notes,
    List<SessionOccurrenceAuditEntry>? auditTrail,
    String? programmeAssignmentId,
    String? programmeSessionSlotId,
  }) {
    return SessionOccurrence(
      occurrenceId: occurrenceId,
      sourceSessionId: sourceSessionId,
      programmeAssignmentId:
          programmeAssignmentId ?? this.programmeAssignmentId,
      programmeSessionSlotId:
          programmeSessionSlotId ?? this.programmeSessionSlotId,
      originalPlannedDate: originalPlannedDate,
      plannedDate: plannedDate ?? this.plannedDate,
      currentDate: currentDate ?? this.currentDate,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      completionStatus: completionStatus ?? this.completionStatus,
      executionSnapshot: executionSnapshot ?? this.executionSnapshot,
      completedAt: completedAt ?? this.completedAt,
      rescheduleHistory: rescheduleHistory ?? this.rescheduleHistory,
      notes: notes ?? this.notes,
      auditTrail: auditTrail ?? this.auditTrail,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionOccurrence &&
        other.occurrenceId == occurrenceId &&
        other.sourceSessionId == sourceSessionId &&
        other.programmeAssignmentId == programmeAssignmentId &&
        other.programmeSessionSlotId == programmeSessionSlotId &&
        other.originalPlannedDate == originalPlannedDate &&
        other.plannedDate == plannedDate &&
        other.currentDate == currentDate &&
        other.lifecycleState == lifecycleState &&
        other.completionStatus == completionStatus &&
        other.executionSnapshot == executionSnapshot &&
        other.completedAt == completedAt &&
        other.notes == notes &&
        _listEquals(other.rescheduleHistory, rescheduleHistory) &&
        _listEquals(other.auditTrail, auditTrail);
  }

  @override
  int get hashCode => Object.hash(
    occurrenceId,
    sourceSessionId,
    programmeAssignmentId,
    programmeSessionSlotId,
    originalPlannedDate,
    plannedDate,
    currentDate,
    lifecycleState,
    completionStatus,
    executionSnapshot,
    completedAt,
    notes,
    Object.hashAll(rescheduleHistory),
    Object.hashAll(auditTrail),
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
