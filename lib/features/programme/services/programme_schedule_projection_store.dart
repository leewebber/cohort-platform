import '../models/programme_schedule_persistence.dart';

/// Persistence port for Sprint 1.7C durable schedule projection.
///
/// Sole durable write capability exposed here is idempotent baseline ensure.
/// There is intentionally no generic save/replace/apply projection writer.
abstract class ProgrammeScheduleProjectionStore {
  Future<ProgrammeSchedulePersistenceResult> ensureBaseline({
    required String programmeAssignmentId,
  });
}
