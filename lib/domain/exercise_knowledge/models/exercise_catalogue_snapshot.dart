import '../vocabulary/exercise_lifecycle_status.dart';
import 'comparison_protocol.dart';
import 'exercise_definition.dart';
import 'exercise_relationship.dart';

/// Immutable catalogue aggregate for validation, publication, and snapshots.
///
/// Deterministic ordering: definitions by id, relationships by id, protocols
/// by id. Not a production persistence authority.
class ExerciseCatalogueSnapshot {
  ExerciseCatalogueSnapshot({
    required this.catalogueVersion,
    required List<ExerciseDefinition> definitions,
    required List<ExerciseRelationship> relationships,
    required List<ComparisonProtocol> comparisonProtocols,
    this.label,
  })  : definitions = _sortDefinitions(definitions),
        relationships = _sortRelationships(relationships),
        comparisonProtocols = _sortProtocols(comparisonProtocols);

  final String catalogueVersion;
  final String? label;
  final List<ExerciseDefinition> definitions;
  final List<ExerciseRelationship> relationships;
  final List<ComparisonProtocol> comparisonProtocols;

  ExerciseCatalogueSnapshot copyWith({
    String? catalogueVersion,
    String? label,
    List<ExerciseDefinition>? definitions,
    List<ExerciseRelationship>? relationships,
    List<ComparisonProtocol>? comparisonProtocols,
  }) {
    return ExerciseCatalogueSnapshot(
      catalogueVersion: catalogueVersion ?? this.catalogueVersion,
      label: label ?? this.label,
      definitions: definitions ?? this.definitions,
      relationships: relationships ?? this.relationships,
      comparisonProtocols: comparisonProtocols ?? this.comparisonProtocols,
    );
  }

  /// Published-only operational view (draft and retired excluded).
  ExerciseCatalogueSnapshot operationalView() {
    return ExerciseCatalogueSnapshot(
      catalogueVersion: catalogueVersion,
      label: label,
      definitions: definitions
          .where((d) => d.lifecycleStatus.isRuntimeAuthoritative)
          .toList(growable: false),
      relationships: relationships
          .where((r) => r.lifecycleStatus.isRuntimeAuthoritative)
          .toList(growable: false),
      comparisonProtocols: comparisonProtocols,
    );
  }

  /// Historical view: published + retired definitions/relationships.
  ExerciseCatalogueSnapshot historicalView() {
    return ExerciseCatalogueSnapshot(
      catalogueVersion: catalogueVersion,
      label: label,
      definitions: definitions
          .where((d) => d.lifecycleStatus.remainsResolvable)
          .toList(growable: false),
      relationships: relationships
          .where((r) => r.lifecycleStatus.remainsResolvable)
          .toList(growable: false),
      comparisonProtocols: comparisonProtocols,
    );
  }

  Map<String, Object?> toJson() => {
        'catalogue_version': catalogueVersion,
        if (label != null) 'label': label,
        'definitions':
            definitions.map((d) => d.toJson()).toList(growable: false),
        'relationships':
            relationships.map((r) => r.toJson()).toList(growable: false),
        'comparison_protocols': comparisonProtocols
            .map((p) => p.toJson())
            .toList(growable: false),
      };

  factory ExerciseCatalogueSnapshot.fromJson(Map<String, Object?> json) {
    final defs = <ExerciseDefinition>[];
    final rawDefs = json['definitions'];
    if (rawDefs is List) {
      for (final item in rawDefs) {
        if (item is Map) {
          defs.add(
            ExerciseDefinition.fromJson(
              Map<String, Object?>.from(item.cast<String, Object?>()),
            ),
          );
        }
      }
    }
    final rels = <ExerciseRelationship>[];
    final rawRels = json['relationships'];
    if (rawRels is List) {
      for (final item in rawRels) {
        if (item is Map) {
          rels.add(
            ExerciseRelationship.fromJson(
              Map<String, Object?>.from(item.cast<String, Object?>()),
            ),
          );
        }
      }
    }
    final protocols = <ComparisonProtocol>[];
    final rawProtocols = json['comparison_protocols'];
    if (rawProtocols is List) {
      for (final item in rawProtocols) {
        if (item is Map) {
          protocols.add(
            ComparisonProtocol.fromJson(
              Map<String, Object?>.from(item.cast<String, Object?>()),
            ),
          );
        }
      }
    }
    return ExerciseCatalogueSnapshot(
      catalogueVersion: json['catalogue_version']?.toString() ?? '',
      label: json['label']?.toString(),
      definitions: defs,
      relationships: rels,
      comparisonProtocols: protocols,
    );
  }
}

List<ExerciseDefinition> _sortDefinitions(List<ExerciseDefinition> input) {
  final copy = List<ExerciseDefinition>.of(input);
  copy.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(copy);
}

List<ExerciseRelationship> _sortRelationships(List<ExerciseRelationship> input) {
  final copy = List<ExerciseRelationship>.of(input);
  copy.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(copy);
}

List<ComparisonProtocol> _sortProtocols(List<ComparisonProtocol> input) {
  final copy = List<ComparisonProtocol>.of(input);
  copy.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(copy);
}
