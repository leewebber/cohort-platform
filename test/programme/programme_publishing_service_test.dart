import 'package:cohort_platform/data/repositories/programme_store_exception.dart';
import 'package:cohort_platform/features/programme/services/programme_publishing_service_impl.dart';
import 'package:cohort_platform/models/programme_lineage.dart';
import 'package:cohort_platform/models/programme_version.dart';
import 'package:cohort_platform/models/programme_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/in_memory_programme_stores.dart';

void main() {
  late InMemoryProgrammeTables tables;
  late InMemoryProgrammeVersionStore store;
  late ProgrammePublishingServiceImpl publishing;

  ProgrammeVersion draftVersion({
    String id = 'version-1',
    String ownerId = 'coach-1',
  }) {
    return ProgrammeVersion(
      id: id,
      lineageId: 'lineage-1',
      versionNumber: 1,
      lifecycleStatus: ProgrammeLifecycleStatus.draft,
      libraryScope: ProgrammeLibraryScope.coachPrivate,
      ownerType: ProgrammeOwnerType.coach,
      ownerId: ownerId,
      name: 'Foundation Test',
      createdBy: ownerId,
    );
  }

  setUp(() {
    tables = InMemoryProgrammeTables();
    tables.lineages.add(
      const ProgrammeLineage(
        id: 'lineage-1',
        code: 'COHORT-TEST',
        createdBy: 'coach-1',
      ),
    );
    tables.versions.add(draftVersion());
    store = InMemoryProgrammeVersionStore(tables);
    publishing = ProgrammePublishingServiceImpl(versionStore: store);
  });

  group('ProgrammePublishingServiceImpl', () {
    test(
      'authorised coach publish sets published state and published_at',
      () async {
        final published = await publishing.publishDraft(
          versionId: 'version-1',
          publishedByCoachId: 'coach-1',
        );

        expect(published.lifecycleStatus, ProgrammeLifecycleStatus.published);
        expect(published.publishedAt, isNotNull);

        final reloaded = await store.getVersionById('version-1');
        expect(reloaded?.lifecycleStatus, ProgrammeLifecycleStatus.published);
        expect(reloaded?.publishedAt, isNotNull);
      },
    );

    test('unauthorised write denial surfaces as store failure', () async {
      tables.denyWrites = true;

      expect(
        () => publishing.publishDraft(
          versionId: 'version-1',
          publishedByCoachId: 'coach-1',
        ),
        throwsA(
          isA<ProgrammeStoreException>().having(
            (error) => error.isAccessDenied,
            'access denied',
            isTrue,
          ),
        ),
      );
    });

    test('repository returns updated published row after save', () async {
      final published = await publishing.publishDraft(
        versionId: 'version-1',
        publishedByCoachId: 'coach-1',
      );

      expect(published.id, 'version-1');
      expect(published.isPublished, isTrue);
    });
  });
}
