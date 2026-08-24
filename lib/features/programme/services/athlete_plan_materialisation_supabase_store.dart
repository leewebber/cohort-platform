import '../../../core/services/supabase_service.dart';
import '../models/athlete_plan_materialisation.dart';
import 'athlete_plan_materialisation_store.dart';

class AthletePlanMaterialisationSupabaseStore
    implements AthletePlanMaterialisationStore {
  const AthletePlanMaterialisationSupabaseStore();

  static const _rpcName = 'start_fixed_programme_from_enrolment';

  @override
  Future<AthletePlanMaterialisationResult> materialise({
    required String programmeAssignmentId,
    String? timezone,
    DateTime? startDate,
  }) async {
    final trimmed = programmeAssignmentId.trim();
    if (trimmed.isEmpty) {
      return const AthletePlanMaterialisationResult(
        status: AthletePlanMaterialisationStatus.validationFailure,
        code: 'invalid_args',
        message: 'Choose a programme enrolment to start.',
      );
    }

    try {
      final response = await SupabaseService.client.rpc(
        _rpcName,
        params: {
          'p_programme_assignment_id': trimmed,
          'p_timezone': timezone,
          'p_start_date': _dateOnly(startDate),
        },
      );

      if (response is Map<String, dynamic>) {
        return AthletePlanMaterialisationResult.fromRpcMap(response);
      }
      if (response is Map) {
        return AthletePlanMaterialisationResult.fromRpcMap(
          Map<String, dynamic>.from(response),
        );
      }

      return const AthletePlanMaterialisationResult(
        status: AthletePlanMaterialisationStatus.failed,
        message: 'The programme could not be started. Please try again.',
      );
    } catch (error) {
      return AthletePlanMaterialisationResult(
        status: AthletePlanMaterialisationStatus.failed,
        code: 'client_error',
        message: _mapError(error),
      );
    }
  }

  String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  String _mapError(Object error) {
    final text = error.toString();
    if (text.contains('JWT') || text.contains('not authenticated')) {
      return 'Sign in to start your programme.';
    }
    if (text.contains('network') || text.contains('SocketException')) {
      return 'Network error. Check your connection and try again.';
    }
    return 'The programme could not be started. Please try again.';
  }
}
