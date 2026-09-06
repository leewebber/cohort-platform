import 'dart:convert';

import 'release_configuration_code.dart';

class SupabaseKeyPolicyDecision {
  const SupabaseKeyPolicyDecision._({required this.code});

  final ReleaseConfigurationCode? code;

  bool get isAccepted => code == null;

  static const accepted = SupabaseKeyPolicyDecision._(code: null);

  factory SupabaseKeyPolicyDecision.rejected(ReleaseConfigurationCode code) {
    return SupabaseKeyPolicyDecision._(code: code);
  }
}

/// Local JWT structure check. Decoding is not authentication.
class SupabaseKeyPolicy {
  const SupabaseKeyPolicy();

  static const _allowedRole = 'anon';

  SupabaseKeyPolicyDecision validate(String rawKey) {
    final key = rawKey.trim();
    if (key.isEmpty) {
      return SupabaseKeyPolicyDecision.rejected(
        ReleaseConfigurationCode.missingKey,
      );
    }
    if (key == 'your-anon-key' || key.toLowerCase() == 'anon-key') {
      return SupabaseKeyPolicyDecision.rejected(
        ReleaseConfigurationCode.placeholderKey,
      );
    }

    final parts = key.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      return SupabaseKeyPolicyDecision.rejected(
        ReleaseConfigurationCode.malformedKey,
      );
    }

    final payload = _decodeJsonObject(parts[1]);
    if (payload == null) {
      return SupabaseKeyPolicyDecision.rejected(
        ReleaseConfigurationCode.malformedKey,
      );
    }

    final role = payload['role'];
    if (role is! String || role.trim().isEmpty) {
      return SupabaseKeyPolicyDecision.rejected(
        ReleaseConfigurationCode.malformedKey,
      );
    }
    if (role == _allowedRole) {
      return SupabaseKeyPolicyDecision.accepted;
    }
    return SupabaseKeyPolicyDecision.rejected(
      ReleaseConfigurationCode.privilegedKey,
    );
  }

  static Map<String, dynamic>? _decodeJsonObject(String encoded) {
    try {
      final normalized = encoded.replaceAll('-', '+').replaceAll('_', '/');
      final padded = switch (normalized.length % 4) {
        2 => '$normalized==',
        3 => '$normalized=',
        0 => normalized,
        _ => normalized,
      };
      final decoded = utf8.decode(base64.decode(padded));
      final json = jsonDecode(decoded);
      if (json is Map<String, dynamic>) return json;
      if (json is Map) {
        return json.map((key, value) => MapEntry(key.toString(), value));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
