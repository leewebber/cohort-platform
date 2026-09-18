import 'package:cohort_platform/domain/content_graph/content_graph_manifest.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_models.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_service.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_vocabulary.dart';
import 'package:cohort_platform/domain/content_graph/in_memory_content_graph_store.dart';
import 'package:cohort_platform/domain/content_graph/m9_content_graph_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryContentGraphStore store;
  late ContentGraphService service;

  setUp(() {
    store = InMemoryContentGraphStore();
    service = M9ContentGraphFixtures.seed(store: store);
  });

  test('same input produces byte-identical manifests and graph hashes', () {
    final first = service.compileDraft(M9ContentGraphFixtures.v1Id);
    final second = service.compileDraft(M9ContentGraphFixtures.v1Id);
    expect(first.canonicalJson, second.canonicalJson);
    expect(first.sha256, second.sha256);
    expect(
      first.manifest.compositeContentIdentity,
      second.manifest.compositeContentIdentity,
    );
  });

  test('edge and node order cannot change the graph hash', () {
    final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
    final reversed = StructuralContentGraph(
      nodes: compiled.graph.nodes.reversed.toList(),
      edges: compiled.graph.edges.reversed.toList(),
    );
    final version = store.programmeVersion(M9ContentGraphFixtures.v1Id)!;
    final json = service.canonicaliser.canonicalJson(
      version: version,
      placements: store.placementsForVersion(version.id).toList(),
      sessionVersions: [
        store.sessionTemplateVersion(M9ContentGraphFixtures.sessionV1Id)!,
      ],
      blocks: store
          .blocksForSessionVersion(M9ContentGraphFixtures.sessionV1Id)
          .toList(),
      graph: reversed,
    );
    expect(service.canonicaliser.sha256Hex(json), compiled.sha256);
  });

  test('package/source change changes composite identity', () {
    final before = service.compileDraft(M9ContentGraphFixtures.v1Id);
    final draft = service.cloneDraftFromPublished(
      actor: M9ContentGraphFixtures.firstParty,
      publishedVersionId: M9ContentGraphFixtures.v1Id,
      draftVersionId: 'draft-package',
    );
    store.putProgrammeVersion(
      store.programmeVersion(draft.id)!.copyWith(
        sourcePackageHash: 'abcd' * 16,
      ),
    );
    final after = service.compileDraft(draft.id);
    expect(after.sha256, before.sha256);
    expect(
      after.manifest.compositeContentIdentity,
      isNot(before.manifest.compositeContentIdentity),
    );
  });

  test('supplemental relationship change changes graph/composite hash', () {
    final before = service.compileDraft(M9ContentGraphFixtures.v1Id);
    M9ContentGraphFixtures.forkSessionTemplateRevision(store);
    final draft = service.cloneDraftFromPublished(
      actor: M9ContentGraphFixtures.firstParty,
      publishedVersionId: M9ContentGraphFixtures.v1Id,
      draftVersionId: 'draft-supp',
    );
    store.putPlacement(
      store.placementsForVersion(draft.id).single.copyWith(
        sessionTemplateVersionId: M9ContentGraphFixtures.sessionV2Id,
      ),
    );
    service.rebindSupplementalFromGraph(draft.id);
    final after = service.compileDraft(draft.id);
    expect(after.sha256, isNot(before.sha256));
    expect(
      after.manifest.compositeContentIdentity,
      isNot(before.manifest.compositeContentIdentity),
    );
  });

  test('stale graph is rejected', () {
    final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
    expect(
      () => service.validateManifest(
        compiled.manifest.copyWith(graphCanonicalSha256: 'deadbeef'),
        programmeVersionId: M9ContentGraphFixtures.v1Id,
      ),
      throwsA(
        isA<ContentGraphException>().having(
          (e) => e.code,
          'code',
          ContentGraphFailureCode.staleGraph,
        ),
      ),
    );
  });

  test('mismatched package is rejected', () {
    final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
    expect(
      () => service.validateManifest(
        compiled.manifest.copyWith(sourceCanonicalContentSha256: 'ff' * 32),
        programmeVersionId: M9ContentGraphFixtures.v1Id,
      ),
      throwsA(
        isA<ContentGraphException>().having(
          (e) => e.code,
          'code',
          ContentGraphFailureCode.sourceHashMismatch,
        ),
      ),
    );
  });

  test('missing supplemental hash is rejected', () {
    final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
    expect(
      () => service.validateManifest(
        compiled.manifest.copyWith(supplementalRelationshipSha256: ''),
        programmeVersionId: M9ContentGraphFixtures.v1Id,
      ),
      throwsA(
        isA<ContentGraphException>().having(
          (e) => e.code,
          'code',
          ContentGraphFailureCode.missingSourceHash,
        ),
      ),
    );
  });

  test('missing source hash is rejected', () {
    final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
    expect(
      () => service.validateManifest(
        compiled.manifest.copyWith(sourceCanonicalContentSha256: ''),
        programmeVersionId: M9ContentGraphFixtures.v1Id,
      ),
      throwsA(
        isA<ContentGraphException>().having(
          (e) => e.code,
          'code',
          ContentGraphFailureCode.missingSourceHash,
        ),
      ),
    );
  });

  test('unsupported graph format/compiler version is rejected', () {
    final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
    expect(
      () => service.validateManifest(
        compiled.manifest.copyWith(compilerVersion: 'content-graph-compiler/v0'),
        programmeVersionId: M9ContentGraphFixtures.v1Id,
      ),
      throwsA(
        isA<ContentGraphException>().having(
          (e) => e.code,
          'code',
          ContentGraphFailureCode.unsupportedCompiler,
        ),
      ),
    );
  });

  test('active-assignment count does not affect graph hash', () {
    final before = service.compileDraft(M9ContentGraphFixtures.v1Id);
    service.enrol(
      assignmentId: 'assignment.extra',
      athleteId: 'athlete.extra',
      programmeId: M9ContentGraphFixtures.programmeId,
    );
    final after = service.compileDraft(M9ContentGraphFixtures.v1Id);
    expect(after.sha256, before.sha256);
    expect(
      after.manifest.compositeContentIdentity,
      before.manifest.compositeContentIdentity,
    );
    expect(
      service.usedByExercise(M9ContentGraphFixtures.exerciseSquat)
          .activeAssignmentCount,
      2,
    );
  });

  test('catalogue visibility does not affect graph hash', () {
    final before = service.compileDraft(M9ContentGraphFixtures.v1Id);
    service.setCatalogueDefaultVersion(
      actor: M9ContentGraphFixtures.firstParty,
      programmeVersionId: M9ContentGraphFixtures.v1Id,
    );
    final after = service.compileDraft(M9ContentGraphFixtures.v1Id);
    expect(after.sha256, before.sha256);
  });

  test('used-by is derived; altered edges fail', () {
    final used = service.usedByExercise(M9ContentGraphFixtures.exerciseSquat);
    expect(
      used.hits.any((h) => h.nodeType == ContentNodeType.programmePlacement),
      isTrue,
    );
    expect(
      used.hits.any((h) => h.nodeType == ContentNodeType.pinnedAssignment),
      isTrue,
    );
    expect(
      () => service.assertDerivedUsedByEdge(
        const ContentGraphEdge(
          type: ContentRelationshipType.exerciseUsedByBlock,
          fromType: ContentNodeType.exercise,
          fromId: M9ContentGraphFixtures.exerciseSquat,
          toType: ContentNodeType.authoredBlock,
          toId: 'block.forged',
        ),
        M9ContentGraphFixtures.v1Id,
      ),
      throwsA(
        isA<ContentGraphException>().having(
          (e) => e.code,
          'code',
          ContentGraphFailureCode.danglingRelationship,
        ),
      ),
    );
  });

  test('graph publication immutability rejects in-place hash edits', () {
    final published = store.programmeVersion(M9ContentGraphFixtures.v1Id)!;
    expect(
      () => store.putProgrammeVersion(
        published.copyWith(canonicalHash: 'mutated'),
      ),
      throwsA(
        isA<ContentGraphException>().having(
          (e) => e.code,
          'code',
          ContentGraphFailureCode.publishedImmutable,
        ),
      ),
    );
  });

  test('fixture source package hash is not the production Apollo package hash', () {
    final compiled = service.compileDraft(M9ContentGraphFixtures.v1Id);
    expect(
      compiled.manifest.sourceCanonicalContentSha256,
      M9ContentGraphFixtures.fixtureSourcePackageHash,
    );
    expect(
      compiled.manifest.sourceCanonicalContentSha256,
      isNot(
        '810334293c72aa2804ebd8bc2a426ca9f3e4977aed3da00989f67ae949dd0b83',
      ),
    );
  });
}
