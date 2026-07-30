import 'dart:convert';

/// Versioned wrapper for every locally stored aggregate.
class PersistenceEnvelope {
  const PersistenceEnvelope({
    required this.schemaVersion,
    required this.savedAt,
    required this.payload,
  });

  final int schemaVersion;
  final DateTime savedAt;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'payload': payload,
  };

  String encode() => jsonEncode(toJson());

  /// Parses [raw]. Throws [PersistenceSchemaException] on unknown version.
  static PersistenceEnvelope decode(
    String raw, {
    required int expectedVersion,
    required String aggregate,
  }) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw PersistenceSchemaException(
        aggregate: aggregate,
        message: 'Envelope is not a JSON object.',
      );
    }
    final map = Map<String, dynamic>.from(decoded);
    final version = map['schemaVersion'];
    if (version is! int) {
      throw PersistenceSchemaException(
        aggregate: aggregate,
        message: 'Missing schemaVersion.',
      );
    }
    if (version != expectedVersion) {
      throw PersistenceSchemaException(
        aggregate: aggregate,
        message: 'Unsupported schemaVersion $version '
            '(expected $expectedVersion).',
        schemaVersion: version,
      );
    }
    final savedAtRaw = map['savedAt']?.toString();
    final savedAt = savedAtRaw == null
        ? DateTime.now().toUtc()
        : DateTime.tryParse(savedAtRaw)?.toUtc() ?? DateTime.now().toUtc();
    final payloadRaw = map['payload'];
    if (payloadRaw is! Map) {
      throw PersistenceSchemaException(
        aggregate: aggregate,
        message: 'Missing payload object.',
      );
    }
    return PersistenceEnvelope(
      schemaVersion: version,
      savedAt: savedAt,
      payload: Map<String, dynamic>.from(payloadRaw),
    );
  }
}

class PersistenceSchemaException implements Exception {
  PersistenceSchemaException({
    required this.aggregate,
    required this.message,
    this.schemaVersion,
  });

  final String aggregate;
  final String message;
  final int? schemaVersion;

  @override
  String toString() =>
      'PersistenceSchemaException($aggregate): $message';
}

/// Current schema versions (v1 only — migration boundary reserved).
abstract final class PersistenceSchemaVersions {
  static const athleteProfile = 1;
  static const planAssignment = 1;
  static const generatedSession = 1;
  static const sessionCompletions = 1;
  static const capabilityTimeline = 1;
  static const previousPerformance = 1;
  static const workoutProgress = 1;
  static const exerciseResults = 1;
}
