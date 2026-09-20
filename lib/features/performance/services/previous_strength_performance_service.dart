import '../../../core/services/supabase_service.dart';
import '../models/previous_strength_performance.dart';
import '../models/session_result_entry_mode.dart';
import '../models/training_session_record_status.dart';
import 'previous_strength_performance_selector.dart';

abstract class PreviousStrengthPerformanceStore {
  const PreviousStrengthPerformanceStore();

  Future<List<PreviousStrengthCandidate>> loadCandidates({
    required String athleteId,
    required Set<String> exerciseIds,
    String? excludeRecordId,
  });
}

/// Bounded in-memory cache. Empty results invalidate after write events.
class PreviousStrengthPerformanceCache {
  PreviousStrengthPerformanceCache._();

  static final Map<String, Map<String, PreviousStrengthExerciseEvidence>>
  _byKey = {};

  static String key({
    required String athleteId,
    required Iterable<String> exerciseIds,
    String? excludeRecordId,
  }) {
    final ids = exerciseIds.toList()..sort();
    return '$athleteId|${excludeRecordId ?? ''}|${ids.join(',')}';
  }

  static Map<String, PreviousStrengthExerciseEvidence>? read(String cacheKey) {
    return _byKey[cacheKey];
  }

  static void write(
    String cacheKey,
    Map<String, PreviousStrengthExerciseEvidence> value,
  ) {
    _byKey[cacheKey] = Map.unmodifiable(value);
  }

  static void invalidateAthlete(String athleteId) {
    _byKey.removeWhere((key, _) => key.startsWith('$athleteId|'));
  }

  static void clear() => _byKey.clear();
}

class EmptyPreviousStrengthPerformanceStore
    implements PreviousStrengthPerformanceStore {
  const EmptyPreviousStrengthPerformanceStore();

  @override
  Future<List<PreviousStrengthCandidate>> loadCandidates({
    required String athleteId,
    required Set<String> exerciseIds,
    String? excludeRecordId,
  }) async {
    return const [];
  }
}

class PreviousStrengthPerformanceService {
  PreviousStrengthPerformanceService({
    PreviousStrengthPerformanceStore? store,
  }) : _store = store ?? const SupabasePreviousStrengthPerformanceStore();

  final PreviousStrengthPerformanceStore _store;

  Future<Map<String, PreviousStrengthExerciseEvidence>> latestForExercises({
    required String athleteId,
    required Iterable<String> exerciseIds,
    String? excludeRecordId,
    DateTime? currentChronologyAt,
    bool bypassCache = false,
  }) async {
    final ids = exerciseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (athleteId.trim().isEmpty || ids.isEmpty) {
      return const {};
    }
    final cacheKey = PreviousStrengthPerformanceCache.key(
      athleteId: athleteId,
      exerciseIds: ids,
      excludeRecordId: excludeRecordId,
    );
    if (!bypassCache) {
      final cached = PreviousStrengthPerformanceCache.read(cacheKey);
      if (cached != null) return cached;
    }
    final candidates = await _store.loadCandidates(
      athleteId: athleteId,
      exerciseIds: ids,
      excludeRecordId: excludeRecordId,
    );
    final selected = PreviousStrengthPerformanceSelector.selectLatest(
      athleteId: athleteId,
      exerciseIds: ids,
      candidates: candidates,
      excludeRecordId: excludeRecordId,
      currentChronologyAt: currentChronologyAt,
    );
    PreviousStrengthPerformanceCache.write(cacheKey, selected);
    return selected;
  }

  static void invalidateAfterWrite(String athleteId) {
    PreviousStrengthPerformanceCache.invalidateAthlete(athleteId);
  }
}

