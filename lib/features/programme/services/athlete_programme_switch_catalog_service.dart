import '../../../models/programme_vocabulary.dart';
import '../models/programme_catalog_entry.dart';
import 'programme_catalog_service.dart';

/// Read-only catalogue filtering for athlete self-service programme switching.
///
/// Assignment mutations stay in [ProgrammeAssignmentService].
class AthleteProgrammeSwitchCatalogService {
  const AthleteProgrammeSwitchCatalogService({
    required ProgrammeCatalogService catalogService,
  }) : _catalogService = catalogService;

  final ProgrammeCatalogService _catalogService;

  Future<List<ProgrammeCatalogEntry>> listPublishedAssignableProgrammes() async {
    final entries = await _catalogService.listCatalogue(
      query: const ProgrammeCatalogueQuery(
        lifecycleStatus: ProgrammeLifecycleStatus.published,
      ),
    );

    return entries.where(_isEligibleForAthleteSwitch).toList(growable: false);
  }

  bool _isEligibleForAthleteSwitch(ProgrammeCatalogEntry entry) {
    if (entry.lifecycleStatus != ProgrammeLifecycleStatus.published) {
      return false;
    }
    if (entry.archivedAt != null) {
      return false;
    }
    if (entry.hasBlockingValidationErrors) {
      return false;
    }
    return true;
  }
}
