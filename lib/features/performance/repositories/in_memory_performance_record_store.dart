import '../mappers/performance_record_mapper.dart';
import '../models/active_performance_draft.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import 'performance_record_store.dart';

class InMemoryPerformanceRecordStore extends PerformanceRecordStore {
  InMemoryPerformanceRecordStore({
    PerformanceRecordMapper? mapper,
  }) : _mapper = mapper ?? const PerformanceRecordMapper();

  final PerformanceRecordMapper _mapper;
  final Map<String, TrainingSessionRecord> _recordsById = {};

  @override
  Future<TrainingSessionRecord?> getById(String recordId) async {
    return _recordsById[recordId];
  }

  @override
  Future<TrainingSessionRecord?> getInProgressForTrainingSession({
    required String athleteId,
    required int trainingSessionId,
  }) async {
    for (final record in _recordsById.values) {
      if (record.athleteId == athleteId &&
          record.trainingSessionId == trainingSessionId &&
          record.status == TrainingSessionRecordStatus.inProgress) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<TrainingSessionRecord?> getTerminalForTrainingSession({
    required String athleteId,
    required int trainingSessionId,
  }) async {
    TrainingSessionRecord? latest;
    for (final record in _recordsById.values) {
      if (record.athleteId != athleteId ||
          record.trainingSessionId != trainingSessionId ||
          !isTerminalRecordStatus(record.status)) {
        continue;
      }
      if (latest == null ||
          (record.completedAt ?? record.startedAt)
              .isAfter(latest.completedAt ?? latest.startedAt)) {
        latest = record;
      }
    }
    return latest;
  }

  @override
  Future<TrainingSessionRecord> createOrResumeInProgress(
    ActivePerformanceDraft draft,
  ) async {
    final existing = await getInProgressForTrainingSession(
      athleteId: draft.athleteId,
      trainingSessionId: draft.trainingSessionId,
    );
    if (existing != null) {
      return existing;
    }

    final terminal = await getTerminalForTrainingSession(
      athleteId: draft.athleteId,
      trainingSessionId: draft.trainingSessionId,
    );
    if (terminal != null) {
      return terminal;
    }

    final record = _mapper.fromDraft(
      draft.copyWith(status: TrainingSessionRecordStatus.inProgress),
    );
    _recordsById[record.recordId] = record;
    return record;
  }

  @override
  Future<TrainingSessionRecord> saveDraft(ActivePerformanceDraft draft) async {
    final record = _mapper.fromDraft(draft);
    _recordsById[record.recordId] = record;
    return record;
  }

  @override
  Future<TrainingSessionRecord> completeRecord(
    ActivePerformanceDraft draft,
  ) async {
    final existingTerminal = await getTerminalForTrainingSession(
      athleteId: draft.athleteId,
      trainingSessionId: draft.trainingSessionId,
    );
    if (existingTerminal != null) {
      return existingTerminal;
    }

    final record = _mapper.fromDraft(draft);
    _recordsById[record.recordId] = record;
    return record;
  }

  @override
  Future<List<TrainingSessionRecord>> listHistory({
    required String athleteId,
    int limit = 25,
    int offset = 0,
  }) async {
    final records = _recordsById.values
        .where(
          (record) =>
              record.athleteId == athleteId &&
              isTerminalRecordStatus(record.status),
        )
        .toList()
      ..sort(
        (a, b) => (b.completedAt ?? b.startedAt)
            .compareTo(a.completedAt ?? a.startedAt),
      );

    if (offset >= records.length) return const [];
    final end = (offset + limit).clamp(0, records.length);
    return records.sublist(offset, end);
  }

  @override
  Future<int> deleteFounderScopedRecords({
    required String athleteId,
    required String sourceProtocolId,
    String? assignmentId,
  }) async {
    final keysToRemove = <String>[];
    for (final entry in _recordsById.entries) {
      final record = entry.value;
      if (record.athleteId != athleteId) continue;

      final matchesProtocol = record.sourceProtocolId == sourceProtocolId;
      final matchesAssignment = assignmentId != null &&
          assignmentId.isNotEmpty &&
          record.assignmentId == assignmentId;
      if (matchesProtocol || matchesAssignment) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _recordsById.remove(key);
    }
    return keysToRemove.length;
  }

  void clear() => _recordsById.clear();
}
