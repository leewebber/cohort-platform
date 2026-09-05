import '../models/future_programme_session_swap.dart';

/// Persistence port for the authenticated future-session swap-and-begin RPC.
abstract class FutureProgrammeSessionSwapStore {
  Future<FutureProgrammeSessionSwapResult> swapAndBegin(
    FutureProgrammeSessionSwapCommand command,
  );
}
