import '../utils/database_uuid.dart';

/// Generates durable opaque identifiers for coach-authored training content.
abstract interface class TrainingContentIdGenerator {
  String newSessionId();
}

/// Uses a full RFC-4122 UUID stored in `performance_protocols.protocol_id`.
class UuidTrainingContentIdGenerator implements TrainingContentIdGenerator {
  const UuidTrainingContentIdGenerator();

  @override
  String newSessionId() => DatabaseUuid.newV4();
}
