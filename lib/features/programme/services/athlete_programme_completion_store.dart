/// Persistence boundary for Sprint 1.5A atomic completion + advancement.
abstract class AthleteProgrammeCompletionStore {
  Future<Map<String, dynamic>> completeAndAdvance(Map<String, dynamic> payload);
}
