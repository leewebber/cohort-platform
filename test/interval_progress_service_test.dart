import 'package:cohort_platform/features/session/services/interval_progress_service.dart';
import 'package:cohort_platform/models/interval_data_source.dart';
import 'package:cohort_platform/models/interval_modality.dart';
import 'package:cohort_platform/models/interval_progress_result.dart';
import 'package:cohort_platform/models/interval_rep_entry.dart';
import 'package:cohort_platform/models/interval_phase_type.dart';
import 'package:cohort_platform/models/previous_interval_performance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = IntervalProgressService();

  group('IntervalProgressService', () {
    test('detects first performance when no prior session exists', () {
      final result = service.evaluate(
        previousPerformance: null,
        todayCompletedWorkPhases: _todayWork(
          paces: [235, 238, 239],
          rpes: [7, 8, 8],
        ),
      );

      expect(result.progressType, IntervalProgressType.firstPerformance);
      expect(result.headline, 'First recorded interval performance.');
    });

    test('detects average pace improvement', () {
      final result = service.evaluate(
        previousPerformance: _previousPerformance(
          repCount: 3,
          averagePace: 239,
          paceDropOff: 4,
          averageRpe: 7.7,
        ),
        todayCompletedWorkPhases: _todayWork(
          paces: [232, 233, 234],
          rpes: [7, 7, 8],
        ),
      );

      expect(result.progressType, IntervalProgressType.averagePaceImproved);
      expect(result.headline, 'Average pace improved.');
    });

    test('detects consistency improvement', () {
      final result = service.evaluate(
        previousPerformance: _previousPerformance(
          repCount: 3,
          averagePace: 237,
          paceDropOff: 6,
          averageRpe: 7.5,
        ),
        todayCompletedWorkPhases: _todayWork(
          paces: [236, 237, 238],
          rpes: [7, 7, 8],
        ),
      );

      expect(result.progressType, IntervalProgressType.consistencyImproved);
      expect(result.headline, 'Pacing consistency improved.');
    });

    test('detects lower RPE at same work', () {
      final result = service.evaluate(
        previousPerformance: _previousPerformance(
          repCount: 3,
          averagePace: 237,
          paceDropOff: 4,
          averageRpe: 8,
        ),
        todayCompletedWorkPhases: _todayWork(
          paces: [235, 237, 239],
          rpes: [6, 7, 7],
        ),
      );

      expect(result.progressType, IntervalProgressType.effortImproved);
      expect(result.headline, 'Same work at lower effort.');
    });

    test('detects more reps completed', () {
      final result = service.evaluate(
        previousPerformance: _previousPerformance(
          repCount: 2,
          averagePace: 237,
          paceDropOff: 3,
          averageRpe: 7.5,
        ),
        todayCompletedWorkPhases: _todayWork(
          paces: [236, 237, 238, 239],
          rpes: [7, 7, 8, 8],
        ),
      );

      expect(result.progressType, IntervalProgressType.moreWorkCompleted);
      expect(result.headline, 'More work completed.');
    });

    test('detects mixed result when metrics move in both directions', () {
      final result = service.evaluate(
        previousPerformance: _previousPerformance(
          repCount: 3,
          averagePace: 237,
          paceDropOff: 2,
          averageRpe: 7,
        ),
        todayCompletedWorkPhases: _todayWork(
          paces: [242, 245, 246],
          rpes: [6, 6, 7],
        ),
      );

      expect(result.progressType, IntervalProgressType.mixedResult);
    });

    test('returns insufficient data when comparison values are missing', () {
      final result = service.evaluate(
        previousPerformance: _previousPerformance(
          repCount: 2,
          averagePace: null,
          paceDropOff: null,
          averageRpe: null,
        ),
        todayCompletedWorkPhases: _todayWork(
          paces: [null, null],
          rpes: [null, null],
        ),
      );

      expect(result.progressType, IntervalProgressType.insufficientData);
    });

    test('excludes skipped reps from today averages', () {
      final result = service.evaluate(
        previousPerformance: _previousPerformance(
          repCount: 2,
          averagePace: 240,
          paceDropOff: 2,
          averageRpe: 8,
        ),
        todayCompletedWorkPhases: [
          _workEntry(pace: 230, rpe: 7),
          _workEntry(pace: 999, rpe: 10, skipped: true),
          _workEntry(pace: 232, rpe: 7),
        ],
      );

      expect(result.progressType, IntervalProgressType.averagePaceImproved);
    });
  });
}

PreviousIntervalPerformance _previousPerformance({
  required int repCount,
  required double? averagePace,
  required double? paceDropOff,
  required double? averageRpe,
}) {
  return PreviousIntervalPerformance(
    trainingSessionId: 1,
    protocolId: 'RN-006',
    modality: IntervalModality.running,
    completedRepCount: repCount,
    averagePaceSecondsPerKm: averagePace,
    paceDropOffSeconds: paceDropOff,
    averageRpe: averageRpe,
    reps: List.generate(
      repCount,
      (index) => PreviousIntervalRep(
        repNumber: index + 1,
        displayLine: 'Rep ${index + 1}',
      ),
    ),
  );
}

List<IntervalRepEntry> _todayWork({
  required List<double?> paces,
  required List<int?> rpes,
}) {
  return [
    for (var index = 0; index < paces.length; index++)
      _workEntry(
        pace: paces[index],
        rpe: rpes[index],
        repNumber: index + 1,
      ),
  ];
}

IntervalRepEntry _workEntry({
  required double? pace,
  required int? rpe,
  int repNumber = 1,
  bool skipped = false,
}) {
  return IntervalRepEntry(
    localId: 'work-$repNumber',
    blockIndex: 1,
    repNumber: repNumber,
    phaseType: IntervalPhaseType.work,
    actualDistance: 800,
    actualDuration: pace == null ? null : Duration(seconds: 188),
    actualPace: pace,
    rpe: rpe,
    completed: true,
    skipped: skipped,
    dataSource: IntervalDataSource.manual,
  );
}
