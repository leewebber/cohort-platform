import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Deterministic SHA-256 fingerprint for compute-only scheduling previews.
class ProgrammeSchedulingPreviewFingerprint {
  const ProgrammeSchedulingPreviewFingerprint._();

  static String compute(Map<String, Object?> payload) {
    final canonical = _canonicalJson(payload);
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static String _canonicalJson(Object? value) {
    if (value == null) return 'null';
    if (value is String) return jsonEncode(value);
    if (value is num || value is bool) return jsonEncode(value);
    if (value is List) {
      final items = value.map(_canonicalJson).join(',');
      return '[$items]';
    }
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      final entries = keys
          .map((k) => '${jsonEncode(k)}:${_canonicalJson(value[k])}')
          .join(',');
      return '{$entries}';
    }
    return jsonEncode(value.toString());
  }
}
