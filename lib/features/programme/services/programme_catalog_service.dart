import '../models/programme_catalog_entry.dart';

export '../models/programme_catalog_entry.dart'
    show ProgrammeCatalogEntry, ProgrammeCatalogueQuery;

/// Read-only catalogue for Coach Studio and enrolment pickers.
///
/// See `43_Programme_Engine_Service_Contracts.md` §3.1.
abstract class ProgrammeCatalogService {
  Future<List<ProgrammeCatalogEntry>> listPublished({
    required ProgrammeCatalogueQuery query,
  });

  Future<ProgrammeCatalogEntry?> getEntry({
    required String lineageCode,
    required int versionNumber,
  });
}
