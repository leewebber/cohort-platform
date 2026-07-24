/// Helpers for distinguishing client local ids from Supabase UUID primary keys.
library;

import 'dart:math';

class DatabaseUuid {
  DatabaseUuid._();

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Returns true when [value] is a non-empty RFC-4122 UUID string.
  static bool isValidDatabaseUuid(String? value) {
    if (value == null) return false;

    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;

    return _uuidPattern.hasMatch(trimmed);
  }

  /// Returns the trimmed UUID when valid; otherwise null.
  static String? persistedIdOrNull(String? value) {
    if (!isValidDatabaseUuid(value)) return null;

    return value!.trim();
  }

  /// Adds `id` to [payload] only when [id] is a valid database UUID.
  ///
  /// Removes any stale `id` key when the value is a client local id.
  static Map<String, dynamic> includeUuidIdIfValid(
    Map<String, dynamic> payload,
    String? id,
  ) {
    final persistedId = persistedIdOrNull(id);
    if (persistedId != null) {
      payload['id'] = persistedId;
    } else {
      payload.remove('id');
    }

    return payload;
  }

  /// Generates a RFC-4122 version-4 UUID string for opaque content identifiers.
  static String newV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int value) => value.toRadixString(16).padLeft(2, '0');

    return '${hex(bytes[0])}${hex(bytes[1])}${hex(bytes[2])}${hex(bytes[3])}-'
        '${hex(bytes[4])}${hex(bytes[5])}-'
        '${hex(bytes[6])}${hex(bytes[7])}-'
        '${hex(bytes[8])}${hex(bytes[9])}-'
        '${hex(bytes[10])}${hex(bytes[11])}${hex(bytes[12])}${hex(bytes[13])}${hex(bytes[14])}${hex(bytes[15])}';
  }
}
