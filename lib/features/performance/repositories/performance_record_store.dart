import '../models/active_performance_draft.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';

abstract class PerformanceRecordStore {
  const PerformanceRecordStore();

  Future<TrainingSessionRecord?> getById(String recordId);

  Future<TrainingSessionRecord?> getInProgressForTrainingSession({
    required String athleteId,
    required int trainingSessionId,
  });

  Future<TrainingSessionRecord?> getTerminalForTrainingSession({
    required String athleteId,
    required int trainingSessionId,
  });

  Future<TrainingSessionRecord> createOrResumeInProgress(
    ActivePerformanceDraft draft,
  );

  Future<TrainingSessionRecord> saveDraft(ActivePerformanceDraft draft);

  Future<TrainingSessionRecord> completeRecord(
    ActivePerformanceDraft draft,
  );

  Future<List<TrainingSessionRecord>> listHistory({
    required String athleteId,
    int limit = 25,
    int offset = 0,
  });

  /// Developer-only scoped cleanup for founder acceptance test resets.
  Future<int> deleteFounderScopedRecords({
    required String athleteId,
    required String sourceProtocolId,
    String? assignmentId,
  });
}

class PerformanceRecordStoreException implements Exception {
  const PerformanceRecordStoreException(this.message);

  final String message;

  @override
  String toString() => 'PerformanceRecordStoreException: $message';
}

bool isTerminalRecordStatus(TrainingSessionRecordStatus status) =>
    status != TrainingSessionRecordStatus.inProgress;
