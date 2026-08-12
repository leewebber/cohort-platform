import '../vocabulary/exercise_lifecycle_status.dart';
import 'coaching_content.dart';
import 'comparison_protocol.dart';
import 'exercise_definition.dart';
import 'exercise_relationship.dart';
import 'knowledge_content_common.dart';
import 'movement_standard.dart';
import 'video_reference.dart';

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
    List<MovementStandard> movementStandards = const [],
    List<CoachingContent> coachingContents = const [],
    List<VideoReference> videoReferences = const [],
    this.label,
  }) : definitions = _sortDefinitions(definitions),
       relationships = _sortRelationships(relationships),
       comparisonProtocols = _sortProtocols(comparisonProtocols),
       movementStandards = _sortContent(movementStandards),
       coachingContents = _sortContent(coachingContents),
       videoReferences = _sortContent(videoReferences);

  final String catalogueVersion;
  final String? label;
  final List<ExerciseDefinition> definitions;
  final List<ExerciseRelationship> relationships;
  final List<ComparisonProtocol> comparisonProtocols;
  final List<MovementStandard> movementStandards;
  final List<CoachingContent> coachingContents;
  final List<VideoReference> videoReferences;

  ExerciseCatalogueSnapshot copyWith({
    String? catalogueVersion,
    String? label,
    List<ExerciseDefinition>? definitions,
    List<ExerciseRelationship>? relationships,
    List<ComparisonProtocol>? comparisonProtocols,
    List<MovementStandard>? movementStandards,
    List<CoachingContent>? coachingContents,
    List<VideoReference>? videoReferences,
  }) {
    return ExerciseCatalogueSnapshot(
      catalogueVersion: catalogueVersion ?? this.catalogueVersion,
      label: label ?? this.label,
      definitions: definitions ?? this.definitions,
      relationships: relationships ?? this.relationships,
      comparisonProtocols: comparisonProtocols ?? this.comparisonProtocols,
      movementStandards: movementStandards ?? this.movementStandards,
      coachingContents: coachingContents ?? this.coachingContents,
      videoReferences: videoReferences ?? this.videoReferences,
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
      movementStandards: movementStandards
          .where((item) => item.lifecycleStatus.isRuntimeAuthoritative)
          .toList(growable: false),
      coachingContents: coachingContents
          .where((item) => item.lifecycleStatus.isRuntimeAuthoritative)
          .toList(growable: false),
      videoReferences: videoReferences
          .where((item) => item.lifecycleStatus.isRuntimeAuthoritative)
          .toList(growable: false),
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
      movementStandards: movementStandards
          .where((item) => item.lifecycleStatus.remainsResolvable)
          .toList(growable: false),
      coachingContents: coachingContents
          .where((item) => item.lifecycleStatus.remainsResolvable)
          .toList(growable: false),
      videoReferences: videoReferences
          .where((item) => item.lifecycleStatus.remainsResolvable)
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => {
    'catalogue_version': catalogueVersion,
    if (label != null) 'label': label,
    'definitions': definitions.map((d) => d.toJson()).toList(growable: false),
    'relationships': relationships
        .map((r) => r.toJson())
        .toList(growable: false),
    'comparison_protocols': comparisonProtocols
        .map((p) => p.toJson())
        .toList(growable: false),
    'movement_standards': movementStandards
        .map((item) => item.toJson())
        .toList(growable: false),
    'coaching_contents': coachingContents
        .map((item) => item.toJson())
        .toList(growable: false),
    'video_references': videoReferences
        .map((item) => item.toJson())
        .toList(growable: false),
  };

  factory ExerciseCatalogueSnapshot.fromJson(Map<String, Object?> json) {
    KnowledgeContentCodec.requireExactKeys(json, const {
      'catalogue_version',
      'label',
      'definitions',
      'relationships',
      'comparison_protocols',
      'movement_standards',
      'coaching_contents',
      'video_references',
    }, 'catalogue');
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
    final movementStandards = <MovementStandard>[];
    for (final item in _mapList(
      json['movement_standards'],
      'movement_standards',
    )) {
      movementStandards.add(MovementStandard.fromJson(item));
    }
    final coachingContents = <CoachingContent>[];
    for (final item in _mapList(
      json['coaching_contents'],
      'coaching_contents',
    )) {
      coachingContents.add(CoachingContent.fromJson(item));
    }
    final videoReferences = <VideoReference>[];
    for (final item in _mapList(json['video_references'], 'video_references')) {
      videoReferences.add(VideoReference.fromJson(item));
    }
    return ExerciseCatalogueSnapshot(
      catalogueVersion: json['catalogue_version']?.toString() ?? '',
      label: json['label']?.toString(),
      definitions: defs,
      relationships: rels,
      comparisonProtocols: protocols,
      movementStandards: movementStandards,
      coachingContents: coachingContents,
      videoReferences: videoReferences,
    );
  }
}

List<ExerciseDefinition> _sortDefinitions(List<ExerciseDefinition> input) {
  final copy = List<ExerciseDefinition>.of(input);
  copy.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(copy);
}

List<ExerciseRelationship> _sortRelationships(
  List<ExerciseRelationship> input,
) {
  final copy = List<ExerciseRelationship>.of(input);
  copy.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(copy);
}

List<ComparisonProtocol> _sortProtocols(List<ComparisonProtocol> input) {
  final copy = List<ComparisonProtocol>.of(input);
  copy.sort((a, b) => a.id.compareTo(b.id));
  return List.unmodifiable(copy);
}

List<T> _sortContent<T extends ExerciseKnowledgeContentRecord>(List<T> input) {
  final copy = List<T>.of(input);
  copy.sort((a, b) {
    final byId = a.id.value.compareTo(b.id.value);
    if (byId != 0) return byId;
    return a.version.compareTo(b.version);
  });
  return List.unmodifiable(copy);
}

List<Map<String, Object?>> _mapList(Object? raw, String path) {
  if (raw == null) return const [];
  if (raw is! List) throw FormatException('$path must be a list.');
  final result = <Map<String, Object?>>[];
  for (var i = 0; i < raw.length; i++) {
    final item = raw[i];
    if (item is! Map) throw FormatException('$path[$i] must be a map.');
    result.add(Map<String, Object?>.from(item.cast<String, Object?>()));
  }
  return result;
}
