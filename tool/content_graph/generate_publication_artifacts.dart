import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/domain/content_graph/content_graph_manifest.dart';

import 'publication_artifact_builder.dart';

void main() {
  final written = writePublicationArtifacts();
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(written));
}

Map<String, Object?> writePublicationArtifacts({String root = artifactRoot}) {
  const builder = PublicationArtifactBuilder();
  final candidates = builder.buildApprovedSet();
  for (final candidate in candidates) {
    assertMatchesQualification(candidate);
    if (containsForbiddenOperationalField(candidate.publication)) {
      throw StateError('${candidate.label} contains a noncanonical field.');
    }
  }

  Directory('$root/cohort_global/apollo').createSync(recursive: true);
  Directory('$root/cohort_global/spartan').createSync(recursive: true);

  final indexCandidates = <Map<String, Object?>>[];
  final checksumLines = <String>[];
  for (final candidate in candidates) {
    final dir = candidate.label == 'apollo'
        ? '$root/cohort_global/apollo'
        : '$root/cohort_global/spartan';
    final manifestRel =
        '${dir.replaceFirst('$root/', '')}/${candidate.programmeVersionId}.manifest.json';
    final publicationRel =
        '${dir.replaceFirst('$root/', '')}/${candidate.programmeVersionId}.publication.json';
    final manifestPath = '$dir/${candidate.programmeVersionId}.manifest.json';
    final publicationPath =
        '$dir/${candidate.programmeVersionId}.publication.json';
    File(manifestPath).writeAsStringSync(candidate.manifestJson);
    File(publicationPath).writeAsStringSync(candidate.publicationJson);
    final manifestSha = sha256Bytes(candidate.manifestJson);
    final publicationSha = sha256Bytes(candidate.publicationJson);
    checksumLines.add('$manifestSha  $manifestRel');
    checksumLines.add('$publicationSha  $publicationRel');
    indexCandidates.add({
      'classification': candidate.classification,
      'composite_identity': candidate.publication['composite_identity'],
      'edge_count': candidate.edgeCount,
      'eligibility': candidate.label == 'apollo'
          ? 'publishable_with_explicit_unresolved'
          : 'fully_eligible',
      'graph_structural_hash': candidate.publication['graph_structural_hash'],
      'label': candidate.label,
      'manifest_path': manifestRel,
      'manifest_sha256': manifestSha,
      'node_count': candidate.nodeCount,
      'programme_version_id': candidate.programmeVersionId,
      'publication_path': publicationRel,
      'publication_sha256': publicationSha,
      'require_full_resolution': candidate.requireFullResolution,
      'source_package_hash': candidate.publication['source_package_hash'],
      'supplemental_relationship_hash':
          candidate.publication['supplemental_relationship_hash'],
      'unresolved_count': candidate.unresolved.length,
    });
  }

  final sourceRel = 'sources/spartan_physique_v3.relationships.json';
  final sourceBytes = File('$artifactRoot/$sourceRel').readAsStringSync();
  if (root != artifactRoot) {
    File('$root/$sourceRel')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(sourceBytes);
  }
  checksumLines.add('${sha256Bytes(sourceBytes)}  $sourceRel');
  checksumLines.sort();
  File('$root/checksums.sha256').writeAsStringSync(
    '${checksumLines.join('\n')}\n',
  );

  final index = {
    'compiler_version': ContentGraphBinding.compilerVersion,
    'graph_format_version': ContentGraphBinding.graphFormatVersion,
    'publisher_id': contentGraphPublisherId,
    'schema': 'content-graph-publication-index/v1',
    'candidates': indexCandidates,
  };
  File('$root/index.json').writeAsStringSync(encodeCanonical(index));
  return index;
}
