import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/services/supabase_service.dart';
import '../../core/utils/database_uuid.dart';
import '../../features/adaptation/models/programme_adaptation_event.dart';
import 'programme_adaptation_event_store.dart';
import 'programme_store_exception.dart';

class ProgrammeAdaptationEventSupabaseStore implements ProgrammeAdaptationEventStore {
  const ProgrammeAdaptationEventSupabaseStore();

  static const _tableName = 'programme_adaptation_events';

  /// PostgREST `cs` filter value for JSONB array containment (`@>`).
  ///
  /// Must be JSON text — passing a Dart [List] to `.contains()` would emit
  /// Postgres array syntax `{…}`, which is invalid for a JSONB column (22P02).
  @visibleForTesting
  static String jsonbArrayContainsFilter(List<String> values) {
    return jsonEncode(values);
  }

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
    final trimmedAssignmentId = assignmentId.trim();
    final trimmedSlotId = sessionSlotId.trim();

    if (!DatabaseUuid.isValidDatabaseUuid(trimmedAssignmentId) ||
        trimmedSlotId.isEmpty) {
      debugPrint(
        '[ProgrammeAdaptationEvent] getPrescriptionForSlot skipped '
        'assignment_id=$trimmedAssignmentId session_slot_id=$trimmedSlotId',
      );
      return null;
    }

    final jsonbSlotFilter = jsonbArrayContainsFilter([trimmedSlotId]);
    debugPrint(
      '[ProgrammeAdaptationEvent] getPrescriptionForSlot '
      'assignment_id=$trimmedAssignmentId '
      'session_slot_id=$trimmedSlotId '
      'affected_slot_ids_cs=$jsonbSlotFilter',
    );

    try {
      final response = await SupabaseService.client
          .from(_tableName)
          .select()
          .eq('assignment_id', trimmedAssignmentId)
          .contains('affected_slot_ids', jsonbSlotFilter)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return ProgrammeAdaptationEvent.fromMap(Map<String, dynamic>.from(response));
    } on ProgrammeStoreException catch (error) {
      if (error.code == '22P02') {
        debugPrint(
          '[ProgrammeAdaptationEvent] getPrescriptionForSlot invalid filter '
          'assignment_id=$trimmedAssignmentId session_slot_id=$trimmedSlotId',
        );
        return null;
      }
      rethrow;
    } catch (error) {
      final wrapped = ProgrammeStoreException.fromDynamic(
        error,
        fallbackMessage: 'Failed to fetch slot prescription adaptation',
        operation: 'getPrescriptionForSlot',
        tableName: _tableName,
      );
      if (wrapped.code == '22P02') {
        debugPrint(
          '[ProgrammeAdaptationEvent] getPrescriptionForSlot invalid filter '
          'assignment_id=$trimmedAssignmentId session_slot_id=$trimmedSlotId',
        );
        return null;
      }
      throw wrapped;
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
