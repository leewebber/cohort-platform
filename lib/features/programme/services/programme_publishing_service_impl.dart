import '../../../data/repositories/programme_store_exception.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_version.dart';
import '../../../models/programme_vocabulary.dart';
import 'programme_publishing_service.dart';

/// Draft → published lifecycle backed by [ProgrammeVersionStore].
class ProgrammePublishingServiceImpl implements ProgrammePublishingService {
  ProgrammePublishingServiceImpl({
    required ProgrammeVersionStore versionStore,
  }) : _versionStore = versionStore;

  final ProgrammeVersionStore _versionStore;

  @override
  Future<ProgrammeVersion> publishDraft({
    required String versionId,
    required String publishedByCoachId,
  }) async {
    final version = await _versionStore.getVersionById(versionId);
    if (version == null) {
      throw ProgrammeStoreException('Programme version not found');
    }

    if (version.lifecycleStatus != ProgrammeLifecycleStatus.draft) {
      throw ProgrammeStoreException('Only draft versions can be published');
    }

    final now = DateTime.now().toUtc();
    final published = version.copyWith(
      lifecycleStatus: ProgrammeLifecycleStatus.published,
      publishedAt: now,
      updatedAt: now,
    );

    return _versionStore.saveDraftVersion(published);
  }

  @override
  Future<ProgrammeVersion> archiveVersion(String versionId) async {
    final version = await _versionStore.getVersionById(versionId);
    if (version == null) {
      throw ProgrammeStoreException('Programme version not found');
    }

    if (version.lifecycleStatus != ProgrammeLifecycleStatus.published) {
      throw ProgrammeStoreException('Only published versions can be archived');
    }

    final now = DateTime.now().toUtc();
    final archived = version.copyWith(
      lifecycleStatus: ProgrammeLifecycleStatus.archived,
      archivedAt: now,
      updatedAt: now,
    );

    return _versionStore.saveDraftVersion(archived);
  }

  @override
  Future<ProgrammeVersion> cloneToNewDraft({
    required String publishedVersionId,
  }) async {
    final published = await _versionStore.getVersionById(publishedVersionId);
    if (published == null) {
      throw ProgrammeStoreException('Published programme version not found');
    }

    if (published.lifecycleStatus != ProgrammeLifecycleStatus.published) {
      throw ProgrammeStoreException('Only published versions can be cloned');
    }

    final tree = await _versionStore.loadTemplateTree(publishedVersionId);
    if (tree == null) {
      throw ProgrammeStoreException('Published programme template not found');
    }

    final draft = published.copyWith(
      id: '',
      versionNumber: published.versionNumber + 1,
      lifecycleStatus: ProgrammeLifecycleStatus.draft,
      publishedAt: null,
      archivedAt: null,
      updatedAt: DateTime.now().toUtc(),
      clearPublishedAt: true,
      clearArchivedAt: true,
    );

    final savedDraft = await _versionStore.saveDraftVersion(draft);
    await _versionStore.saveTemplateTree(version: savedDraft, tree: tree);

    return savedDraft;
  }
}
