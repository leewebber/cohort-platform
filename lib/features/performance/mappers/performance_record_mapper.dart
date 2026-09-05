import '../models/active_performance_draft.dart';
import '../models/performance_result_data.dart';
import '../models/performance_result_type.dart';
import '../models/performance_snapshot.dart';
import '../models/training_session_record.dart';
import '../services/interval_set_sync.dart';

class PerformanceRecordMapper {
  const PerformanceRecordMapper();

  TrainingSessionRecord fromDraft(ActivePerformanceDraft draft) {
    final blockResults = draft.blockDrafts
        .map((blockDraft) {
          final exerciseResults = blockDraft.exerciseResults
              .map((exerciseDraft) {
                final setResults = exerciseDraft.sets
                    .map(
                      (setDraft) => TrainingSetResult(
                        setResultId: setDraft.setResultId,
                        exerciseResultId: exerciseDraft.exerciseResultId,
                        setNumber: setDraft.setNumber,
                        position: setDraft.position,
                        reps: setDraft.reps,
                        load: _authoritativeLoad(
                          load: setDraft.load,
                          kind: exerciseDraft.exerciseSnapshot.loadKind,
                        ),
                        loadUnit: _authoritativeLoadUnit(
                          load: setDraft.load,
                          loadUnit: setDraft.loadUnit,
                          kind: exerciseDraft.exerciseSnapshot.loadKind,
                        ),
                        distance: setDraft.distance,
                        distanceUnit: setDraft.distanceUnit,
                        durationSeconds: setDraft.durationSeconds,
                        completed: setDraft.completed,
                        rpe: setDraft.rpe,
                        note: setDraft.note,
                      ),
                    )
                    .toList(growable: false);

                return TrainingExerciseResult(
                  exerciseResultId: exerciseDraft.exerciseResultId,
                  blockResultId: blockDraft.blockResultId,
                  sourceExerciseId: exerciseDraft.sourceExerciseId,
                  exerciseSnapshot: exerciseDraft.exerciseSnapshot,
                  position: exerciseDraft.position,
                  athleteNote: exerciseDraft.athleteNote,
                  setResults: setResults,
                );
              })
              .toList(growable: false);

          return TrainingBlockResult(
            blockResultId: blockDraft.blockResultId,
            sessionRecordId: draft.recordId,
            sourceBlockId: blockDraft.sourceBlockId,
            blockSnapshot: blockDraft.blockSnapshot,
            status: blockDraft.status,
            resultType: blockDraft.resultType,
            position: blockDraft.position,
            resultData: blockDraft.resultData,
            athleteNote: blockDraft.athleteNote,
            startedAt: blockDraft.startedAt,
            completedAt: blockDraft.completedAt,
            durationSeconds: blockDraft.durationSeconds,
            exerciseResults: exerciseResults,
          );
        })
        .toList(growable: false);

    return TrainingSessionRecord(
      recordId: draft.recordId,
      athleteId: draft.athleteId,
      trainingSessionId: draft.trainingSessionId,
      sourceProtocolId: draft.sourceProtocolId,
      programmeId: draft.programmeId,
      assignmentId: draft.assignmentId,
      programmeSessionId: draft.programmeSessionId,
      status: draft.status,
      sessionSnapshot: draft.sessionSnapshot,
      activeBlockId: draft.activeBlockId,
      startedAt: draft.startedAt,
      completedAt: draft.completedAt,
      durationSeconds: draft.durationSeconds,
      overallRpe: draft.overallRpe,
      athleteNote: draft.athleteNote,
      blockResults: blockResults,
    );
  }

  ActivePerformanceDraft toDraft(TrainingSessionRecord record) {
    final blockDrafts = record.blockResults
        .map((block) {
          return BlockPerformanceDraft(
            blockResultId: block.blockResultId,
            sourceBlockId: block.sourceBlockId,
            blockSnapshot: block.blockSnapshot,
            position: block.position,
            status: block.status,
            captureMode: BlockCaptureMode.auto,
            resultType: block.resultType,
            resultData: _intervalResult(block),
            startedAt: block.startedAt,
            completedAt: block.completedAt,
            durationSeconds: block.durationSeconds,
            athleteNote: block.athleteNote,
            exerciseResults: block.exerciseResults
                .map(
                  (exercise) => ExercisePerformanceDraft(
                    exerciseResultId: exercise.exerciseResultId,
                    sourceExerciseId: exercise.sourceExerciseId,
                    exerciseSnapshot: exercise.exerciseSnapshot,
                    position: exercise.position,
                    athleteNote: exercise.athleteNote,
                    sets: exercise.setResults
                        .map(
                          (set) => SetPerformanceDraft(
                            setResultId: set.setResultId,
                            setNumber: set.setNumber,
                            position: set.position,
                            reps: set.reps,
                            load: set.load,
                            loadUnit: set.loadUnit,
                            distance: set.distance,
                            distanceUnit: set.distanceUnit,
                            durationSeconds: set.durationSeconds,
                            completed: set.completed,
                            rpe: set.rpe,
                            note: set.note,
                          ),
                        )
                        .toList(growable: false),
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);

    return ActivePerformanceDraft(
      recordId: record.recordId,
      athleteId: record.athleteId,
      trainingSessionId: record.trainingSessionId ?? 0,
      sourceProtocolId: record.sourceProtocolId ?? '',
      sessionSnapshot: record.sessionSnapshot,
      status: record.status,
      startedAt: record.startedAt,
      programmeId: record.programmeId,
      assignmentId: record.assignmentId,
      programmeSessionId: record.programmeSessionId,
      activeBlockId: record.activeBlockId,
      overallRpe: record.overallRpe,
      athleteNote: record.athleteNote,
      completedAt: record.completedAt,
      durationSeconds: record.durationSeconds,
      blockDrafts: blockDrafts,
    );
  }

  static PerformanceResultData _intervalResult(TrainingBlockResult block) {
    final data = block.resultData ?? const CompletionResultData();
    if (data is! IntervalResultData) return data;
    return IntervalSetSync.hydrateFromSets(
      result: data,
      exercises: block.exerciseResults,
    );
  }

  static double? _authoritativeLoad({
    required double? load,
    required StrengthActualLoadKind kind,
  }) {
    if (!kind.expectsExternalLoad) {
      return null;
    }
    if (load == null) return null;
    if (load == 0) return null;
    return load;
  }

  static String? _authoritativeLoadUnit({
    required double? load,
    required String? loadUnit,
    required StrengthActualLoadKind kind,
  }) {
    if (_authoritativeLoad(load: load, kind: kind) == null) {
      return null;
    }
    final unit = loadUnit?.trim();
    return unit == null || unit.isEmpty ? 'kg' : unit;
  }
}
