import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';

abstract class RunningTargetAdmissionStore {
  Future<Map<String, dynamic>> review(String occurrenceId);
  Future<void> confirmZone(int? lower, int? upper, {bool withdraw = false});
}

class SupabaseRunningTargetAdmissionStore
    implements RunningTargetAdmissionStore, QualityRunningTargetAdmissionStore {
  SupabaseRunningTargetAdmissionStore({
    required this.athleteId,
    SupabaseClient? client,
  }) : _client = client ?? SupabaseService.client;
  final String athleteId;
  final SupabaseClient _client;
  void _owner() {
    if (_client.auth.currentUser?.id != athleteId) {
      throw StateError('Sign in to the workout account.');
    }
  }

  @override
  Future<Map<String, dynamic>> review(String occurrenceId) async {
    _owner();
    final result = await _client.rpc(
      'review_running_zone2_targets',
      params: {'p_occurrence_id': occurrenceId},
    );
    _owner();
    if (result is! Map) {
      throw const FormatException('Running target review is unavailable.');
    }
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<void> confirmZone(
    int? lower,
    int? upper, {
    bool withdraw = false,
  }) async {
    _owner();
    await _client.rpc(
      'confirm_running_zone2',
      params: {
        'p_expected_athlete_id': athleteId,
        'p_lower_bpm': lower,
        'p_upper_bpm': upper,
        'p_withdraw': withdraw,
      },
    );
    _owner();
  }

  @override
  Future<Map<String, dynamic>> reviewQuality(
    String occurrenceId,
    String source,
  ) async {
    _owner();
    final raw = await _client.rpc(
      'review_running_quality_targets',
      params: {'p_occurrence_id': occurrenceId, 'p_target_source': source},
    );
    _owner();
    if (raw is! Map) {
      throw const FormatException('Quality target review is unavailable.');
    }
    return Map<String, dynamic>.from(raw);
  }

  @override
  Future<void> confirmQuality({
    required String kind,
    int? seconds,
    String? date,
    bool? sustained,
    bool withdraw = false,
    String? manualOrigin,
  }) async {
    _owner();
    await _client.rpc(
      'confirm_running_quality_input',
      params: {
        'p_expected_athlete_id': athleteId,
        'p_input_kind': kind,
        'p_seconds': seconds,
        'p_result_date': date,
        'p_sustained': sustained,
        'p_withdraw': withdraw,
        'p_manual_origin': manualOrigin,
      },
    );
    _owner();
  }
}

abstract class QualityRunningTargetAdmissionStore {
  Future<Map<String, dynamic>> reviewQuality(
    String occurrenceId,
    String source,
  );
  Future<void> confirmQuality({
    required String kind,
    int? seconds,
    String? date,
    bool? sustained,
    bool withdraw = false,
    String? manualOrigin,
  });
}
