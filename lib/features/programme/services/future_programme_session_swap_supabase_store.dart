import '../../../core/services/supabase_service.dart';
import '../models/future_programme_session_swap.dart';
import 'future_programme_session_swap_store.dart';

/// Designated adapter for [swap_future_fixed_programme_session_and_begin].
class FutureProgrammeSessionSwapSupabaseStore
    implements FutureProgrammeSessionSwapStore {
  const FutureProgrammeSessionSwapSupabaseStore();

  static const rpcName = 'swap_future_fixed_programme_session_and_begin';

  @override
  Future<FutureProgrammeSessionSwapResult> swapAndBegin(
    FutureProgrammeSessionSwapCommand command,
  ) async {
    try {
      final response = await SupabaseService.client.rpc(
        rpcName,
        params: {'payload': command.toRpcPayload()},
      );
      if (response is Map<String, dynamic>) {
        return FutureProgrammeSessionSwapResult.fromRpcMap(response);
      }
      if (response is Map) {
        return FutureProgrammeSessionSwapResult.fromRpcMap(
          Map<String, dynamic>.from(response),
        );
      }
      return const FutureProgrammeSessionSwapResult(
        status: FutureProgrammeSessionSwapStatus.failed,
        code: 'unexpected_rpc_shape',
        message: 'This session could not be swapped safely.',
      );
    } catch (_) {
      return FutureProgrammeSessionSwapResult(
        status: FutureProgrammeSessionSwapStatus.failed,
        code: 'client_error',
        message: FutureProgrammeSessionSwapResult.athleteVisibleMessageForCode(
          'client_error',
        ),
      );
    }
  }
}
