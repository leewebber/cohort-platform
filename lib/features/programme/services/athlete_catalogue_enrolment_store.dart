import '../models/athlete_catalogue_enrolment.dart';

/// Persistence port for Sprint 1.3 catalogue enrolment RPC.
abstract class AthleteCatalogueEnrolmentStore {
  /// Enrols the authenticated athlete in [programmeVersionId].
  ///
  /// Athlete identity is derived server-side from `auth.uid()`. Callers must
  /// not supply another athlete id.
  Future<AthleteCatalogueEnrolmentResult> enrol({
    required String programmeVersionId,
    String? timezone,
    bool replaceActive = false,
  });
}
