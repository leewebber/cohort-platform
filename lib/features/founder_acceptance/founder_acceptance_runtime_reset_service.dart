import 'package:flutter/foundation.dart';

import '../../data/repositories/training_session_repository.dart';
import '../performance/repositories/performance_record_store.dart';
import '../performance/repositories/supabase_performance_record_store.dart';
import '../session/controllers/session_execution_controller.dart';
import 'founder_acceptance_content.dart';

/// Result of developer-only founder acceptance runtime cleanup.
class FounderAcceptanceRuntimeResetResult {
  const FounderAcceptanceRuntimeResetResult({
    required this.deletedPerformanceRecords,
    required this.deletedTrainingSessions,
    required this.clearedMemoryKeys,
  });

  final int deletedPerformanceRecords;
  final int deletedTrainingSessions;
  final int clearedMemoryKeys;

  @override
  String toString() {
    return 'FounderAcceptanceRuntimeResetResult('
        'performanceRecords=$deletedPerformanceRecords, '
        'trainingSessions=$deletedTrainingSessions, '
        'memoryKeys=$clearedMemoryKeys)';
  }
}

/// Clears persisted and in-memory founder session runtime state.
///
/// Developer-only — invoked exclusively from founder acceptance reset tooling.
class FounderAcceptanceRuntimeResetService {
  FounderAcceptanceRuntimeResetService({
    PerformanceRecordStore? performanceRecordStore,
    TrainingSessionRepository? trainingSessionRepository,
    AthleteSessionMemoryStore? memoryStore,
  })  : _performanceRecordStore =
            performanceRecordStore ?? SupabasePerformanceRecordStore(),
        _trainingSessionRepository =
            trainingSessionRepository ?? const TrainingSessionRepository(),
        _memoryStore = memoryStore ?? AthleteSessionMemoryStore.instance;

  final PerformanceRecordStore _performanceRecordStore;
  final TrainingSessionRepository _trainingSessionRepository;
  final AthleteSessionMemoryStore _memoryStore;

  Future<FounderAcceptanceRuntimeResetResult> clearFounderRuntimeState({
    required String athleteId,
    String? assignmentId,
  }) async {
    assert(
      kDebugMode,
      'FounderAcceptanceRuntimeResetService is developer-only',
    );

    final protocolId = FounderAcceptanceContent.protocolId;

    debugPrint(
      '[FounderAcceptanceReset] clearing runtime state '
      'athlete=$athleteId protocol=$protocolId assignment=$assignmentId',
    );

    final deletedPerformanceRecords =
        await _performanceRecordStore.deleteFounderScopedRecords(
      athleteId: athleteId,
      sourceProtocolId: protocolId,
      assignmentId: assignmentId,
    );

    final deletedTrainingSessions =
        await _trainingSessionRepository.deleteForAthleteAndProtocol(
      athleteId: athleteId,
      protocolId: protocolId,
    );

    final clearedMemoryKeys = _memoryStore.clearForProtocol(protocolId);

    final result = FounderAcceptanceRuntimeResetResult(
      deletedPerformanceRecords: deletedPerformanceRecords,
      deletedTrainingSessions: deletedTrainingSessions,
      clearedMemoryKeys: clearedMemoryKeys,
    );
    debugPrint('[FounderAcceptanceReset] runtime cleanup: $result');
    return result;
  }
}
