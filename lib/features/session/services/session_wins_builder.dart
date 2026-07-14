import '../../../models/exercise_progress_result.dart';
import '../../../models/interval_progress_result.dart';
import '../../../models/session_win.dart';
import '../models/interval_session_finish_summary.dart';
import '../models/strength_session_finish_summary.dart';

/// Builds prioritised [SessionWin] highlights from per-exercise progress results.
class SessionWinsBuilder {
  const SessionWinsBuilder();

  static const _maxWins = 5;

  List<SessionWin> build(StrengthSessionFinishSummary summary) {
    final wins = <SessionWin>[];

    for (final exercise in summary.exercises) {
      final result = exercise.progressResult;
      if (result == null) {
        continue;
      }

      final win = _winFromProgress(
        exerciseName: exercise.exerciseName,
        result: result,
      );

      if (win != null) {
        wins.add(win);
      }
    }

    if (summary.endedEarly) {
      wins.add(
        const SessionWin(
          type: SessionWinType.completedAsPlanned,
          title: 'Completed the work that was available today.',
          message: 'You logged meaningful work before ending the session.',
        ),
      );
    }

    wins.sort(
      (left, right) => _priority(right.type).compareTo(_priority(left.type)),
    );

    if (wins.isEmpty) {
      return const [
        SessionWin(
          type: SessionWinType.completedAsPlanned,
          title: 'Session completed as programmed',
          message: 'You moved through today\'s plan with focus and intent.',
        ),
      ];
    }

    return wins.take(_maxWins).toList(growable: false);
  }

  List<SessionWin> buildInterval(IntervalSessionFinishSummary summary) {
    final wins = <SessionWin>[];

    final progress = summary.progressResult;
    if (progress != null) {
      final win = _winFromIntervalProgress(progress);
      if (win != null) {
        wins.add(win);
      }
    }

    if (summary.endedEarly) {
      wins.add(
        const SessionWin(
          type: SessionWinType.completedAsPlanned,
          title: 'Completed the work that was available today.',
          message: 'You logged meaningful work before ending the session.',
        ),
      );
    }

    if (wins.isEmpty) {
      return const [
        SessionWin(
          type: SessionWinType.completedAsPlanned,
          title: 'Session completed as programmed',
          message: 'You moved through today\'s plan with focus and intent.',
        ),
      ];
    }

    return wins.take(_maxWins).toList(growable: false);
  }

  SessionWin? _winFromIntervalProgress(IntervalProgressResult result) {
    switch (result.progressType) {
      case IntervalProgressType.insufficientData:
        return SessionWin(
          type: SessionWinType.completedAsPlanned,
          title: result.headline,
          message: result.message,
          supportingDetail:
              result.reasons.isNotEmpty ? result.reasons.first : null,
        );
      case IntervalProgressType.mixedResult:
        return SessionWin(
          type: SessionWinType.completedAsPlanned,
          title: result.headline,
          message: result.message,
          supportingDetail:
              result.reasons.isNotEmpty ? result.reasons.first : null,
        );
      case IntervalProgressType.averagePaceImproved:
        return _intervalWin(
          type: SessionWinType.paceProgress,
          headline: result.headline,
          result: result,
        );
      case IntervalProgressType.consistencyImproved:
        return _intervalWin(
          type: SessionWinType.consistency,
          headline: result.headline,
          result: result,
        );
      case IntervalProgressType.effortImproved:
        return _intervalWin(
          type: SessionWinType.rpeProgress,
          headline: result.headline,
          result: result,
        );
      case IntervalProgressType.moreWorkCompleted:
        return _intervalWin(
          type: SessionWinType.repProgress,
          headline: result.headline,
          result: result,
        );
      case IntervalProgressType.firstPerformance:
        return _intervalWin(
          type: SessionWinType.firstPerformance,
          headline: result.headline,
          result: result,
        );
      case IntervalProgressType.matchedPerformance:
        return _intervalWin(
          type: SessionWinType.matchedPerformance,
          headline: result.headline,
          result: result,
        );
    }
  }

  SessionWin _intervalWin({
    required SessionWinType type,
    required String headline,
    required IntervalProgressResult result,
  }) {
    return SessionWin(
      type: type,
      title: headline,
      message: result.message,
      supportingDetail: result.reasons.isNotEmpty ? result.reasons.first : null,
    );
  }

  SessionWin? _winFromProgress({
    required String exerciseName,
    required ExerciseProgressResult result,
  }) {
    switch (result.progressType) {
      case ExerciseProgressType.mixedResult:
      case ExerciseProgressType.insufficientData:
        return null;
      case ExerciseProgressType.loadProgress:
        return _exerciseWin(
          exerciseName: exerciseName,
          type: SessionWinType.loadProgress,
          headline: 'Load increased.',
          result: result,
        );
      case ExerciseProgressType.repProgress:
        return _exerciseWin(
          exerciseName: exerciseName,
          type: SessionWinType.repProgress,
          headline: 'More total reps.',
          result: result,
        );
      case ExerciseProgressType.volumeProgress:
        return _exerciseWin(
          exerciseName: exerciseName,
          type: SessionWinType.volumeProgress,
          headline: 'Total volume increased.',
          result: result,
        );
      case ExerciseProgressType.rpeProgress:
        return _exerciseWin(
          exerciseName: exerciseName,
          type: SessionWinType.rpeProgress,
          headline: 'Same work at lower effort.',
          result: result,
        );
      case ExerciseProgressType.firstPerformance:
        return _exerciseWin(
          exerciseName: exerciseName,
          type: SessionWinType.firstPerformance,
          headline: 'First recorded performance.',
          result: result,
        );
      case ExerciseProgressType.matchedPerformance:
        final improvedEfficiency =
            result.message.toLowerCase().contains('improved efficiency');

        return _exerciseWin(
          exerciseName: exerciseName,
          type: improvedEfficiency
              ? SessionWinType.consistency
              : SessionWinType.matchedPerformance,
          headline: improvedEfficiency
              ? 'Performance matched with improved efficiency.'
              : 'Performance matched — strong consistency.',
          result: result,
        );
    }
  }

  SessionWin _exerciseWin({
    required String exerciseName,
    required SessionWinType type,
    required String headline,
    required ExerciseProgressResult result,
  }) {
    return SessionWin(
      type: type,
      title: '$exerciseName — $headline',
      message: result.message,
      exerciseName: exerciseName,
      supportingDetail: result.reasons.isNotEmpty ? result.reasons.first : null,
    );
  }

  int _priority(SessionWinType type) {
    return switch (type) {
      SessionWinType.loadProgress => 100,
      SessionWinType.paceProgress => 95,
      SessionWinType.repProgress => 90,
      SessionWinType.volumeProgress => 80,
      SessionWinType.rpeProgress => 70,
      SessionWinType.matchedPerformance => 60,
      SessionWinType.consistency => 55,
      SessionWinType.firstPerformance => 50,
      SessionWinType.recoveryDecision => 40,
      SessionWinType.completedAsPlanned => 10,
    };
  }
}
