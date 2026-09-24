import '../../../core/services/authenticated_identity.dart';

/// Production athlete identity for Home, Progress, History, and shell.
///
/// Tests and fixture previews may pass an explicit [override]. Production
/// code must not substitute a synthetic or cached athlete id.
abstract final class AthleteSurfaceIdentity {
  static String require({String? override}) {
    final explicit = override?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return AuthenticatedIdentity.requireAthleteId();
  }
}
