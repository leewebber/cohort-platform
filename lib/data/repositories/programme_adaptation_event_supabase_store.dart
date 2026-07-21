import '../../core/services/supabase_service.dart';
import '../../core/utils/database_uuid.dart';
import '../../features/adaptation/models/programme_adaptation_event.dart';
import 'programme_adaptation_event_store.dart';
import 'programme_store_exception.dart';

class ProgrammeAdaptationEventSupabaseStore implements ProgrammeAdaptationEventStore {
  const ProgrammeAdaptationEventSupabaseStore();

  static const _tableName = 'programme_adaptation_events';

  @override
  Future<ProgrammeAdaptationEvent?> getByTriggerSession({
    required String assignmentId,
    required int triggerTrainingSessionId,
  }) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('assignment_id', assignmentId.trim())
          .eq('trigger_training_session_id', triggerTrainingSessionId)
          .maybeSingle();

      if (response == null) return null;
      return ProgrammeAdaptationEvent.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch programme adaptation event',
      );
    }
  }

  @override
  Future<ProgrammeAdaptationEvent?> getLatestForAssignment(
    String assignmentId,
  ) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('assignment_id', assignmentId.trim())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return ProgrammeAdaptationEvent.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch latest programme adaptation event',
      );
    }
  }

  @override
  Future<ProgrammeAdaptationEvent?> getPrescriptionForSlot({
    required String assignmentId,
    required String sessionSlotId,
  }) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('assignment_id', assignmentId.trim())
          .contains('affected_slot_ids', [sessionSlotId.trim()])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return ProgrammeAdaptationEvent.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch slot prescription adaptation',
      );
    }
  }

  @override
  Future<ProgrammeAdaptationEvent> insert(ProgrammeAdaptationEvent event) async {
    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .insert(event.toInsertMap())
          .select()
          .single();

      return ProgrammeAdaptationEvent.fromMap(Map<String, dynamic>.from(response));
    } catch (error) {
      throw ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to insert programme adaptation event',
      );
    }
  }
}

/// In-memory store for unit tests.
class InMemoryProgrammeAdaptationEventStore implements ProgrammeAdaptationEventStore {
  InMemoryProgrammeAdaptationEventStore(this.events);

  final List<ProgrammeAdaptationEvent> events;

  @override
  Future<ProgrammeAdaptationEvent?> getByTriggerSession({
    required String assignmentId,
    required int triggerTrainingSessionId,
  }) async {
    for (final event in events) {
      if (event.assignmentId == assignmentId &&
          event.triggerTrainingSessionId == triggerTrainingSessionId) {
        return event;
      }
    }
    return null;
  }

  @override
  Future<ProgrammeAdaptationEvent?> getLatestForAssignment(
    String assignmentId,
  ) async {
    ProgrammeAdaptationEvent? latest;
    for (final event in events) {
      if (event.assignmentId != assignmentId) continue;
      if (latest == null ||
          (event.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .isAfter(latest.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))) {
        latest = event;
      }
    }
    return latest;
  }

  @override
  Future<ProgrammeAdaptationEvent?> getPrescriptionForSlot({
    required String assignmentId,
    required String sessionSlotId,
  }) async {
    ProgrammeAdaptationEvent? latest;
    for (final event in events) {
      if (event.assignmentId != assignmentId) continue;
      if (!event.affectedSlotIds.contains(sessionSlotId)) continue;
      if (latest == null ||
          (event.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .isAfter(latest.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))) {
        latest = event;
      }
    }
    return latest;
  }

  @override
  Future<ProgrammeAdaptationEvent> insert(ProgrammeAdaptationEvent event) async {
    final persisted = ProgrammeAdaptationEvent(
      id: event.id.isEmpty ? DatabaseUuid.newV4() : event.id,
      assignmentId: event.assignmentId,
      athleteId: event.athleteId,
      triggerTrainingSessionId: event.triggerTrainingSessionId,
      adaptationType: event.adaptationType,
      explanation: event.explanation,
      athleteSummary: event.athleteSummary,
      affectedSlotIds: event.affectedSlotIds,
      payload: event.payload,
      triggerSlotId: event.triggerSlotId,
      createdAt: event.createdAt ?? DateTime.now().toUtc(),
    );
    events.add(persisted);
    return persisted;
  }
}
