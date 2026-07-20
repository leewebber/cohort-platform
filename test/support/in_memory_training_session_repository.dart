import 'package:cohort_platform/data/repositories/training_session_repository.dart';
import 'package:cohort_platform/models/training_session.dart';
import 'package:cohort_platform/models/training_session_status.dart';

/// In-memory [TrainingSessionRepository] for founder reset tests.
class InMemoryTrainingSessionRepository extends TrainingSessionRepository {
  InMemoryTrainingSessionRepository();

  final List<TrainingSession> sessions = <TrainingSession>[];
  int _nextId = 1000;

  TrainingSession seed({
    required String athleteId,
    required String protocolId,
    TrainingSessionStatus status = TrainingSessionStatus.planned,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    final session = TrainingSession(
      id: _nextId++,
      athleteId: athleteId,
      protocolId: protocolId,
      status: status,
      startedAt: startedAt,
      completedAt: completedAt,
      createdAt: DateTime.now().toUtc(),
    );
    sessions.add(session);
    return session;
  }

  @override
  Future<TrainingSession?> getLatestSessionForAthleteAndProtocol({
    required String athleteId,
    required String protocolId,
  }) async {
    TrainingSession? latest;
    for (final session in sessions) {
      if (session.athleteId != athleteId || session.protocolId != protocolId) {
        continue;
      }
      if (latest == null ||
          (session.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .isAfter(latest.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))) {
        latest = session;
      }
    }
    return latest;
  }

  @override
  Future<int> deleteForAthleteAndProtocol({
    required String athleteId,
    required String protocolId,
  }) async {
    final before = sessions.length;
    sessions.removeWhere(
      (session) =>
          session.athleteId == athleteId && session.protocolId == protocolId,
    );
    return before - sessions.length;
  }
}
