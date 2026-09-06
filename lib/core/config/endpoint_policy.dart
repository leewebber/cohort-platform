import 'build_environment.dart';
import 'release_configuration_code.dart';

class EndpointPolicyDecision {
  const EndpointPolicyDecision._({required this.code});

  final ReleaseConfigurationCode? code;

  bool get isAccepted => code == null;

  static const accepted = EndpointPolicyDecision._(code: null);

  factory EndpointPolicyDecision.rejected(ReleaseConfigurationCode code) {
    return EndpointPolicyDecision._(code: code);
  }
}

/// Canonical URI/IP endpoint policy. No substring matching of the raw URL.
class EndpointPolicy {
  const EndpointPolicy();

  EndpointPolicyDecision validate({
    required BuildEnvironment environment,
    required String rawUrl,
  }) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.missingUrl,
      );
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.malformedUrl,
      );
    }
    if (uri.userInfo.isNotEmpty) {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.malformedUrl,
      );
    }

    final host = uri.host.toLowerCase();
    if (_isPlaceholderHost(host)) {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.placeholderHost,
      );
    }

    return switch (environment) {
      BuildEnvironment.production => _validateProduction(uri, host),
      BuildEnvironment.loopbackPreview => _validateLoopbackPreview(uri, host),
      BuildEnvironment.development => _validateDevelopment(uri, host),
    };
  }

  EndpointPolicyDecision _validateProduction(Uri uri, String host) {
    if (uri.scheme != 'https') {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.productionScheme,
      );
    }
    if (uri.hasPort && uri.port != 443) {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.productionHost,
      );
    }
    if (_isLoopbackHost(host) || _isPrivateOrLocalHost(host)) {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.productionHost,
      );
    }
    if (host != BuildEnvironment.productionHost) {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.productionHost,
      );
    }
    return EndpointPolicyDecision.accepted;
  }

  EndpointPolicyDecision _validateLoopbackPreview(Uri uri, String host) {
    if (uri.scheme != 'http') {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.previewScheme,
      );
    }
    if (!_isLoopbackHost(host)) {
      return EndpointPolicyDecision.rejected(
        _isPrivateOrLocalHost(host)
            ? ReleaseConfigurationCode.previewLan
            : ReleaseConfigurationCode.previewHost,
      );
    }
    return EndpointPolicyDecision.accepted;
  }

  /// Development may use loopback HTTP, Field Manual HTTPS, or Staging HTTPS.
  EndpointPolicyDecision _validateDevelopment(Uri uri, String host) {
    if (_isLoopbackHost(host)) {
      if (uri.scheme != 'http') {
        return EndpointPolicyDecision.rejected(
          ReleaseConfigurationCode.developmentEndpoint,
        );
      }
      return EndpointPolicyDecision.accepted;
    }
    if (host == BuildEnvironment.productionHost ||
        host == BuildEnvironment.stagingHost) {
      if (uri.scheme != 'https') {
        return EndpointPolicyDecision.rejected(
          ReleaseConfigurationCode.developmentEndpoint,
        );
      }
      if (uri.hasPort && uri.port != 443) {
        return EndpointPolicyDecision.rejected(
          ReleaseConfigurationCode.developmentEndpoint,
        );
      }
      return EndpointPolicyDecision.accepted;
    }
    if (_isPrivateOrLocalHost(host)) {
      return EndpointPolicyDecision.rejected(
        ReleaseConfigurationCode.previewLan,
      );
    }
    return EndpointPolicyDecision.rejected(
      ReleaseConfigurationCode.developmentEndpoint,
    );
  }

  static bool _isPlaceholderHost(String host) {
    return host == 'your-project.supabase.co' ||
        host == 'example.supabase.co' ||
        host == 'localhost.example' ||
        host.endsWith('.example') ||
        host.endsWith('.invalid') ||
        host.endsWith('.test');
  }

  static bool _isLoopbackHost(String host) {
    if (host == 'localhost' || host == '::1' || host == '0:0:0:0:0:0:0:1') {
      return true;
    }
    final ipv4 = _parseIpv4(host);
    if (ipv4 != null) return ipv4[0] == 127;
    return false;
  }

  static bool _isPrivateOrLocalHost(String host) {
    if (_isLoopbackHost(host)) return true;
    final ipv4 = _parseIpv4(host);
    if (ipv4 != null) {
      final a = ipv4[0];
      final b = ipv4[1];
      if (a == 10) return true;
      if (a == 192 && b == 168) return true;
      if (a == 172 && b >= 16 && b <= 31) return true;
      if (a == 169 && b == 254) return true;
      if (a == 0) return true;
      return false;
    }
    if (host.contains(':')) {
      final compact = host.toLowerCase();
      if (compact.startsWith('fe80:')) return true;
      if (compact.startsWith('fc') || compact.startsWith('fd')) return true;
      return true;
    }
    return false;
  }

  static List<int>? _parseIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return null;
    final octets = <int>[];
    for (final part in parts) {
      if (part.isEmpty || part.length > 3) return null;
      final value = int.tryParse(part, radix: 10);
      if (value == null || value < 0 || value > 255) return null;
      if (part.length > 1 && part.startsWith('0')) return null;
      octets.add(value);
    }
    return octets;
  }
}
