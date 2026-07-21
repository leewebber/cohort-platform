import '../../features/adaptation/models/programme_adaptation_event.dart';

abstract class ProgrammeAdaptationEventStore {
  const ProgrammeAdaptationEventStore();

  Future<ProgrammeAdaptationEvent?> getByTriggerSession({
    required String assignmentId,
    required int triggerTrainingSessionId,
  });

  Future<ProgrammeAdaptationEvent?> getLatestForAssignment(String assignmentId);

  Future<ProgrammeAdaptationEvent?> getPrescriptionForSlot({
    required String assignmentId,
    required String sessionSlotId,
  });

  Future<ProgrammeAdaptationEvent> insert(ProgrammeAdaptationEvent event);
}
