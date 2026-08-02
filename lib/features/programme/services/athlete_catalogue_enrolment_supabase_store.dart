import '../../../core/services/supabase_service.dart';
import '../models/athlete_catalogue_enrolment.dart';
import 'athlete_catalogue_enrolment_store.dart';

class AthleteCatalogueEnrolmentSupabaseStore
    implements AthleteCatalogueEnrolmentStore {
  const AthleteCatalogueEnrolmentSupabaseStore();

  static const _rpcName = 'enrol_athlete_in_catalogue_programme_version';

  @override
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    String? timezone,
    bool replaceActive = false,
  }) async {
    final trimmed = programmeVersionId.trim();
    if (trimmed.isEmpty) {
      return const AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.validationFailure,
        code: 'invalid_args',
        message: 'Choose a programme to enrol.',
      );
    }

    try {
      final response = await SupabaseService.client.rpc(
        _rpcName,
        params: {
          'p_programme_version_id': trimmed,
          'p_timezone': timezone,
          'p_replace_active': replaceActive,
        },
      );

      if (response is Map<String, dynamic>) {
        return AthleteCatalogueEnrolmentResult.fromRpcMap(response);
      }
      if (response is Map) {
        return AthleteCatalogueEnrolmentResult.fromRpcMap(
          Map<String, dynamic>.from(response),
        );
      }

      return const AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.failed,
        message: 'Enrolment could not be completed. Please try again.',
      );
    } catch (error) {
      return AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.failed,
        message: _mapError(error),
        code: 'client_error',
      );
    }
  }

  String _mapError(Object error) {
    final text = error.toString();
    if (text.contains('JWT') || text.contains('not authenticated')) {
      return 'Sign in to enrol in a programme.';
    }
    if (text.contains('network') || text.contains('SocketException')) {
      return 'Network error. Check your connection and try again.';
    }
    return 'Enrolment could not be completed. Please try again.';
  }
}
