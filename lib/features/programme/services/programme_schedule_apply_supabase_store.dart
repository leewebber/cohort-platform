import '../../../core/services/supabase_service.dart';
import '../models/programme_schedule_apply.dart';
import 'programme_schedule_apply_store.dart';

/// Supabase adapter for [apply_programme_schedule_operation] (Move/Swap only).
class ProgrammeScheduleApplySupabaseStore implements ProgrammeScheduleApplyStore {
  const ProgrammeScheduleApplySupabaseStore();

  static const _rpcName = 'apply_programme_schedule_operation';

  @override
  Future<ProgrammeScheduleApplyResult> apply(
    ProgrammeScheduleApplyCommand command,
  ) async {
    try {
      final response = await SupabaseService.client.rpc(
        _rpcName,
        params: {'payload': command.toRpcPayload()},
      );
      if (response is Map<String, dynamic>) {
        return ProgrammeScheduleApplyResult.fromRpcMap(response);
      }
      if (response is Map) {
        return ProgrammeScheduleApplyResult.fromRpcMap(
          Map<String, dynamic>.from(response),
        );
      }
      return const ProgrammeScheduleApplyResult(
        status: ProgrammeScheduleApplyStatus.failed,
        code: 'unexpected_rpc_shape',
        message: 'Schedule change could not be applied.',
      );
    } catch (error) {
      return ProgrammeScheduleApplyResult(
        status: ProgrammeScheduleApplyStatus.persistenceUnavailable,
        code: 'client_error',
        message: error.toString(),
      );
    }
  }
}
