import '../../../core/services/supabase_service.dart';
import '../../../domain/programme_scheduling/programme_scheduling_domain.dart';
import 'programme_schedule_operations_store.dart';

/// SELECT-only adapter for scheduling operation log Undo eligibility.
class ProgrammeScheduleOperationsSupabaseStore
    implements ProgrammeScheduleOperationsStore {
  const ProgrammeScheduleOperationsSupabaseStore();

  @override
  Future<ProgrammeSchedulingUndoableOperation?> latestUndoableOperation({
    required String assignmentId,
  }) async {
    final rows = await SupabaseService.client
        .from('programme_schedule_operations')
        .select(
          'id, assignment_id, operation_type, base_revision, result_revision, '
          'prior_snapshot, operated_at, undo_expires_at, undo_consumed_at, '
          'undo_invalidated_at',
        )
        .eq('assignment_id', assignmentId)
        .inFilter('operation_type', ['move', 'swap', 'push', 'skip'])
        .order('result_revision', ascending: false)
        .limit(1);

    if (rows.isEmpty) return null;
    final row = Map<String, dynamic>.from(rows.first as Map);
    return _fromRow(row);
  }

  ProgrammeSchedulingUndoableOperation _fromRow(Map<String, dynamic> row) {
    final typeName = row['operation_type']?.toString() ?? '';
    final originalType = ProgrammeSchedulingOperationType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => ProgrammeSchedulingOperationType.undo,
    );
    final priorRaw = row['prior_snapshot'];
    final prior = <String, Object?>{};
    if (priorRaw is Map) {
      prior.addAll(Map<String, Object?>.from(priorRaw));
    }
    final incomplete = originalType == ProgrammeSchedulingOperationType.skip &&
        !(prior.containsKey('outcome_existed_before') &&
            prior.containsKey('outcome_status_before') &&
            prior.containsKey('assignment_status_before') &&
            prior.containsKey('assignment_completed_at_before') &&
            prior.containsKey('cursor_before') &&
            prior.containsKey('disposition_before'));

    return ProgrammeSchedulingUndoableOperation(
      operationId: row['id'].toString(),
      assignmentId: row['assignment_id'].toString(),
      originalType: originalType,
      resultRevision: _asInt(row['result_revision']) ?? -1,
      baseRevision: _asInt(row['base_revision']),
      operatedAt: DateTime.tryParse(row['operated_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      undoExpiresAt: DateTime.tryParse(row['undo_expires_at']?.toString() ?? ''),
      priorSnapshot: prior,
      undoConsumedAt: DateTime.tryParse(
        row['undo_consumed_at']?.toString() ?? '',
      ),
      undoInvalidatedAt: DateTime.tryParse(
        row['undo_invalidated_at']?.toString() ?? '',
      ),
      incompleteSnapshot: incomplete,
      ineligibilityDetail: incomplete
          ? 'Skip operation lacks a complete inverse snapshot.'
          : null,
    );
  }

  int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
