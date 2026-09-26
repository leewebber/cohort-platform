import '../../../core/services/supabase_service.dart';
import '../models/athlete_catalogue_enrolment.dart';

abstract class PrivateProgrammeEnrolmentStore {
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    required String timezone,
    required DateTime localStartDate,
    required bool replaceActive,
  });
}

class PrivateProgrammeEnrolmentSupabaseStore
    implements PrivateProgrammeEnrolmentStore {
  const PrivateProgrammeEnrolmentSupabaseStore();

  static const rpcName = 'enrol_athlete_in_private_programme_version';

  @override
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    required String timezone,
    required DateTime localStartDate,
    required bool replaceActive,
  }) async {
    final version = programmeVersionId.trim();
    if (version.isEmpty) {
      return const AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.validationFailure,
        code: 'invalid_args',
        message: 'Choose a private programme to activate.',
      );
    }
    try {
      final y = localStartDate.year.toString().padLeft(4, '0');
      final m = localStartDate.month.toString().padLeft(2, '0');
      final d = localStartDate.day.toString().padLeft(2, '0');
      final response = await SupabaseService.client.rpc(
        rpcName,
        params: {
          'p_programme_version_id': version,
          'p_timezone': timezone,
          'p_started_at': '$y-$m-$d',
          'p_replace_active': replaceActive,
        },
      );
      final map = response is Map<String, dynamic>
          ? response
          : response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};
      if (map.isEmpty) {
        return const AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.failed,
          message: 'Activation could not be completed. Please try again.',
        );
      }
      return AthleteCatalogueEnrolmentResult.fromRpcMap(map);
    } catch (error) {
      final text = error.toString();
      if (text.contains('JWT') || text.contains('not authenticated')) {
        return const AthleteCatalogueEnrolmentResult(
          status: AthleteCatalogueEnrolmentStatus.authorizationFailure,
          code: 'not_authenticated',
          message: 'Sign in to activate a private programme.',
        );
      }
      return AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.failed,
        code: 'client_error',
        message: 'Activation could not be completed. Please try again.',
      );
    }
  }
}
