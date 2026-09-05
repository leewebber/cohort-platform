import '../models/interval_work_result.dart';
import '../models/performance_result_data.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import 'running_pace_plausibility.dart';

class PerformanceCorrectionException implements Exception {
  const PerformanceCorrectionException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => message ?? code;
}

class PerformanceCorrectionDraft {
  PerformanceCorrectionDraft(TrainingSessionRecord record)
    : record = record,
      overallRpe = record.overallRpe,
      athleteNote = record.athleteNote,
      blockResults = [
        for (final block in record.blockResults)
          block.copyWith(
            exerciseResults: [
              for (final exercise in block.exerciseResults)
                exercise.copyWith(setResults: [...exercise.setResults]),
            ],
          ),
      ];

  final TrainingSessionRecord record;
  int? overallRpe;
  String? athleteNote;
  List<TrainingBlockResult> blockResults;
  String? correctionNote;
  bool acknowledgeImplausibleRunningPace = false;

  TrainingSessionRecord get original => record;

  TrainingSessionRecord snapshot() {
    return record.copyWith(
      overallRpe: overallRpe,
      athleteNote: athleteNote,
      blockResults: blockResults,
    );
  }

  RunningPaceWarning? runningWarning() {
    return RunningPacePlausibility.fromRecord(snapshot());
  }
}

class PerformanceCorrectionService {
  const PerformanceCorrectionService();

  void validate(PerformanceCorrectionDraft draft) {
    if (draft.record.status != TrainingSessionRecordStatus.completed) {
      throw const PerformanceCorrectionException('session_not_completed');
    }
    if (draft.overallRpe != null &&
        (draft.overallRpe! < 1 || draft.overallRpe! > 10)) {
      throw const PerformanceCorrectionException('invalid_rpe');
    }
    for (final block in draft.blockResults) {
      final data = block.resultData;
      if (data is EnduranceResultData) {
        _validateEndurance(data);
      }
      if (data is IntervalResultData) {
        if (data.recordedCount < 0 || data.recordedCount > 1000) {
          throw const PerformanceCorrectionException('invalid_interval_count');
        }
        final prescribed = data.prescribedCount;
        if (prescribed != null && data.recordedCount > prescribed) {
          throw const PerformanceCorrectionException('invalid_interval_count');
        }
        if (data.usesPerIntervalCapture &&
            prescribed != null &&
            data.intervals.length > prescribed) {
          throw const PerformanceCorrectionException('invalid_interval_count');
        }
        if (!IntervalPaceUnit.isSupported(data.paceUnit)) {
          throw const PerformanceCorrectionException('invalid_pace_unit');
        }
        for (final row in data.intervals) {
          if (prescribed != null &&
              (row.ordinal < 1 || row.ordinal > prescribed)) {
            throw const PerformanceCorrectionException('invalid_interval_ordinal');
          }
          if (row.state == IntervalWorkState.completed &&
              (row.paceSecondsPerKm == null || row.paceSecondsPerKm! <= 0)) {
            throw const PerformanceCorrectionException('invalid_pace');
          }
        }
      }
      for (final exercise in block.exerciseResults) {
        for (final set in exercise.setResults) {
          if (set.reps != null && (set.reps! < 0 || set.reps! > 1000)) {
            throw const PerformanceCorrectionException('invalid_reps');
          }
          final kind = exercise.exerciseSnapshot.loadKind;
          if (kind.expectsExternalLoad &&
              set.load != null &&
              set.load! > 2000) {
            throw const PerformanceCorrectionException('invalid_load');
          }
        }
      }
    }
  }

  Map<String, dynamic> toPayload(PerformanceCorrectionDraft draft) {
    validate(draft);
    return {
      'record_id': draft.record.recordId,
      if (draft.overallRpe != draft.record.overallRpe)
        'overall_rpe': draft.overallRpe,
      if (draft.athleteNote != draft.record.athleteNote)
        'athlete_note': draft.athleteNote,
      if (draft.correctionNote != null) 'correction_note': draft.correctionNote,
      'implausible_running_pace_acknowledged':
          draft.acknowledgeImplausibleRunningPace,
      'blocks': [
        for (final block in draft.blockResults)
          if (_blockChanged(draft.record, block))
            {
              'block_result_id': block.blockResultId,
              if (block.resultData != null)
                'result_data': block.resultData!.toJson(),
            },
      ],
      'sets': [
        for (final block in draft.blockResults)
          for (final exercise in block.exerciseResults)
            for (final set in exercise.setResults)
              if (_setChanged(draft.record, set))
                {
                  'set_result_id': set.setResultId,
                  'reps': set.reps,
                  'load': set.load,
                  'load_unit': set.loadUnit,
                  'completed': set.completed,
                  'rpe': set.rpe,
                  'note': set.note,
                  'distance': set.distance,
                  'distance_unit': set.distanceUnit,
                  'duration_seconds': set.durationSeconds,
                },
      ],
    };
  }

  TrainingSessionRecord applyLocally(PerformanceCorrectionDraft draft) {
    validate(draft);
    return draft.snapshot().copyWith(lastCorrectedAt: DateTime.now().toUtc());
  }

  static void _validateEndurance(EnduranceResultData data) {
    if (data.durationSeconds != null &&
        (data.durationSeconds! < 0 || data.durationSeconds! > 86400)) {
      throw const PerformanceCorrectionException('invalid_duration');
    }
    if (data.distance != null &&
        (data.distance! < 0 || data.distance! > 1000)) {
      throw const PerformanceCorrectionException('invalid_distance');
    }
    if (data.averageHeartRate != null &&
        (data.averageHeartRate! < 20 || data.averageHeartRate! > 250)) {
      throw const PerformanceCorrectionException('invalid_heart_rate');
    }
  }

  static bool _blockChanged(
    TrainingSessionRecord original,
    TrainingBlockResult block,
  ) {
    for (final current in original.blockResults) {
      if (current.blockResultId != block.blockResultId) continue;
      return current.resultData?.toJson().toString() !=
          block.resultData?.toJson().toString();
    }
    return false;
  }

  static bool _setChanged(TrainingSessionRecord original, TrainingSetResult set) {
    for (final block in original.blockResults) {
      for (final exercise in block.exerciseResults) {
        for (final current in exercise.setResults) {
          if (current.setResultId != set.setResultId) continue;
          return current.reps != set.reps ||
              current.load != set.load ||
              current.loadUnit != set.loadUnit ||
              current.completed != set.completed ||
              current.rpe != set.rpe ||
              current.note != set.note ||
              current.distance != set.distance ||
              current.distanceUnit != set.distanceUnit ||
              current.durationSeconds != set.durationSeconds;
        }
      }
    }
    return false;
  }
}
