import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'content_graph_vocabulary.dart';

/// Content-graph manifest format v1 is a derived integrity/read-model.
///
/// Authoritative source remains authored programme/session/exercise content
/// and its canonical compiler inputs. Plan Package v1 and this manifest are
/// derived outputs. The manifest must not be authored independently.
class ContentGraphBinding {
  static const graphFormatVersion = 1;
  static const compilerVersion = 'content-graph-compiler/v1';
  static const planPackageSchemaV1 = 'plan-package/v1';
  static const supplementalSchemaV1 = 'canonical-relationship-source/v1';
  static const apolloSqlSupplementalSchema = 'apollo-sql-relationships/v1';

  static String sha256Hex(String canonicalJson) {
    return sha256.convert(utf8.encode(canonicalJson)).toString();
  }

  static String compositeDigest({
    required String sourcePackageHash,
    required String supplementalRelationshipHash,
    String compilerVersion = ContentGraphBinding.compilerVersion,
    int graphFormatVersion = ContentGraphBinding.graphFormatVersion,
  }) {
    final tree = {
      'compiler_version': compilerVersion,
      'graph_format_version': graphFormatVersion,
      'source_package_hash': sourcePackageHash,
      'supplemental_relationship_hash': supplementalRelationshipHash,
    };
    final keys = tree.keys.toList()..sort();
    final canonical = jsonEncode({for (final k in keys) k: tree[k]});
    return sha256Hex(canonical);
  }
}

class ContentGraphNode {
  const ContentGraphNode({
    required this.type,
    required this.id,
  });

  final ContentNodeType type;
  final String id;

  Map<String, Object?> toCanonical() => {
        'id': id,
        'type': type.name,
      };
}

class ContentGraphEdge {
  const ContentGraphEdge({
    required this.type,
    required this.fromType,
    required this.fromId,
    required this.toType,
    required this.toId,
  });

  final ContentRelationshipType type;
  final ContentNodeType fromType;
  final String fromId;
  final ContentNodeType toType;
  final String toId;

  Map<String, Object?> toCanonical() => {
        'from_id': fromId,
        'from_type': fromType.name,
        'to_id': toId,
        'to_type': toType.name,
        'type': type.name,
      };
}

class StructuralContentGraph {
  const StructuralContentGraph({
    required this.nodes,
    required this.edges,
  });

  final List<ContentGraphNode> nodes;
  final List<ContentGraphEdge> edges;
}

class SupplementalRelationshipSource {
  const SupplementalRelationshipSource({
    required this.schemaVersion,
    required this.canonicalJson,
    required this.sha256,
    required this.exerciseIds,
    this.unresolved = const [],
  });

  final String schemaVersion;
  final String canonicalJson;
  final String sha256;
  final Set<String> exerciseIds;
  final List<String> unresolved;

  factory SupplementalRelationshipSource.fromDeclaredExercises({
    String schemaVersion = ContentGraphBinding.supplementalSchemaV1,
    required Iterable<String> exerciseIds,
    List<String> unresolved = const [],
  }) {
    final ids = {...exerciseIds}.toList()..sort();
    final unresolvedSorted = [...unresolved]..sort();
    final tree = <String, Object?>{
      'exercise_ids': ids,
      'schema_version': schemaVersion,
      'unresolved': unresolvedSorted,
    };
    final keys = tree.keys.toList()..sort();
    final canonical = jsonEncode({for (final k in keys) k: tree[k]});
    return SupplementalRelationshipSource(
      schemaVersion: schemaVersion,
      canonicalJson: canonical,
      sha256: ContentGraphBinding.sha256Hex(canonical),
      exerciseIds: ids.toSet(),
      unresolved: unresolvedSorted,
    );
  }

  factory SupplementalRelationshipSource.fromUsedByEdges(
    Iterable<ContentGraphEdge> edges, {
    String schemaVersion = ContentGraphBinding.supplementalSchemaV1,
    List<String> unresolved = const [],
  }) {
    final usedBy = edges
        .where((e) => e.type == ContentRelationshipType.exerciseUsedByBlock)
        .map(
          (e) => {
            'exercise_id': e.fromId,
            'block_id': e.toId,
          },
        )
        .toList();
    usedBy.sort((a, b) {
      final exercise = (a['exercise_id']!).compareTo(b['exercise_id']!);
      if (exercise != 0) return exercise;
      return (a['block_id']!).compareTo(b['block_id']!);
    });
    final ids = {
      for (final row in usedBy) row['exercise_id']!,
    }.toList()
      ..sort();
    final unresolvedSorted = [...unresolved]..sort();
    final tree = <String, Object?>{
      'edges': usedBy,
      'exercise_ids': ids,
      'schema_version': schemaVersion,
      'unresolved': unresolvedSorted,
    };
    final keys = tree.keys.toList()..sort();
    final canonical = jsonEncode({for (final k in keys) k: tree[k]});
    return SupplementalRelationshipSource(
      schemaVersion: schemaVersion,
      canonicalJson: canonical,
      sha256: ContentGraphBinding.sha256Hex(canonical),
      exerciseIds: ids.toSet(),
      unresolved: unresolvedSorted,
    );
  }
}

class ContentGraphManifest {
  const ContentGraphManifest({
    required this.graphFormatVersion,
    required this.compilerVersion,
    required this.programmeId,
    required this.programmeVersionId,
    required this.sourcePackageSchemaVersion,
    required this.sourceCanonicalContentSha256,
    required this.graphCanonicalSha256,
    required this.supplementalRelationshipSha256,
    required this.compositeContentIdentity,
    required this.nodeCount,
    required this.edgeCount,
    required this.canonicalJson,
    this.unresolved = const [],
    this.provenance = const {
      'generator': ContentGraphBinding.compilerVersion,
      'excluded_from_structural_hash': true,
    },
  });

  final int graphFormatVersion;
  final String compilerVersion;
  final String programmeId;
  final String programmeVersionId;
  final String sourcePackageSchemaVersion;
  final String sourceCanonicalContentSha256;
  final String graphCanonicalSha256;
  final String supplementalRelationshipSha256;
  final String compositeContentIdentity;
  final int nodeCount;
  final int edgeCount;
  final String canonicalJson;
  final List<String> unresolved;
  final Map<String, Object?> provenance;

  ContentGraphManifest copyWith({
    String? sourceCanonicalContentSha256,
    String? graphCanonicalSha256,
    String? supplementalRelationshipSha256,
    String? compositeContentIdentity,
    String? compilerVersion,
    int? graphFormatVersion,
  }) {
    return ContentGraphManifest(
      graphFormatVersion: graphFormatVersion ?? this.graphFormatVersion,
      compilerVersion: compilerVersion ?? this.compilerVersion,
      programmeId: programmeId,
      programmeVersionId: programmeVersionId,
      sourcePackageSchemaVersion: sourcePackageSchemaVersion,
      sourceCanonicalContentSha256:
          sourceCanonicalContentSha256 ?? this.sourceCanonicalContentSha256,
      graphCanonicalSha256: graphCanonicalSha256 ?? this.graphCanonicalSha256,
      supplementalRelationshipSha256: supplementalRelationshipSha256 ??
          this.supplementalRelationshipSha256,
      compositeContentIdentity:
          compositeContentIdentity ?? this.compositeContentIdentity,
      nodeCount: nodeCount,
      edgeCount: edgeCount,
      canonicalJson: canonicalJson,
      unresolved: unresolved,
      provenance: provenance,
    );
  }
}
