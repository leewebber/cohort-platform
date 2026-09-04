import '../mappers/performance_record_mapper.dart';
import '../models/active_performance_draft.dart';
import '../models/training_session_record.dart';
import '../models/training_session_record_status.dart';
import '../services/performance_correction_service.dart';
import 'performance_record_store.dart';

class InMemoryPerformanceRecordStore extends PerformanceRecordStore {
  InMemoryPerformanceRecordStore({PerformanceRecordMapper? mapper})
    : _mapper = mapper ?? const PerformanceRecordMapper();

  final PerformanceRecordMapper _mapper;
  final Map<String, TrainingSessionRecord> _recordsById = {};
  final List<Map<String, dynamic>> corrections = [];
  bool authenticated = true;
  String? actingAthleteId;

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
          (record.completedAt ?? record.startedAt).isAfter(
            latest.completedAt ?? latest.startedAt,
          )) {
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
  Future<TrainingSessionRecord> correctCompleted(
    PerformanceCorrectionDraft draft,
  ) async {
    if (!authenticated) {
      throw const PerformanceCorrectionException('authentication_required');
    }
    final existing = _recordsById[draft.record.recordId];
    if (existing == null) {
      throw const PerformanceCorrectionException('performance_record_not_found');
    }
    final actor = actingAthleteId ?? draft.record.athleteId;
    if (actor != existing.athleteId) {
      throw const PerformanceCorrectionException('not_performance_owner');
    }
    if (existing.status != TrainingSessionRecordStatus.completed) {
      throw const PerformanceCorrectionException('session_not_completed');
    }
    const service = PerformanceCorrectionService();
    final payload = service.toPayload(draft);
    final corrected = service.applyLocally(draft).copyWith(
      lastCorrectedAt: DateTime.now().toUtc(),
    );
    if (corrected.completedAt != existing.completedAt ||
        corrected.status != existing.status) {
      throw const PerformanceCorrectionException('lifecycle_mutated');
    }
    _recordsById[existing.recordId] = existing.copyWith(
      overallRpe: corrected.overallRpe,
      athleteNote: corrected.athleteNote,
      blockResults: corrected.blockResults,
      lastCorrectedAt: corrected.lastCorrectedAt,
    );
    corrections.add({
      'record_id': existing.recordId,
      'athlete_id': existing.athleteId,
      'before': {
        'overall_rpe': existing.overallRpe,
      },
      'after': payload,
      'implausible_running_pace_acknowledged':
          draft.acknowledgeImplausibleRunningPace,
      'corrected_at': DateTime.now().toUtc().toIso8601String(),
    });
    return _recordsById[existing.recordId]!;
  }

  @override
  Future<List<TrainingSessionRecord>> listHistory({
    required String athleteId,
    int limit = 25,
    int offset = 0,
  }) async {
    final records =
        _recordsById.values
            .where(
              (record) =>
                  record.athleteId == athleteId &&
                  isTerminalRecordStatus(record.status),
            )
            .toList()
          ..sort(
            (a, b) => (b.completedAt ?? b.startedAt).compareTo(
              a.completedAt ?? a.startedAt,
            ),
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
      final matchesAssignment =
          assignmentId != null &&
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

  void put(TrainingSessionRecord record) {
    _recordsById[record.recordId] = record;
  }

  void clear() => _recordsById.clear();
}
