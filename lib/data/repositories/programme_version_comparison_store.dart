import '../../features/programme_comparison/models/programme_version_comparison_models.dart';
import '../../models/programme_version.dart';

abstract class ProgrammeVersionComparisonStore {
  const ProgrammeVersionComparisonStore();

  Future<ProgrammeVersion?> getVersionById(String programmeVersionId);

  Future<ProgrammeVersionComparisonSnapshot> loadSnapshot(
    String programmeVersionId, {
    bool exerciseEnrichmentAuthoritative = true,
    String? exerciseEnrichmentLimitation,
  });
}

class ProgrammeVersionComparisonStoreException implements Exception {
  const ProgrammeVersionComparisonStoreException(this.message);

  final String message;

  @override
  String toString() => 'ProgrammeVersionComparisonStoreException: $message';
}
