import '../../../core/services/supabase_service.dart';
import '../models/overdue_programme_recovery.dart';
import 'overdue_programme_recovery_store.dart';

class OverdueProgrammeRecoverySupabaseStore
    implements OverdueProgrammeRecoveryStore {
  const OverdueProgrammeRecoverySupabaseStore();

  static const rpcName = 'recover_overdue_fixed_programme_occurrence';

  @override
  Future<OverdueProgrammeRecoveryResult> recover(
    OverdueProgrammeRecoveryCommand command,
  ) async {
    try {
      final response = await SupabaseService.client.rpc(
        rpcName,
        params: {'payload': command.toRpcPayload()},
      );
      if (response is Map<String, dynamic>) {
        return OverdueProgrammeRecoveryResult.fromRpcMap(response);
      }
      if (response is Map) {
        return OverdueProgrammeRecoveryResult.fromRpcMap(
          Map<String, dynamic>.from(response),
        );
      }
      return const OverdueProgrammeRecoveryResult(
        status: OverdueProgrammeRecoveryStatus.failed,
        code: 'unexpected_rpc_shape',
      );
    } catch (_) {
      return OverdueProgrammeRecoveryResult(
        status: OverdueProgrammeRecoveryStatus.failed,
        code: 'client_error',
        message: OverdueProgrammeRecoveryResult.athleteVisibleMessageForCode(
          'client_error',
        ),
      );
    }
  }
}
