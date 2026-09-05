import '../../../models/timer_configuration.dart';
import '../../../models/workout_format.dart';
import '../../session/models/session_execution_plan.dart';
import '../models/interval_work_result.dart';
import '../models/performance_result_data.dart';
import '../models/performance_snapshot.dart';

class IntervalCaptureContract {
  const IntervalCaptureContract._();

  static const paceTokens = {'interval_pace', 'pace_each_interval'};

  static bool tracksPerIntervalPace({
    required WorkoutFormat workoutFormat,
    TimerConfiguration? timer,
    Iterable<String> extraTokens = const [],
  }) {
    if (workoutFormat != WorkoutFormat.intervals &&
        workoutFormat != WorkoutFormat.tabata &&
        workoutFormat != WorkoutFormat.emom) {
      return false;
    }
    final tokens = <String>{
      ...?timer?.tracking,
      ...extraTokens,
    }.map((token) => token.trim()).where((token) => token.isNotEmpty);
    return tokens.any(paceTokens.contains);
  }

  static bool requiresPerIntervalRows(SessionExecutionBlock block) {
    return tracksPerIntervalPace(
      workoutFormat: block.workoutFormat,
      timer: block.timerConfiguration,
    );
  }

  static int? prescribedRounds(SessionExecutionBlock block) {
    return block.timerConfiguration?.rounds ??
        block.timerConfiguration?.targetRounds;
  }

  static int? workSeconds(SessionExecutionBlock block) {
    return block.timerConfiguration?.workSeconds ??
        block.timerConfiguration?.intervalSeconds;
  }

  static String comparisonFamily({
    required WorkoutFormat workoutFormat,
    required int? workSeconds,
    required String paceUnit,
    String modality = 'run',
  }) {
    final work = workSeconds == null ? 'unknown' : '${workSeconds}s';
    return '${workoutFormat.dbValue}:$modality:$work:$paceUnit';
  }

  static String familyLabel({required int? workSeconds}) {
    if (workSeconds == null || workSeconds <= 0) {
      return 'Interval best';
    }
    if (workSeconds % 60 == 0) {
      final minutes = workSeconds ~/ 60;
      return '$minutes-minute interval best';
    }
    return '$workSeconds-second interval best';
  }

  static IntervalResultData authoredResult(SessionExecutionBlock block) {
    final rounds = prescribedRounds(block);
    final work = workSeconds(block);
    final unit = IntervalPaceUnit.secondsPerKm;
    final family = comparisonFamily(
      workoutFormat: block.workoutFormat,
      workSeconds: work,
      paceUnit: unit,
    );
    if (!requiresPerIntervalRows(block) ||
        rounds == null ||
        rounds <= 0 ||
        work == null ||
        work <= 0) {
      return IntervalResultData(totalIntervals: rounds);
    }
    return IntervalResultData(
      totalIntervals: rounds,
      workSeconds: work,
      paceUnit: unit,
      comparisonFamily: family,
      intervals: List.generate(
        rounds,
        (index) => IntervalWorkResult(
          ordinal: index + 1,
          workSeconds: work,
          paceUnit: unit,
        ),
        growable: false,
      ),
    );
  }

  static bool snapshotTracksPerInterval(BlockPerformanceSnapshot snapshot) {
    return tracksPerIntervalPace(
      workoutFormat: snapshot.workoutFormat,
      extraTokens: snapshot.tracking,
    );
  }
}
