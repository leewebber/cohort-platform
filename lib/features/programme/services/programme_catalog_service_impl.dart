import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_vocabulary.dart';
import '../models/programme_catalog_entry.dart';
import 'programme_catalog_entry_mapper.dart';
import 'programme_catalog_service.dart';

/// Read-only catalogue backed by [ProgrammeVersionStore].
class ProgrammeCatalogServiceImpl implements ProgrammeCatalogService {
  ProgrammeCatalogServiceImpl({
    required ProgrammeVersionStore versionStore,
    required String coachId,
  })  : _versionStore = versionStore,
        _coachId = coachId;

  final ProgrammeVersionStore _versionStore;
  final String _coachId;

  @override
  Future<List<ProgrammeCatalogEntry>> listCatalogue({
    required ProgrammeCatalogueQuery query,
    ProgrammeLifecycleStatus? lifecycleStatus,
  }) async {
    final mergedQuery = query.copyWith(
      lifecycleStatus: lifecycleStatus ?? query.lifecycleStatus,
    );

    final entries = await _versionStore.listCatalogueVersions(mergedQuery);

    return entries
        .map(
          (entry) => entry.copyWith(
            ownerDisplayLabel: programmeCatalogOwnerDisplayLabel(
              entry: entry,
              coachId: _coachId,
            ),
          ),
        )
        .toList();
  }

  @override
  Future<ProgrammeCatalogEntry?> getEntry({
    required String lineageCode,
    required int versionNumber,
  }) async {
    final version = await _versionStore.getVersionByLineageAndNumber(
      lineageCode: lineageCode,
      versionNumber: versionNumber,
    );

    if (version == null) return null;

    final entries = await listCatalogue(
      query: ProgrammeCatalogueQuery(
        searchTerm: lineageCode,
        lifecycleStatus: version.lifecycleStatus,
      ),
      lifecycleStatus: version.lifecycleStatus,
    );

    for (final entry in entries) {
      if (entry.versionId == version.id) {
        return entry;
      }
    }

    return null;
  }
}
