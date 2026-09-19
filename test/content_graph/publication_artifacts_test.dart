import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/domain/content_graph/apollo_local_graph_binder.dart';
import 'package:cohort_platform/domain/content_graph/content_graph_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/content_graph/generate_publication_artifacts.dart';
import '../../tool/content_graph/publication_artifact_builder.dart';

void main() {
  late Map<String, dynamic> index;

  setUpAll(() {
    index = jsonDecode(
      File('content/content_graph/v1/index.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('approved candidate set is closed and hashes agree', () {
    final labels = [
      for (final item in index['candidates'] as List)
        (item as Map)['label'] as String,
    ];
    expect(labels, ['apollo', 'spartan_v3']);

    for (final raw in index['candidates'] as List) {
      final item = Map<String, dynamic>.from(raw as Map);
      final manifest = File(
        'content/content_graph/v1/${item['manifest_path']}',
      ).readAsStringSync();
      final publication = File(
        'content/content_graph/v1/${item['publication_path']}',
      ).readAsStringSync();
      expect(sha256Bytes(manifest), item['manifest_sha256']);
      expect(sha256Bytes(publication), item['publication_sha256']);
      final decoded = jsonDecode(publication) as Map<String, dynamic>;
      expect(decoded['source_package_hash'], item['source_package_hash']);
      expect(
        decoded['supplemental_relationship_hash'],
        item['supplemental_relationship_hash'],
      );
      expect(decoded['graph_structural_hash'], item['graph_structural_hash']);
      expect(decoded['composite_identity'], item['composite_identity']);
      expect(decoded['programme_version_id'], item['programme_version_id']);
      expect(decoded['require_full_resolution'], item['require_full_resolution']);
      expect(containsForbiddenOperationalField(decoded), isFalse);
      expect(jsonDecode(manifest), decoded['canonical_payload']);
    }
  });

  test('checksums.sha256 matches committed files', () {
    final lines = File('content/content_graph/v1/checksums.sha256')
        .readAsLinesSync()
        .where((line) => line.trim().isNotEmpty);
    expect(lines, isNotEmpty);
    for (final line in lines) {
      final hash = line.substring(0, 64);
      final rel = line.substring(66);
      expect(
        sha256Bytes(File('content/content_graph/v1/$rel').readAsStringSync()),
        hash,
      );
    }
  });

  test('regeneration is byte-identical across isolated runs', () {
    final first = Directory.systemTemp.createTempSync('cg-art-1-');
    final second = Directory.systemTemp.createTempSync('cg-art-2-');
    addTearDown(() {
      first.deleteSync(recursive: true);
      second.deleteSync(recursive: true);
    });
    writePublicationArtifacts(root: first.path);
    writePublicationArtifacts(root: second.path);
    for (final name in [
      'index.json',
      'checksums.sha256',
      'cohort_global/apollo/$apolloProgrammeVersionId.manifest.json',
      'cohort_global/apollo/$apolloProgrammeVersionId.publication.json',
      'cohort_global/spartan/$spartanV3ProgrammeVersionId.manifest.json',
      'cohort_global/spartan/$spartanV3ProgrammeVersionId.publication.json',
    ]) {
      final committed = File('content/content_graph/v1/$name').readAsStringSync();
      final a = File('${first.path}/$name').readAsStringSync();
      final b = File('${second.path}/$name').readAsStringSync();
      expect(a, b, reason: '$name isolated runs differ');
      expect(a, committed, reason: '$name differs from committed artifact');
    }
  });

  test('Apollo and Spartan match qualification identities', () {
    const builder = PublicationArtifactBuilder();
    final apollo = builder.buildApollo();
    final spartan = builder.buildSpartanV3();
    assertMatchesQualification(apollo);
    assertMatchesQualification(spartan);
    expect(apollo.unresolved.length, 131);
    expect(
      apollo.unresolved.every((item) => item.startsWith('name_only_block:')),
      isTrue,
    );
    expect(spartan.unresolved, isEmpty);
    expect(spartan.requireFullResolution, isTrue);
    expect(apollo.requireFullResolution, isFalse);
  });

  test('assignment counts do not change graph hashes or publication bytes', () {
    const builder = PublicationArtifactBuilder();
    final published = builder.buildApollo();
    final weekSql = {
      for (final file in Directory('supabase/migrations').listSync())
        if (file is File &&
            file.path.contains('apollo') &&
            file.path.endsWith('.sql') &&
            file.readAsStringSync().contains('EX-'))
          file.path: file.readAsStringSync(),
    };
    final bound = ApolloLocalGraphBinder().bind(
      planPackageYaml: File(apolloPlanPackagePath).readAsStringSync(),
      weekSqlByPath: weekSql,
    );
    bound.store.putAssignment(
      PinnedAssignment(
        id: 'assignment.operational-count-only',
        athleteId: 'athlete.operational-count-only',
        programmeVersionId: bound.manifest.programmeVersionId,
        active: true,
      ),
    );
    final after = bound.service.compileDraft(bound.manifest.programmeVersionId);
    expect(
      after.manifest.graphCanonicalSha256,
      published.publication['graph_structural_hash'],
    );
    expect(
      after.manifest.compositeContentIdentity,
      published.publication['composite_identity'],
    );
    expect(builder.buildApollo().publicationJson, published.publicationJson);
  });
}