class SupabasePreviousStrengthPerformanceStore
    implements PreviousStrengthPerformanceStore {
  const SupabasePreviousStrengthPerformanceStore();

  static const _recordLimit = 40;

  @override
  Future<List<PreviousStrengthCandidate>> loadCandidates({
    required String athleteId,
    required Set<String> exerciseIds,
    String? excludeRecordId,
  }) async {
    if (exerciseIds.isEmpty) return const [];
    final records = await SupabaseService.client
        .from('training_session_records')
        .select(
          'record_id, athlete_id, status, started_at, completed_at, performed_on, entry_mode',
        )
        .eq('athlete_id', athleteId)
        .inFilter('status', const ['completed', 'partially_completed'])
        .order('started_at', ascending: false)
        .limit(_recordLimit);

    final headers = <_RecordHeader>[];
    for (final row in (records as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      final recordId = map['record_id']?.toString() ?? '';
      if (recordId.isEmpty) continue;
      if (excludeRecordId != null && recordId == excludeRecordId) continue;
      final startedAt = DateTime.tryParse(map['started_at']?.toString() ?? '');
      if (startedAt == null) continue;
      headers.add(
        _RecordHeader(
          recordId: recordId,
          athleteId: map['athlete_id']?.toString() ?? athleteId,
          status: TrainingSessionRecordStatusDb.fromDb(
            map['status']?.toString(),
          ),
          startedAt: startedAt,
          completedAt: DateTime.tryParse(
            map['completed_at']?.toString() ?? '',
          ),
          performedOn: DateTime.tryParse(
            map['performed_on']?.toString() ?? '',
          ),
          entryMode: SessionResultEntryMode.parse(map['entry_mode']),
        ),
      );
    }
    if (headers.isEmpty) return const [];
    final recordIds = headers.map((h) => h.recordId).toList();

    final blockRows = await SupabaseService.client
        .from('training_block_results')
        .select('block_result_id, session_record_id')
        .inFilter('session_record_id', recordIds);
    final blockToRecord = <String, String>{};
    for (final row in (blockRows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      final blockId = map['block_result_id']?.toString() ?? '';
      final recordId = map['session_record_id']?.toString() ?? '';
      if (blockId.isEmpty || recordId.isEmpty) continue;
      blockToRecord[blockId] = recordId;
    }
    if (blockToRecord.isEmpty) return const [];

    final exerciseRows = await SupabaseService.client
        .from('training_exercise_results')
        .select('exercise_result_id, source_exercise_id, block_result_id')
        .inFilter('block_result_id', blockToRecord.keys.toList())
        .inFilter('source_exercise_id', exerciseIds.toList());
    final exerciseToRecord = <String, String>{};
    final exerciseIdByResult = <String, String>{};
    for (final row in (exerciseRows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      final exerciseResultId = map['exercise_result_id']?.toString() ?? '';
      final sourceId = map['source_exercise_id']?.toString() ?? '';
      final blockId = map['block_result_id']?.toString() ?? '';
      final recordId = blockToRecord[blockId];
      if (exerciseResultId.isEmpty ||
          sourceId.isEmpty ||
          recordId == null ||
          !exerciseIds.contains(sourceId)) {
        continue;
      }
      exerciseToRecord[exerciseResultId] = recordId;
      exerciseIdByResult[exerciseResultId] = sourceId;
    }
    if (exerciseToRecord.isEmpty) {
      return headers
          .map(
            (header) => PreviousStrengthCandidate(
              recordId: header.recordId,
              athleteId: header.athleteId,
              status: header.status,
              startedAt: header.startedAt,
              completedAt: header.completedAt,
              performedOn: header.performedOn,
              entryMode: header.entryMode,
              exercises: const [],
            ),
          )
          .toList(growable: false);
    }

    final setRows = await SupabaseService.client
        .from('training_set_results')
        .select(
          'exercise_result_id, set_number, reps, load, load_unit, rpe, completed',
        )
        .inFilter('exercise_result_id', exerciseToRecord.keys.toList())
        .eq('completed', true);

    final setsByExercise = <String, List<PreviousStrengthSetEvidence>>{};
    for (final row in (setRows as List)) {
      final map = Map<String, dynamic>.from(row as Map);
      if (map['completed'] != true) continue;
      final exerciseResultId = map['exercise_result_id']?.toString() ?? '';
      final sourceId = exerciseIdByResult[exerciseResultId];
      if (sourceId == null) continue;
      final set = PreviousStrengthSetEvidence(
        setNumber: map['set_number'] as int? ?? 0,
        reps: _nullableInt(map['reps']),
        load: _nullableDouble(map['load']),
        loadUnit: map['load_unit']?.toString(),
        rpe: _nullableInt(map['rpe']),
      );
      if (!set.hasActuals) continue;
      setsByExercise
          .putIfAbsent(exerciseResultId, () => [])
          .add(set);
    }

    final exercisesByRecord = <String, List<PreviousStrengthCandidateExercise>>{};
    for (final entry in exerciseToRecord.entries) {
      final sets = setsByExercise[entry.key];
      if (sets == null || sets.isEmpty) continue;
      final sourceId = exerciseIdByResult[entry.key];
      if (sourceId == null) continue;
      exercisesByRecord
          .putIfAbsent(entry.value, () => [])
          .add(
            PreviousStrengthCandidateExercise(
              exerciseId: sourceId,
              sets: sets,
            ),
          );
    }

    return [
      for (final header in headers)
        PreviousStrengthCandidate(
          recordId: header.recordId,
          athleteId: header.athleteId,
          status: header.status,
          startedAt: header.startedAt,
          completedAt: header.completedAt,
          performedOn: header.performedOn,
          entryMode: header.entryMode,
          exercises: exercisesByRecord[header.recordId] ?? const [],
        ),
    ];
  }

  static int? _nullableInt(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  static double? _nullableDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

class _RecordHeader {
  const _RecordHeader({
    required this.recordId,
    required this.athleteId,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.performedOn,
    required this.entryMode,
  });

  final String recordId;
  final String athleteId;
  final TrainingSessionRecordStatus status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? performedOn;
  final SessionResultEntryMode entryMode;
}

class CountingPreviousStrengthPerformanceStore
    implements PreviousStrengthPerformanceStore {
  CountingPreviousStrengthPerformanceStore(this.inner);

  final PreviousStrengthPerformanceStore inner;
  int loadCount = 0;

  @override
  Future<List<PreviousStrengthCandidate>> loadCandidates({
    required String athleteId,
    required Set<String> exerciseIds,
    String? excludeRecordId,
  }) {
    loadCount += 1;
    return inner.loadCandidates(
      athleteId: athleteId,
      exerciseIds: exerciseIds,
      excludeRecordId: excludeRecordId,
    );
  }
}

class InMemoryPreviousStrengthPerformanceStore
    implements PreviousStrengthPerformanceStore {
  InMemoryPreviousStrengthPerformanceStore(this.candidates);

  final List<PreviousStrengthCandidate> candidates;
  int loadCount = 0;

  @override
  Future<List<PreviousStrengthCandidate>> loadCandidates({
    required String athleteId,
    required Set<String> exerciseIds,
    String? excludeRecordId,
  }) async {
    loadCount += 1;
    return [
      for (final candidate in candidates)
        if (candidate.athleteId == athleteId)
          PreviousStrengthCandidate(
            recordId: candidate.recordId,
            athleteId: candidate.athleteId,
            status: candidate.status,
            startedAt: candidate.startedAt,
            completedAt: candidate.completedAt,
            performedOn: candidate.performedOn,
            entryMode: candidate.entryMode,
            exercises: [
              for (final exercise in candidate.exercises)
                if (exerciseIds.contains(exercise.exerciseId)) exercise,
            ],
          ),
    ];
  }
}
