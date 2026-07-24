/// Persistence error surfaced from Programme Engine stores.
///
/// RLS and constraint failures must not be swallowed.
class ProgrammeStoreException implements Exception {
  ProgrammeStoreException(
    this.message, {
    this.code,
    this.details,
    this.hint,
    this.cause,
    this.operation,
    this.tableName,
    this.conflictTarget,
  });

  final String message;
  final String? code;
  final String? details;
  final String? hint;
  final Object? cause;
  final String? operation;
  final String? tableName;
  final String? conflictTarget;

  bool get isAccessDenied {
    final normalizedCode = code?.trim();
    if (normalizedCode == '42501') return true;

    final normalizedMessage = message.toLowerCase();
    return normalizedMessage.contains('permission denied') ||
        normalizedMessage.contains('row-level security');
  }

  bool get isUniqueViolation => code?.trim() == '23505';

  bool get isMissingConflictTarget => code?.trim() == '42P10';

  factory ProgrammeStoreException.fromDynamic(
    Object error, {
    String fallbackMessage = 'Programme store operation failed',
    String? operation,
    String? tableName,
    String? conflictTarget,
  }) {
    if (error is ProgrammeStoreException) return error;

    if (error is Exception) {
      final parsed = _parseExceptionString(error.toString());
      return ProgrammeStoreException(
        parsed.message ?? fallbackMessage,
        code: parsed.code,
        details: parsed.details,
        hint: parsed.hint,
        cause: error,
        operation: operation,
        tableName: tableName,
        conflictTarget: conflictTarget,
      );
    }

    return ProgrammeStoreException(
      error.toString(),
      cause: error,
      operation: operation,
      tableName: tableName,
      conflictTarget: conflictTarget,
    );
  }

  static _ParsedPostgrestError _parseExceptionString(String value) {
    final codeMatch = RegExp(
      r'code:\s*([^,\n]+)',
      caseSensitive: false,
    ).firstMatch(value);
    final messageMatch = RegExp(
      r'message:\s*([^,\n]+)',
      caseSensitive: false,
    ).firstMatch(value);
    final detailsMatch = RegExp(
      r'details:\s*([^,\n]+)',
      caseSensitive: false,
    ).firstMatch(value);
    final hintMatch = RegExp(
      r'hint:\s*([^,\n]+)',
      caseSensitive: false,
    ).firstMatch(value);

    return _ParsedPostgrestError(
      code: _trimToken(codeMatch?.group(1)),
      message: _trimToken(messageMatch?.group(1)),
      details: _trimToken(detailsMatch?.group(1)),
      hint: _trimToken(hintMatch?.group(1)),
    );
  }

  static String? _trimToken(String? value) {
    if (value == null) return null;

    final trimmed = value.trim();
    if (trimmed.endsWith(')')) {
      return trimmed.substring(0, trimmed.length - 1).trim();
    }

    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  String toString() {
    final buffer = StringBuffer('ProgrammeStoreException');
    if (operation != null) buffer.write('[$operation]');
    buffer.write(': $message');
    if (tableName != null) buffer.write(' (table: $tableName)');
    if (conflictTarget != null) buffer.write(' (onConflict: $conflictTarget)');
    if (code != null) buffer.write(' (code: $code)');
    if (details != null) buffer.write(' details: $details');
    if (hint != null) buffer.write(' hint: $hint');
    return buffer.toString();
  }
}

class _ParsedPostgrestError {
  const _ParsedPostgrestError({
    this.code,
    this.message,
    this.details,
    this.hint,
  });

  final String? code;
  final String? message;
  final String? details;
  final String? hint;
}
