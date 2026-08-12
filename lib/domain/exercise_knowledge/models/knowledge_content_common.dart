import '../value_objects/exercise_id.dart';
import '../vocabulary/exercise_lifecycle_status.dart';
import 'knowledge_reference.dart';

/// Current repository-owned schema for movement-content records.
const exerciseKnowledgeContentSchemaVersion = 1;

/// Generic identity for a human or governed authoring actor.
///
/// Publication authority is evaluated separately by the publication service.
class KnowledgeActorId {
  KnowledgeActorId._(this.value);

  static final RegExp _pattern = RegExp(r'^[a-z][a-z0-9_.:-]{1,127}$');

  final String value;

  factory KnowledgeActorId.parse(String raw) {
    final value = raw.trim();
    if (!_pattern.hasMatch(value)) {
      throw FormatException('Malformed knowledge actor id: $value');
    }
    return KnowledgeActorId._(value);
  }

  Map<String, Object?> toJson() => {'id': value};

  factory KnowledgeActorId.fromJson(Map<String, Object?> json) {
    KnowledgeContentCodec.requireExactKeys(json, const {'id'}, 'actor');
    return KnowledgeActorId.parse(json['id']?.toString() ?? '');
  }

  @override
  bool operator ==(Object other) =>
      other is KnowledgeActorId && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Explicit source and provenance for authored movement knowledge.
class KnowledgeProvenance {
  const KnowledgeProvenance({
    required this.sourceType,
    required this.sourceReference,
    this.notes,
  });

  final String sourceType;
  final String sourceReference;
  final String? notes;

  Map<String, Object?> toJson() => {
    'source_type': sourceType,
    'source_reference': sourceReference,
    if (notes != null) 'notes': notes,
  };

  factory KnowledgeProvenance.fromJson(Map<String, Object?> json) {
    KnowledgeContentCodec.requireExactKeys(json, const {
      'source_type',
      'source_reference',
      'notes',
    }, 'provenance');
    return KnowledgeProvenance(
      sourceType: json['source_type']?.toString() ?? '',
      sourceReference: json['source_reference']?.toString() ?? '',
      notes: json['notes']?.toString(),
    );
  }
}

enum ExerciseKnowledgeContentKind {
  movementStandard,
  coachingContent,
  videoReference,
}

extension ExerciseKnowledgeContentKindCodec on ExerciseKnowledgeContentKind {
  String get wireValue => switch (this) {
    ExerciseKnowledgeContentKind.movementStandard => 'movement_standard',
    ExerciseKnowledgeContentKind.coachingContent => 'coaching_content',
    ExerciseKnowledgeContentKind.videoReference => 'video_reference',
  };
}

/// Shared read surface for versioned movement-content records.
abstract interface class ExerciseKnowledgeContentRecord {
  KnowledgeReferenceId get id;
  ExerciseId get exerciseId;
  String get version;
  ExerciseLifecycleStatus get lifecycleStatus;
  KnowledgeActorId get authorId;
  KnowledgeActorId? get reviewerId;
  KnowledgeProvenance get provenance;
  DateTime get authoredAt;
  DateTime? get reviewedAt;
  DateTime? get publishedAt;
  KnowledgeReferenceId? get replacementId;
  ExerciseKnowledgeContentKind get contentKind;
  Map<String, Object?> toJson();
}

/// Strict parsing helpers for repository-owned movement-content schemas.
class KnowledgeContentCodec {
  KnowledgeContentCodec._();

  static void requireExactKeys(
    Map<String, Object?> json,
    Set<String> allowed,
    String path,
  ) {
    final unsupported =
        json.keys.where((key) => !allowed.contains(key)).toList()..sort();
    if (unsupported.isNotEmpty) {
      throw FormatException(
        '$path contains unsupported fields: ${unsupported.join(', ')}',
      );
    }
  }

  static void requireSchemaVersion(Map<String, Object?> json, String path) {
    final raw = json['schema_version'];
    final parsed = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (parsed != exerciseKnowledgeContentSchemaVersion) {
      throw FormatException(
        '$path has unsupported schema_version: ${raw ?? 'missing'}',
      );
    }
  }

  static DateTime requireDate(Object? raw, String path) {
    final parsed = DateTime.tryParse(raw?.toString() ?? '')?.toUtc();
    if (parsed == null) {
      throw FormatException('$path must be an ISO-8601 date.');
    }
    return parsed;
  }

  static DateTime? optionalDate(Object? raw, String path) {
    if (raw == null) return null;
    return requireDate(raw, path);
  }

  static List<String> strings(Object? raw, String path) {
    if (raw == null) return const [];
    if (raw is! List) throw FormatException('$path must be a list.');
    return List.unmodifiable(raw.map((value) => value.toString()));
  }

  static List<Map<String, Object?>> maps(Object? raw, String path) {
    if (raw == null) return const [];
    if (raw is! List) throw FormatException('$path must be a list.');
    final result = <Map<String, Object?>>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      if (item is! Map) throw FormatException('$path[$i] must be a map.');
      result.add(Map<String, Object?>.from(item.cast<String, Object?>()));
    }
    return List.unmodifiable(result);
  }

  static Map<String, Object?> map(Object? raw, String path) {
    if (raw is! Map) throw FormatException('$path must be a map.');
    return Map<String, Object?>.from(raw.cast<String, Object?>());
  }

  static List<KnowledgeReferenceId> referenceIds(Object? raw, String path) =>
      strings(
        raw,
        path,
      ).map(KnowledgeReferenceId.parse).toList(growable: false);

  static Map<String, Object?> commonJson({
    required KnowledgeReferenceId id,
    required ExerciseId exerciseId,
    required String version,
    required ExerciseLifecycleStatus lifecycleStatus,
    required KnowledgeActorId authorId,
    required KnowledgeProvenance provenance,
    required DateTime authoredAt,
    KnowledgeActorId? reviewerId,
    DateTime? reviewedAt,
    DateTime? publishedAt,
    KnowledgeReferenceId? replacementId,
  }) => {
    'schema_version': exerciseKnowledgeContentSchemaVersion,
    'id': id.value,
    'exercise_id': exerciseId.value,
    'version': version,
    'lifecycle_status': lifecycleStatus.wireValue,
    'author': authorId.toJson(),
    if (reviewerId != null) 'reviewer': reviewerId.toJson(),
    'provenance': provenance.toJson(),
    'authored_at': authoredAt.toUtc().toIso8601String(),
    if (reviewedAt != null) 'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    if (publishedAt != null)
      'published_at': publishedAt.toUtc().toIso8601String(),
    if (replacementId != null) 'replacement_id': replacementId.value,
  };

  static KnowledgeActorId actor(Object? raw, String path) =>
      KnowledgeActorId.fromJson(map(raw, path));

  static KnowledgeActorId? optionalActor(Object? raw, String path) =>
      raw == null ? null : actor(raw, path);

  static KnowledgeProvenance provenance(Object? raw, String path) =>
      KnowledgeProvenance.fromJson(map(raw, path));

  static ExerciseLifecycleStatus lifecycle(Object? raw, String path) {
    final parsed = ExerciseLifecycleStatusCodec.tryParse(raw?.toString());
    if (parsed == null) throw FormatException('$path is unsupported.');
    return parsed;
  }
}
