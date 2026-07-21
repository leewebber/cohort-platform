import '../../../data/repositories/programme_adaptation_event_store.dart';
import '../../../data/repositories/programme_adaptation_event_supabase_store.dart';
import '../models/programme_adaptation_event.dart';

/// Resolves athlete-specific prescription overrides from adaptation events.
class AdaptationPrescriptionService {
  AdaptationPrescriptionService({
    ProgrammeAdaptationEventStore? adaptationEventStore,
  }) : _adaptationEventStore =
            adaptationEventStore ?? const ProgrammeAdaptationEventSupabaseStore();

  final ProgrammeAdaptationEventStore _adaptationEventStore;

  Future<Map<String, String>> loadLoadOverrides({
    required String assignmentId,
    required String sessionSlotId,
  }) async {
    final event = await _adaptationEventStore.getPrescriptionForSlot(
      assignmentId: assignmentId,
      sessionSlotId: sessionSlotId,
    );

    if (event == null ||
        event.adaptationType != ProgrammeAdaptationType.loadProgression) {
      return const {};
    }

    final exerciseId = event.payload['exerciseId']?.toString();
    final newLoadKg = event.payload['newLoadKg'];
    if (exerciseId == null || exerciseId.isEmpty || newLoadKg == null) {
      return const {};
    }

    final formatted = newLoadKg is num
        ? '${_formatLoad(newLoadKg.toDouble())} kg'
        : newLoadKg.toString();

    return {exerciseId: formatted};
  }

  Future<ProgrammeAdaptationEvent?> getLatestForAssignment(
    String assignmentId,
  ) {
    return _adaptationEventStore.getLatestForAssignment(assignmentId);
  }

  String _formatLoad(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
