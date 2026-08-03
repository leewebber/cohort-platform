import '../../../core/services/supabase_service.dart';
import '../models/programme_schedule_persistence.dart';
import 'programme_schedule_projection_store.dart';

/// Supabase adapter for [ensure_programme_schedule_projection].
///
/// Does not expose Move/Swap/Push/Skip apply. Does not provide a generic
/// projection writer.
class ProgrammeScheduleProjectionSupabaseStore
    implements ProgrammeScheduleProjectionStore {
  const ProgrammeScheduleProjectionSupabaseStore();

  static const _ensureRpc = 'ensure_programme_schedule_projection';

  @override
  Future<ProgrammeSchedulePersistenceResult> ensureBaseline({
    required String programmeAssignmentId,
  }) async {
    final trimmed = programmeAssignmentId.trim();
    if (trimmed.isEmpty) {
      return const ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.validationFailure,
        code: 'invalid_args',
        message: 'Assignment id is required.',
      );
    }

    try {
      final response = await SupabaseService.client.rpc(
        _ensureRpc,
        params: {'p_programme_assignment_id': trimmed},
      );

      if (response is Map<String, dynamic>) {
        return ProgrammeSchedulePersistenceResult.fromEnsureRpcMap(response);
      }
      if (response is Map) {
        return ProgrammeSchedulePersistenceResult.fromEnsureRpcMap(
          Map<String, dynamic>.from(response),
        );
      }

      return const ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.failed,
        code: 'unexpected_rpc_shape',
        message: 'Schedule projection could not be loaded.',
      );
    } catch (error) {
      return ProgrammeSchedulePersistenceResult(
        status: ProgrammeSchedulePersistenceStatus.persistenceUnavailable,
        code: 'client_error',
        message: _mapError(error),
      );
    }
  }

  String _mapError(Object error) {
    final text = error.toString();
    if (text.contains('JWT') || text.contains('not authenticated')) {
      return 'Sign in to load your programme schedule.';
    }
    if (text.contains('network') || text.contains('SocketException')) {
      return 'Network error. Check your connection and try again.';
    }
    return 'Schedule projection could not be loaded. Please try again.';
  }
}
