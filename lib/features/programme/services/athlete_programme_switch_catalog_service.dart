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

  /// Lists Sprint 1.2 / 1.3 catalogue-eligible programmes for athlete enrolment.
  ///
  /// Requires published + cohort_global + approved_for_global (server RLS also
  /// enforces this for athletes). Not a commercial catalogue.
  Future<List<ProgrammeCatalogEntry>>
  listPublishedAssignableProgrammes() async {
    final entries = await _catalogService.listCatalogue(
      query: const ProgrammeCatalogueQuery(
        lifecycleStatus: ProgrammeLifecycleStatus.published,
        libraryScope: ProgrammeLibraryScope.cohortGlobal,
        includeGlobalApprovedOnly: true,
      ),
    );

    return entries
        .where(_isEligibleForAthleteCatalogue)
        .toList(growable: false);
  }

  bool _isEligibleForAthleteCatalogue(ProgrammeCatalogEntry entry) {
    if (entry.lifecycleStatus != ProgrammeLifecycleStatus.published) {
      return false;
    }
    if (entry.libraryScope != ProgrammeLibraryScope.cohortGlobal) {
      return false;
    }
    if (!entry.approvedForGlobal) {
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
