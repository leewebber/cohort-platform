import '../models/fixed_programme_occurrence_projection.dart';
import '../models/future_programme_session_swap.dart';
import 'future_programme_session_swap_store.dart';

/// Application boundary for Train today → Swap and begin.
///
/// Does not rewrite fixtures, invent completions, or start a session before
/// the authenticated swap authority returns success.
class FutureProgrammeSessionSwapService {
  const FutureProgrammeSessionSwapService({required this.store});

  final FutureProgrammeSessionSwapStore store;

  Future<FutureProgrammeSessionSwapResult> swapAndBegin({
    required FixedProgrammeCalendarProjection calendar,
    required FixedProgrammeOccurrenceProjection selected,
  }) {
    final today = calendar.todayOccurrence;
    if (today == null || !calendar.canOfferFutureTrainTodaySwap(selected)) {
      return Future.value(
        const FutureProgrammeSessionSwapResult(
          status: FutureProgrammeSessionSwapStatus.rejected,
          code: 'swap_not_offered',
          message: 'A clean one-for-one swap is not available.',
        ),
      );
    }
    return store.swapAndBegin(
      FutureProgrammeSessionSwapCommand(
        assignmentId: calendar.assignmentId,
        todayOccurrenceId: today.occurrenceId,
        selectedOccurrenceId: selected.occurrenceId,
        expectedTodayDate: today.scheduledDate,
        expectedSelectedDate: selected.scheduledDate,
      ),
    );
  }
}
