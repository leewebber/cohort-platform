import 'package:cohort_platform/application/ports/workout_execution_record_store.dart';
import 'package:cohort_platform/domain/workout_execution_record/workout_execution_record_domain.dart';

/// In-memory [WorkoutExecutionRecordStore] for tests and local orchestration.
class InMemoryWorkoutExecutionRecordStore
    implements WorkoutExecutionRecordStore {
  InMemoryWorkoutExecutionRecordStore({
    Map<String, WorkoutExecutionRecord>? seed,
  }) : _byId = Map.from(seed ?? const {});

  final Map<String, WorkoutExecutionRecord> _byId;

  @override
  WorkoutExecutionRecord? getById(String recordId) => _byId[recordId.trim()];

  @override
  WorkoutExecutionRecord? getByOccurrenceId(String occurrenceId) {
    final trimmed = occurrenceId.trim();
    for (final record in _byId.values) {
      if (record.occurrenceId.trim() == trimmed) {
        return record;
      }
    }
    return null;
  }

  @override
  void save(WorkoutExecutionRecord record) {
    _byId[record.recordId] = record;
  }
}
