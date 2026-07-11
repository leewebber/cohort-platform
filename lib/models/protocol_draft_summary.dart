/// Lightweight row for unpublished protocol drafts in Coach Studio.
class ProtocolDraftSummary {
  const ProtocolDraftSummary({
    required this.protocolId,
    required this.name,
    this.sessionType,
    this.durationMin,
  });

  final String protocolId;
  final String name;
  final String? sessionType;
  final int? durationMin;

  factory ProtocolDraftSummary.fromMap(Map<String, dynamic> map) {
    return ProtocolDraftSummary(
      protocolId: map['protocol_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      sessionType: map['session_type']?.toString(),
      durationMin: _nullableInt(map['duration_min']),
    );
  }

  static int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
