import '../models/alias_resolution.dart';
import '../models/comparison_protocol.dart';
import '../models/exercise_catalogue_snapshot.dart';
import '../models/exercise_definition.dart';
import '../models/exercise_definition_lookup.dart';
import '../models/exercise_relationship.dart';
import '../ports/exercise_knowledge_repository.dart';
import '../value_objects/exercise_id.dart';

/// Deterministic in-memory repository for tests and local verification.
///
/// Not a production persistence authority. No Supabase / hosted access.
class InMemoryExerciseKnowledgeRepository
    implements ExerciseKnowledgeRepository {
  InMemoryExerciseKnowledgeRepository({
    ExerciseCatalogueSnapshot? initial,
    this.defaultCatalogueVersion = '0',
  }) {
    if (initial != null) {
      replaceCatalogue(initial);
    }
  }

  final String defaultCatalogueVersion;

  final Map<String, ExerciseDefinition> _definitions = {};
  final Map<String, ExerciseRelationship> _relationships = {};
  final Map<String, ComparisonProtocol> _protocols = {};
  String _catalogueVersion = '0';

  @override
  void replaceCatalogue(ExerciseCatalogueSnapshot snapshot) {
    _definitions.clear();
    _relationships.clear();
    _protocols.clear();
    _catalogueVersion = snapshot.catalogueVersion;
    for (final def in snapshot.definitions) {
      _definitions[def.id.value] = def;
    }
    for (final rel in snapshot.relationships) {
      _relationships[rel.id] = rel;
    }
    for (final protocol in snapshot.comparisonProtocols) {
      _protocols[protocol.id] = protocol;
    }
  }

  @override
  void upsertDefinition(ExerciseDefinition definition) {
    _definitions[definition.id.value] = definition;
  }

  @override
  void upsertRelationship(ExerciseRelationship relationship) {
    _relationships[relationship.id] = relationship;
  }

  @override
  void upsertComparisonProtocol(ComparisonProtocol protocol) {
    _protocols[protocol.id] = protocol;
  }

  @override
  ExerciseDefinitionLookup getDefinition(
    ExerciseId id, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.historical,
  }) {
    final def = _definitions[id.value];
    if (def == null) return ExerciseDefinitionLookup.missing(id);
    if (!visibility.includes(def.lifecycleStatus)) {
      return ExerciseDefinitionLookup.missing(id);
    }
    return ExerciseDefinitionLookup.found(def);
  }

  @override
  List<ExerciseDefinitionLookup> getDefinitions(
    Iterable<ExerciseId> ids, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.historical,
  }) {
    final unique = ids.toSet().toList()..sort();
    return [
      for (final id in unique) getDefinition(id, visibility: visibility),
    ];
  }

  @override
  List<ExerciseDefinition> listDefinitions({
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
  }) {
    final out = _definitions.values
        .where((d) => visibility.includes(d.lifecycleStatus))
        .toList(growable: true);
    out.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(out);
  }

  @override
  AliasResolutionResult resolveAlias(String alias) {
    final needle = alias.trim().toLowerCase();
    if (needle.isEmpty) return const AliasNotFound();

    // Transitional knowledge ids are not resolved here (deferred bridge).
    if (ExerciseId.isTransitionalKnowledgeId(alias)) {
      return const AliasNotFound();
    }

    final matches = <ExerciseId>[];
    for (final def in _definitions.values) {
      final names = <String>[
        def.canonicalName,
        ...def.aliases,
      ];
      for (final name in names) {
        if (name.trim().toLowerCase() == needle) {
          matches.add(def.id);
          break;
        }
      }
    }
    matches.sort();
    if (matches.isEmpty) return const AliasNotFound();
    if (matches.length == 1) return AliasResolved(matches.first);
    return AliasAmbiguous(List.unmodifiable(matches));
  }

  @override
  List<ExerciseRelationship> outgoingRelationships(
    ExerciseId id, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
  }) {
    final out = _relationships.values
        .where(
          (r) =>
              r.sourceExerciseId == id &&
              visibility.includes(r.lifecycleStatus),
        )
        .toList(growable: true);
    out.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(out);
  }

  @override
  List<ExerciseRelationship> incomingRelationships(
    ExerciseId id, {
    ExerciseKnowledgeVisibility visibility =
        ExerciseKnowledgeVisibility.operational,
  }) {
    final out = _relationships.values
        .where(
          (r) =>
              r.targetExerciseId == id &&
              visibility.includes(r.lifecycleStatus),
        )
        .toList(growable: true);
    out.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(out);
  }

  @override
  ComparisonProtocol? getComparisonProtocol(
    String protocolId, {
    String? version,
  }) {
    final protocol = _protocols[protocolId];
    if (protocol == null) return null;
    if (version != null && protocol.version != version) return null;
    return protocol;
  }

  @override
  ExerciseCatalogueSnapshot authoringSnapshot({String? catalogueVersion}) {
    return ExerciseCatalogueSnapshot(
      catalogueVersion: catalogueVersion ?? _catalogueVersion,
      definitions: _definitions.values.toList(growable: false),
      relationships: _relationships.values.toList(growable: false),
      comparisonProtocols: _protocols.values.toList(growable: false),
    );
  }

  @override
  ExerciseCatalogueSnapshot operationalSnapshot({String? catalogueVersion}) {
    return authoringSnapshot(catalogueVersion: catalogueVersion)
        .operationalView();
  }
}
