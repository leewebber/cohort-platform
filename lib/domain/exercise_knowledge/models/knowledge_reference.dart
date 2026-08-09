/// Stable reference id for coaching, media, movement, or sport standards.
class KnowledgeReferenceId {
  KnowledgeReferenceId._(this.value);

  static final RegExp _pattern = RegExp(r'^[a-z][a-z0-9_.-]{1,127}$');

  final String value;

  factory KnowledgeReferenceId.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Reference id must not be blank.');
    }
    if (!_pattern.hasMatch(trimmed)) {
      throw FormatException('Malformed knowledge reference id: $trimmed');
    }
    return KnowledgeReferenceId._(trimmed);
  }

  static KnowledgeReferenceId? tryParse(String? raw) {
    if (raw == null) return null;
    try {
      return KnowledgeReferenceId.parse(raw);
    } on FormatException {
      return null;
    }
  }

  String toJson() => value;

  @override
  bool operator ==(Object other) =>
      other is KnowledgeReferenceId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Optional reference to reusable coaching content.
class CoachingContentRef {
  const CoachingContentRef({required this.id, this.label});

  final KnowledgeReferenceId id;
  final String? label;

  Map<String, Object?> toJson() => {
        'id': id.value,
        if (label != null) 'label': label,
      };

  factory CoachingContentRef.fromJson(Map<String, Object?> json) {
    return CoachingContentRef(
      id: KnowledgeReferenceId.parse(json['id']?.toString() ?? ''),
      label: json['label']?.toString(),
    );
  }
}

/// Optional media reference (asset need not exist yet).
class MediaReference {
  const MediaReference({
    required this.id,
    this.kind = MediaReferenceKind.unspecified,
    this.uriHint,
  });

  final KnowledgeReferenceId id;
  final MediaReferenceKind kind;

  /// Non-authoritative hint only; population deferred.
  final String? uriHint;

  Map<String, Object?> toJson() => {
        'id': id.value,
        'kind': kind.wireValue,
        if (uriHint != null) 'uri_hint': uriHint,
      };

  factory MediaReference.fromJson(Map<String, Object?> json) {
    return MediaReference(
      id: KnowledgeReferenceId.parse(json['id']?.toString() ?? ''),
      kind: MediaReferenceKindCodec.tryParse(json['kind']?.toString()) ??
          MediaReferenceKind.unspecified,
      uriHint: json['uri_hint']?.toString(),
    );
  }
}

enum MediaReferenceKind { video, image, unspecified }

extension MediaReferenceKindCodec on MediaReferenceKind {
  String get wireValue {
    return switch (this) {
      MediaReferenceKind.video => 'video',
      MediaReferenceKind.image => 'image',
      MediaReferenceKind.unspecified => 'unspecified',
    };
  }

  static MediaReferenceKind? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final normalized = raw.trim().toLowerCase();
    for (final value in MediaReferenceKind.values) {
      if (value.wireValue == normalized) return value;
    }
    return null;
  }
}

/// Optional movement standard reference.
class MovementStandardRef {
  const MovementStandardRef({required this.id, this.label});

  final KnowledgeReferenceId id;
  final String? label;

  Map<String, Object?> toJson() => {
        'id': id.value,
        if (label != null) 'label': label,
      };

  factory MovementStandardRef.fromJson(Map<String, Object?> json) {
    return MovementStandardRef(
      id: KnowledgeReferenceId.parse(json['id']?.toString() ?? ''),
      label: json['label']?.toString(),
    );
  }
}

/// Sport-specific standard (e.g. HYROX wall-ball standard).
///
/// HYROX station identity is a sport classification/standard attached to the
/// canonical exercise — not a second exercise identity.
class SportStandardRef {
  const SportStandardRef({
    required this.id,
    this.sportCode,
    this.label,
  });

  final KnowledgeReferenceId id;
  final String? sportCode;
  final String? label;

  Map<String, Object?> toJson() => {
        'id': id.value,
        if (sportCode != null) 'sport_code': sportCode,
        if (label != null) 'label': label,
      };

  factory SportStandardRef.fromJson(Map<String, Object?> json) {
    return SportStandardRef(
      id: KnowledgeReferenceId.parse(json['id']?.toString() ?? ''),
      sportCode: json['sport_code']?.toString(),
      label: json['label']?.toString(),
    );
  }
}
