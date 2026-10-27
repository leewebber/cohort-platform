import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

class AcquisitionException implements Exception {
  const AcquisitionException(this.code);
  final String code;

  String get message => switch (code) {
    'session_expired' => 'Your session has expired. Sign in again to continue.',
    'access_denied' => 'This programme is not available to your account.',
    'onboarding_required' =>
      'Complete training setup before getting a programme.',
    'invalid_timezone' => 'Choose a valid training timezone.',
    'active_enrolment_exists' =>
      'You already have an active programme. Your current training is unchanged.',
    'programme_unavailable' => 'This programme is not ready to start yet.',
    _ =>
      'This is unavailable right now. Your training is unchanged. Please retry.',
  };
}

class TrainingSetup {
  const TrainingSetup({this.timezone, this.complete = false});
  final String? timezone;
  final bool complete;
}

class PrivateProgrammeOffer {
  const PrivateProgrammeOffer({
    required this.versionId,
    required this.title,
    required this.ready,
    this.summary,
    this.durationWeeks,
    this.sessionsPerWeek,
    this.equipment,
    this.level,
    this.assignmentId,
    this.timezone,
  });
  final String versionId;
  final String title;
  final bool ready;
  final String? summary;
  final int? durationWeeks;
  final int? sessionsPerWeek;
  final String? equipment;
  final String? level;
  final String? assignmentId;
  final String? timezone;

  factory PrivateProgrammeOffer.fromMap(Map<String, dynamic> m) =>
      PrivateProgrammeOffer(
        versionId: m['version_id'] as String,
        title: m['title'] as String,
        ready: m['ready'] == true,
        summary: m['summary'] as String?,
        durationWeeks: m['duration_weeks'] as int?,
        sessionsPerWeek: m['sessions_per_week'] as int?,
        equipment: m['equipment'] as String?,
        level: m['level'] as String?,
        assignmentId: m['assignment_id'] as String?,
        timezone: m['timezone'] as String?,
      );
}

abstract class AcquisitionStore {
  Future<TrainingSetup> loadSetup();
  Future<TrainingSetup> saveSetup(String timezone, {required bool complete});
  Future<List<PrivateProgrammeOffer>> catalogue({String? versionId});
  Future<String> acquire(String versionId, DateTime startDate);
}

class SupabaseAcquisitionStore implements AcquisitionStore {
  SupabaseAcquisitionStore({required this.athleteId, this.client});
  final String athleteId;
  final SupabaseClient? client;
  SupabaseClient get _resolvedClient => client ?? SupabaseService.client;

  Future<Map<String, dynamic>> _call(
    String rpc, [
    Map<String, dynamic>? params,
  ]) async {
    try {
      if (_resolvedClient.auth.currentUser?.id != athleteId) {
        throw const AcquisitionException('session_expired');
      }
      final raw = await _resolvedClient.rpc(
        rpc,
        params: {...?params, 'p_expected_athlete_id': athleteId},
      );
      if (raw is! Map) throw const AcquisitionException('unavailable');
      final result = Map<String, dynamic>.from(raw);
      if (!['ok', 'enrolled', 'already_enrolled'].contains(result['status'])) {
        throw AcquisitionException(
          result['status'] as String? ?? 'unavailable',
        );
      }
      return result;
    } on AcquisitionException {
      rethrow;
    } on AuthException {
      throw const AcquisitionException('session_expired');
    } on PostgrestException catch (e) {
      throw AcquisitionException(
        ['PGRST301', 'PGRST303', '42501'].contains(e.code)
            ? 'session_expired'
            : 'unavailable',
      );
    } catch (_) {
      throw const AcquisitionException('unavailable');
    }
  }

  TrainingSetup _setup(Map<String, dynamic> m) => TrainingSetup(
    timezone: m['timezone'] as String?,
    complete: m['complete'] == true,
  );
  @override
  Future<TrainingSetup> loadSetup() async =>
      _setup(await _call('read_my_training_setup'));
  @override
  Future<TrainingSetup> saveSetup(
    String timezone, {
    required bool complete,
  }) async => _setup(
    await _call('save_my_training_setup', {
      'p_timezone': timezone,
      'p_complete': complete,
    }),
  );
  @override
  Future<List<PrivateProgrammeOffer>> catalogue({String? versionId}) async {
    final m = await _call('read_my_private_programme_catalogue', {
      'p_version_id': versionId,
    });
    return (m['programmes'] as List)
        .map(
          (e) => PrivateProgrammeOffer.fromMap(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  @override
  Future<String> acquire(String versionId, DateTime startDate) async {
    final date =
        '${startDate.year.toString().padLeft(4, '0')}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}';
    final m = await _call('acquire_my_private_programme', {
      'p_version_id': versionId,
      'p_start_date': date,
    });
    if (m['athlete_id'] != athleteId ||
        m['programme_version_id'] != versionId ||
        m['enrolment_id'] is! String) {
      throw const AcquisitionException('unavailable');
    }
    return m['enrolment_id'] as String;
  }
}
