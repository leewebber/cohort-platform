import '../../../core/utils/database_uuid.dart';
import 'performance_result_data.dart';
import 'performance_result_type.dart';
import 'performance_snapshot.dart';
import 'training_block_result_status.dart';
import 'training_session_record_status.dart';

class SetPerformanceDraft {
  const SetPerformanceDraft({
    required this.setResultId,
    required this.setNumber,
    required this.position,
    this.reps,
    this.load,
    this.loadUnit = 'kg',
    this.distance,
    this.distanceUnit,
    this.durationSeconds,
    this.completed = false,
    this.rpe,
    this.note,
  });

  final String setResultId;
  final int setNumber;
  final int position;
  final int? reps;
  final double? load;
  final String loadUnit;
  final double? distance;
  final String? distanceUnit;
  final int? durationSeconds;
  final bool completed;
  final int? rpe;
  final String? note;

  SetPerformanceDraft copyWith({
    String? setResultId,
    int? setNumber,
    int? position,
    int? reps,
    double? load,
    String? loadUnit,
    double? distance,
    String? distanceUnit,
    int? durationSeconds,
    bool? completed,
    int? rpe,
    String? note,
  }) {
    return SetPerformanceDraft(
      setResultId: setResultId ?? this.setResultId,
      setNumber: setNumber ?? this.setNumber,
      position: position ?? this.position,
      reps: reps ?? this.reps,
      load: load ?? this.load,
      loadUnit: loadUnit ?? this.loadUnit,
      distance: distance ?? this.distance,
      distanceUnit: distanceUnit ?? this.distanceUnit,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      completed: completed ?? this.completed,
      rpe: rpe ?? this.rpe,
      note: note ?? this.note,
    );
  }

  factory SetPerformanceDraft.empty({
    required int setNumber,
    required int position,
  }) {
    return SetPerformanceDraft(
      setResultId: DatabaseUuid.newV4(),
      setNumber: setNumber,
      position: position,
    );
  }
}

class ExercisePerformanceDraft {
  const ExercisePerformanceDraft({
    required this.exerciseResultId,
    required this.sourceExerciseId,
    required this.exerciseSnapshot,
    required this.position,
    this.sets = const [],
    this.athleteNote,
  });

  final String exerciseResultId;
  final String sourceExerciseId;
  final ExercisePerformanceSnapshot exerciseSnapshot;
  final int position;
  final List<SetPerformanceDraft> sets;
  final String? athleteNote;

  ExercisePerformanceDraft copyWith({
    List<SetPerformanceDraft>? sets,
    String? athleteNote,
  }) {
    return ExercisePerformanceDraft(
      exerciseResultId: exerciseResultId,
      sourceExerciseId: sourceExerciseId,
      exerciseSnapshot: exerciseSnapshot,
      position: position,
      sets: sets ?? this.sets,
      athleteNote: athleteNote ?? this.athleteNote,
    );
  }
}

class BlockPerformanceDraft {
  const BlockPerformanceDraft({
    required this.blockResultId,
    required this.sourceBlockId,
    required this.blockSnapshot,
    required this.position,
    required this.status,
    required this.captureMode,
    required this.resultType,
    required this.resultData,
    this.startedAt,
    this.completedAt,
    this.durationSeconds,
    this.athleteNote,
    this.exerciseResults = const [],
  });

  final String blockResultId;
  final String sourceBlockId;
  final BlockPerformanceSnapshot blockSnapshot;
  final int position;
  final TrainingBlockResultStatus status;
  final BlockCaptureMode captureMode;
  final PerformanceResultType resultType;
  final PerformanceResultData resultData;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int? durationSeconds;
  final String? athleteNote;
  final List<ExercisePerformanceDraft> exerciseResults;

  BlockPerformanceDraft copyWith({
    TrainingBlockResultStatus? status,
    BlockCaptureMode? captureMode,
    PerformanceResultType? resultType,
    PerformanceResultData? resultData,
    DateTime? startedAt,
    DateTime? completedAt,
    int? durationSeconds,
    String? athleteNote,
    List<ExercisePerformanceDraft>? exerciseResults,
  }) {
    return BlockPerformanceDraft(
      blockResultId: blockResultId,
      sourceBlockId: sourceBlockId,
      blockSnapshot: blockSnapshot,
      position: position,
      status: status ?? this.status,
      captureMode: captureMode ?? this.captureMode,
      resultType: resultType ?? this.resultType,
      resultData: resultData ?? this.resultData,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      athleteNote: athleteNote ?? this.athleteNote,
      exerciseResults: exerciseResults ?? this.exerciseResults,
    );
  }
}

class ActivePerformanceDraft {
  const ActivePerformanceDraft({
    required this.recordId,
    required this.athleteId,
    required this.trainingSessionId,
    required this.sourceProtocolId,
    required this.sessionSnapshot,
    required this.status,
    required this.startedAt,
    this.programmeId,
    this.assignmentId,
    this.programmeSessionId,
    this.activeBlockId,
    this.overallRpe,
    this.athleteNote,
    this.completedAt,
    this.durationSeconds,
    this.blockDrafts = const [],
  });

  final String recordId;
  final String athleteId;
  final int trainingSessionId;
  final String sourceProtocolId;
  final SessionPerformanceSnapshot sessionSnapshot;
  final TrainingSessionRecordStatus status;
  final DateTime startedAt;
  final String? programmeId;
  final String? assignmentId;
  final String? programmeSessionId;
  final String? activeBlockId;
  final int? overallRpe;
  final String? athleteNote;
  final DateTime? completedAt;
  final int? durationSeconds;
  final List<BlockPerformanceDraft> blockDrafts;

  int get completedBlockCount =>
      blockDrafts.where((b) => b.status == TrainingBlockResultStatus.completed).length;

  int get skippedBlockCount =>
      blockDrafts.where((b) => b.status == TrainingBlockResultStatus.skipped).length;

  int get incompleteBlockCount => blockDrafts.where((block) {
        if (!block.blockSnapshot.content.trim().isNotEmpty &&
            block.blockSnapshot.exercises.isEmpty) {
          return false;
        }
        return block.status != TrainingBlockResultStatus.completed &&
            block.status != TrainingBlockResultStatus.skipped;
      }).length;

  BlockPerformanceDraft? blockDraftFor(String sourceBlockId) {
    for (final draft in blockDrafts) {
      if (draft.sourceBlockId == sourceBlockId) return draft;
    }
    return null;
  }

  ActivePerformanceDraft copyWith({
    TrainingSessionRecordStatus? status,
    String? activeBlockId,
    int? overallRpe,
    String? athleteNote,
    DateTime? completedAt,
    int? durationSeconds,
    List<BlockPerformanceDraft>? blockDrafts,
  }) {
    return ActivePerformanceDraft(
      recordId: recordId,
      athleteId: athleteId,
      trainingSessionId: trainingSessionId,
      sourceProtocolId: sourceProtocolId,
      sessionSnapshot: sessionSnapshot,
      status: status ?? this.status,
      startedAt: startedAt,
      programmeId: programmeId,
      assignmentId: assignmentId,
      programmeSessionId: programmeSessionId,
      activeBlockId: activeBlockId ?? this.activeBlockId,
      overallRpe: overallRpe ?? this.overallRpe,
      athleteNote: athleteNote ?? this.athleteNote,
      completedAt: completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      blockDrafts: blockDrafts ?? this.blockDrafts,
    );
  }
}
