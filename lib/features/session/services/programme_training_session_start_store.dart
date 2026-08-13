/// Transactional persistence boundary for one programme occurrence start.
abstract class ProgrammeTrainingSessionStartStore {
  Future<Map<String, dynamic>> createOrResume(Map<String, dynamic> payload);
}
