import '../../features/programme/models/programme_catalog_entry.dart';
import '../../features/programme/models/programme_template.dart';
import '../../models/programme_lineage.dart';
import '../../models/programme_version.dart';

/// Persistence boundary for versioned programme templates.
///
/// Fetch and persist only — no schedule resolution.
/// See `43_Programme_Engine_Service_Contracts.md` §2.1.
abstract class ProgrammeVersionStore {
  Future<ProgrammeLineage?> getLineageByCode(String code);

  Future<ProgrammeLineage?> getLineageById(String lineageId);

  Future<ProgrammeVersion?> getVersionById(String versionId);

  Future<ProgrammeVersion?> getVersionByLineageAndNumber({
    required String lineageCode,
    required int versionNumber,
  });

  Future<ProgrammeVersion?> getPublishedVersion({
    required String lineageCode,
    required int versionNumber,
  });

  Future<ProgrammeTemplateTree?> loadTemplateTree(String versionId);

  Future<ProgrammeVersion> saveDraftVersion(ProgrammeVersion version);

  Future<void> saveTemplateTree({
    required ProgrammeVersion version,
    required ProgrammeTemplateTree tree,
  });

  Future<List<ProgrammeCatalogEntry>> listCatalogueVersions(
    ProgrammeCatalogueQuery query,
  );

  Future<ProgrammeLineage> insertLineage(ProgrammeLineage lineage);

  Future<void> deleteDraftVersion(String versionId);
}
