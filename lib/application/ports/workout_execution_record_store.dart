import 'package:cohort_platform/domain/workout_execution_record/workout_execution_record_domain.dart';

/// Persistence port for domain [WorkoutExecutionRecord] (target athlete pipeline).
abstract interface class WorkoutExecutionRecordStore {
  WorkoutExecutionRecord? getById(String recordId);

  WorkoutExecutionRecord? getByOccurrenceId(String occurrenceId);

  void save(WorkoutExecutionRecord record);
}
