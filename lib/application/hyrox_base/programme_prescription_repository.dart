import '../../core/services/supabase_service.dart';
import '../../features/session/services/programme_training_session_start_store.dart';
import '../../features/session/services/programme_training_session_start_supabase_store.dart';
import 'benchmark_repository.dart';

/// Authenticated review/consent over the assignment's actual authoritative source.
/// Start delegates to the established store/RPC, never to a new session creator.
class ProgrammePrescriptionRepository {
  ProgrammePrescriptionRepository({
    BaseBenchmarkRpc? rpc,
    ProgrammeTrainingSessionStartStore? starts,
  }) : _rpc = rpc ?? _supabase,
       _starts = starts ?? const ProgrammeTrainingSessionStartSupabaseStore();
  final BaseBenchmarkRpc _rpc;
  final ProgrammeTrainingSessionStartStore _starts;
  static Future<Object?> _supabase(String name, Map<String, Object?> params) =>
      SupabaseService.client.rpc(name, params: params);

  Future<Map<String, Object?>> readState({
    required String assignmentId,
    required String programmeVersionId,
  }) async {
    final result = await _rpc('read_hyrox_programme_prescription_state', {
      'p_assignment_id': assignmentId,
      'p_programme_version_id': programmeVersionId,
    });
    if (result is! Map || result['status'] != 'read') {
      throw StateError('Programme targets are unavailable.');
    }
    return Map<String, Object?>.from(result);
  }

  Future<Map<String, Object?>> review({
    required String assignmentId,
    required String programmeVersionId,
    required Map<String, String?> selectedRevisions,
    int? incrementGrams,
  }) => _call('review_hyrox_programme_prescription', {
    'assignment_id': assignmentId,
    'programme_version_id': programmeVersionId,
    'selected_revisions': selectedRevisions,
    'increment_grams': incrementGrams,
  });

  Future<Map<String, Object?>> consent({
    required String commandId,
    required String assignmentId,
    required String programmeVersionId,
    required String? reviewId,
    required String? expectedConsentId,
    required bool withdraw,
  }) => _call('consent_hyrox_programme_prescription', {
    'command_id': commandId,
    'assignment_id': assignmentId,
    'programme_version_id': programmeVersionId,
    'action': withdraw ? 'withdraw' : 'accept',
    'review_id': reviewId,
    'expected_consent_id': expectedConsentId,
  });

  Future<Map<String, dynamic>> start({
    required String occurrenceId,
    required String consentId,
  }) => _starts.createOrResume({
    'occurrence_id': occurrenceId,
    'bound_consent_id': consentId,
  });

  Future<Map<String, Object?>> _call(
    String name,
    Map<String, Object?> payload,
  ) async {
    final result = await _rpc(name, {'payload': payload});
    if (result is! Map || result['status'] is! String) {
      throw StateError('Malformed programme prescription response.');
    }
    return Map<String, Object?>.from(result);
  }
}
