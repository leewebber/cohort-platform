import 'package:cohort_platform/data/repositories/programme_adaptation_event_supabase_store.dart';
import 'package:cohort_platform/data/repositories/programme_store_exception.dart';
import 'package:cohort_platform/features/adaptation/models/programme_adaptation_event.dart';
import 'package:cohort_platform/features/adaptation/services/adaptation_prescription_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingAdaptationEventStore extends InMemoryProgrammeAdaptationEventStore {
  _ThrowingAdaptationEventStore() : super([]);

  @override
  Future<ProgrammeAdaptationEvent?> getPrescriptionForSlot({
    required String assignmentId,
    required String sessionSlotId,
  }) {
    throw ProgrammeStoreException(
      'invalid input syntax for type uuid',
      code: '22P02',
    );
  }
}

void main() {
  const assignmentId = '00000000-0000-4000-8000-000000000001';
  const slotId = '00000000-0000-4000-8000-000000000002';

  group('ProgrammeAdaptationEventSupabaseStore', () {
    test('jsonb slot filter uses JSON array syntax not postgres array', () {
      expect(
        ProgrammeAdaptationEventSupabaseStore.jsonbArrayContainsFilter([slotId]),
        '["$slotId"]',
      );
      expect(
        ProgrammeAdaptationEventSupabaseStore.jsonbArrayContainsFilter([slotId]),
        isNot(contains('{')),
      );
    });
  });

  group('AdaptationPrescriptionService', () {
    test('returns empty overrides when no adaptation event exists', () async {
      final service = AdaptationPrescriptionService(
        adaptationEventStore: InMemoryProgrammeAdaptationEventStore([]),
      );

      final overrides = await service.loadLoadOverrides(
        assignmentId: assignmentId,
        sessionSlotId: slotId,
      );

      expect(overrides, isEmpty);
    });

    test('returns load override from load_progression event', () async {
      final store = InMemoryProgrammeAdaptationEventStore([
        ProgrammeAdaptationEvent(
          id: 'event-1',
          assignmentId: assignmentId,
          athleteId: '00000000-0000-4000-8000-000000000099',
          triggerTrainingSessionId: 42,
          adaptationType: ProgrammeAdaptationType.loadProgression,
          explanation: 'Progress load',
          athleteSummary: 'Heavier squat next time',
          affectedSlotIds: [slotId],
          payload: {
            'exerciseId': 'exercise-1',
            'newLoadKg': 100,
          },
        ),
      ]);
      final service = AdaptationPrescriptionService(adaptationEventStore: store);

      final overrides = await service.loadLoadOverrides(
        assignmentId: assignmentId,
        sessionSlotId: slotId,
      );

      expect(overrides, {'exercise-1': '100 kg'});
    });

    test('returns empty overrides when store throws ProgrammeStoreException', () async {
      final service = AdaptationPrescriptionService(
        adaptationEventStore: _ThrowingAdaptationEventStore(),
      );

      final overrides = await service.loadLoadOverrides(
        assignmentId: assignmentId,
        sessionSlotId: slotId,
      );

      expect(overrides, isEmpty);
    });
  });
}
