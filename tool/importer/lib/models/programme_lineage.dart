/// Stable human-readable programme identity across versions.
///
/// Maps to `programme_lineages`. See `42_Programme_Engine_Schema.md`.
class ProgrammeLineage {
  const ProgrammeLineage({
    required this.id,
    required this.code,
    this.importKey,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// UUID primary key.
  final String id;

  /// Human code — e.g. `PROG-HYROX-12`. Stored on assignments and training_sessions.
  final String code;

  /// Stable founder YAML import identifier when created via importer.
  final String? importKey;

  final String? createdBy;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ProgrammeLineage.fromMap(Map<String, dynamic> map) {
    return ProgrammeLineage(
      id: _trimStringRequired(map['id']),
      code: _trimStringRequired(map['code']),
      importKey: _trimString(map['import_key']),
      createdBy: _trimString(map['created_by']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'code': code,
      if (importKey != null) 'import_key': importKey,
      if (createdBy != null) 'created_by': createdBy,
    };
  }

  ProgrammeLineage copyWith({
    String? id,
    String? code,
    String? importKey,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProgrammeLineage(
      id: id ?? this.id,
      code: code ?? this.code,
      importKey: importKey ?? this.importKey,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String? _trimString(dynamic value) {
    if (value == null) return null;

    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _trimStringRequired(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    return DateTime.tryParse(value.toString());
  }
}
