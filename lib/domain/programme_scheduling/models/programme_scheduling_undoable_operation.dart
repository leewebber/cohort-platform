import '../vocabulary/programme_scheduling_operation_type.dart';

/// Authoritative undoable scheduling operation loaded for compute-only Undo
/// preview (Sprint 1.7F). Inverse values come from the durable operation log,
/// never from client-authored rows.
class ProgrammeSchedulingUndoableOperation {
  const ProgrammeSchedulingUndoableOperation({
    required this.operationId,
    required this.assignmentId,
    required this.originalType,
    required this.resultRevision,
    required this.baseRevision,
    required this.operatedAt,
    required this.undoExpiresAt,
    required this.priorSnapshot,
    this.undoConsumedAt,
    this.undoInvalidatedAt,
    this.incompleteSnapshot = false,
    this.ineligibilityDetail,
  });

  final String operationId;
  final String assignmentId;
  final ProgrammeSchedulingOperationType originalType;
  final int resultRevision;
  final int? baseRevision;
  final DateTime operatedAt;
  final DateTime? undoExpiresAt;
  final Map<String, Object?> priorSnapshot;
  final DateTime? undoConsumedAt;
  final DateTime? undoInvalidatedAt;
  final bool incompleteSnapshot;
  final String? ineligibilityDetail;

  bool get isStructurallyEligible {
    if (incompleteSnapshot) return false;
    if (undoConsumedAt != null) return false;
    if (undoInvalidatedAt != null) return false;
    if (undoExpiresAt == null) return false;
    if (!originalType.isUndoableMutation) return false;
    return true;
  }

  /// Client-side display helper; server uses `NOW() < undo_expires_at`.
  bool isExpiredAt(DateTime now) {
    final expires = undoExpiresAt;
    if (expires == null) return true;
    return !now.isBefore(expires);
  }
}

extension ProgrammeSchedulingUndoableOperationTypeX
    on ProgrammeSchedulingOperationType {
  bool get isUndoableMutation =>
      this == ProgrammeSchedulingOperationType.move ||
      this == ProgrammeSchedulingOperationType.swap ||
      this == ProgrammeSchedulingOperationType.push ||
      this == ProgrammeSchedulingOperationType.skip;
}
