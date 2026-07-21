/// Stable identity grouping immutable Session Revisions.
///
/// Maps to `session_lineages`. Each revision is a `performance_protocols` row
/// identified by `protocol_id`.
class SessionLineage {
  const SessionLineage({
    required this.id,
    required this.displayName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String displayName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SessionLineage.fromMap(Map<String, dynamic> map) {
    return SessionLineage(
      id: _trimRequired(map['id']),
      displayName: _trimRequired(map['display_name']),
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'display_name': displayName,
    };
  }

  SessionLineage copyWith({
    String? id,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SessionLineage(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _trimRequired(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
