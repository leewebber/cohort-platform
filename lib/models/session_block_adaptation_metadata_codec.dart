import '../domain/adaptation/adaptation_domain.dart';

/// Persistence keys for block adaptation metadata on `session_blocks`.
abstract final class SessionBlockAdaptationMetadataKeys {
  static const blockPriority = 'block_priority';
  static const adaptationPolicy = 'adaptation_policy';
}

/// Parses and serialises explicit block adaptation metadata only (not derived defaults).
class SessionBlockAdaptationMetadataCodec {
  const SessionBlockAdaptationMetadataCodec._();

  static BlockPriority? parseBlockPriority(dynamic value) {
    if (value == null) return null;
    return BlockPriorityDb.fromDb(value.toString());
  }

  static BlockAdaptationPolicy? parseAdaptationPolicy(dynamic value) {
    if (value == null) return null;
    try {
      if (value is Map<String, dynamic>) {
        return BlockAdaptationPolicy.fromJson(value);
      }
      if (value is Map) {
        return BlockAdaptationPolicy.fromJson(Map<String, dynamic>.from(value));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Writes only explicitly authored values — never type-derived defaults.
  static void writeExplicitToMap({
    required Map<String, dynamic> target,
    BlockPriority? blockPriority,
    BlockAdaptationPolicy? adaptationPolicy,
  }) {
    if (blockPriority != null) {
      target[SessionBlockAdaptationMetadataKeys.blockPriority] =
          blockPriority.dbValue;
    }
    if (adaptationPolicy != null) {
      target[SessionBlockAdaptationMetadataKeys.adaptationPolicy] =
          adaptationPolicy.toJson();
    }
  }

  static void stripPendingPersistenceColumns(Map<String, dynamic> map) {
    map.remove(SessionBlockAdaptationMetadataKeys.blockPriority);
    map.remove(SessionBlockAdaptationMetadataKeys.adaptationPolicy);
  }
}
