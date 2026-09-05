import '../models/interval_work_result.dart';
import '../models/performance_result_data.dart';
import 'interval_pace_format.dart';

class IntervalResultMath {
  const IntervalResultMath._();

  static Iterable<IntervalWorkResult> comparableRows(
    IntervalResultData result,
  ) {
    return result.intervals.where((row) => row.hasValidPace);
  }

  static double? averagePaceSecondsPerKm(IntervalResultData result) {
    var time = 0.0;
    var distance = 0.0;
    for (final row in comparableRows(result)) {
      time += row.workSeconds;
      distance += row.impliedDistanceKm!;
    }
    if (distance <= 0 || time <= 0) return null;
    return time / distance;
  }

  static IntervalWorkResult? fastest(IntervalResultData result) {
    IntervalWorkResult? best;
    for (final row in comparableRows(result)) {
      if (best == null || row.paceSecondsPerKm! < best.paceSecondsPerKm!) {
        best = row;
      }
    }
    return best;
  }

  static IntervalWorkResult? slowest(IntervalResultData result) {
    IntervalWorkResult? worst;
    for (final row in comparableRows(result)) {
      if (worst == null || row.paceSecondsPerKm! > worst.paceSecondsPerKm!) {
        worst = row;
      }
    }
    return worst;
  }

  static double? paceSpreadSeconds(IntervalResultData result) {
    final quick = fastest(result)?.paceSecondsPerKm;
    final slow = slowest(result)?.paceSecondsPerKm;
    if (quick == null || slow == null) return null;
    return slow - quick;
  }

  static String formatPace(double? secondsPerKm) {
    return IntervalPaceFormat.display(secondsPerKm);
  }
}
