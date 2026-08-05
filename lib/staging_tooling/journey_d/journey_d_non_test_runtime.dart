import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'journey_d_memory_gotrue_storage.dart';

/// Thrown when Journey D Supabase bootstrap is misconfigured or conflicts.
class JourneyDSupabaseInitException implements Exception {
  JourneyDSupabaseInitException(this.code, this.detail);

  final String code;
  final String detail;

  @override
  String toString() => 'JourneyDSupabaseInitException($code: $detail)';
}

/// Shared guards + Supabase bootstrap for Journey D non-test live executables.
///
/// Must not run under [TestWidgetsFlutterBinding]. Uses EmptyLocalStorage so
/// SharedPreferences / plugin persistence is not required.
///
/// Ownership: exactly one successful [initializeSupabase] per process.
/// Never read [Supabase.instance] before initialization — that getter asserts
/// in debug when uninitialized (the 441812a staging create failure).
class JourneyDNonTestRuntime {
  JourneyDNonTestRuntime._();

  static const loopbackProofEnv = 'S17_JD_LOOPBACK_PROOF';

  static bool _ownedInitialized = false;
  static String? _initializedOrigin;
  static bool _initializeInFlight = false;

  /// Process-local ownership flag (never via [Supabase.instance] pre-init).
  static bool get isOwnedInitialized => _ownedInitialized;

  /// Reset ownership bookkeeping only — for isolated local unit tests.
  @visibleForTesting
  static void debugResetOwnership() {
    _ownedInitialized = false;
    _initializedOrigin = null;
    _initializeInFlight = false;
  }

  static String _originOf(String url) {
    final uri = Uri.parse(url.trim());
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    return '${uri.scheme}://${uri.host}:$port';
  }

  /// True when the current binding is a Flutter test binding.
  static bool get isTestBinding {
    try {
      final name = WidgetsBinding.instance.runtimeType.toString();
      return name.contains('TestWidgetsFlutterBinding') ||
          name.contains('AutomatedTestWidgetsFlutterBinding') ||
          name.contains('LiveTestWidgetsFlutterBinding');
    } on Object {
      return false;
    }
  }

  /// Fail closed if a test binding is present (live traffic forbidden).
  static void refuseTestBinding({required String surface}) {
    if (isTestBinding) {
      throw StateError(
        'REFUSED: $surface cannot run under Flutter test binding '
        '(TestWidgetsFlutterBinding). Use the non-test executable.',
      );
    }
  }

  /// Validate non-secret URL/key shape before any client construction.
  static void validateSupabaseConfig({
    required String url,
    required String anonOrServiceKey,
  }) {
    final trimmedUrl = url.trim();
    final trimmedKey = anonOrServiceKey.trim();
    if (trimmedUrl.isEmpty || trimmedKey.isEmpty) {
      throw JourneyDSupabaseInitException(
        'config_missing',
        'url_or_key_empty',
      );
    }
    final uri = Uri.tryParse(trimmedUrl);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      throw JourneyDSupabaseInitException(
        'config_invalid_url',
        'url_must_be_http_or_https_with_host',
      );
    }
    if (trimmedUrl.contains('otnhhdxs')) {
      throw JourneyDSupabaseInitException(
        'config_production_refused',
        'production_host_denied',
      );
    }
  }

  /// Initialize supabase_flutter without SharedPreferences plugins.
  ///
  /// Ordering: optional binding → test-binding refuse → config validate →
  /// single owned [Supabase.initialize] with EmptyLocalStorage + memory PKCE.
  ///
  /// Idempotent for the same host. Conflicting host fails typed.
  static Future<void> initializeSupabase({
    required String url,
    required String anonOrServiceKey,
    bool ensureFlutterBinding = false,
  }) async {
    if (ensureFlutterBinding) {
      WidgetsFlutterBinding.ensureInitialized();
    }
    refuseTestBinding(surface: 'Supabase.initialize');
    validateSupabaseConfig(url: url, anonOrServiceKey: anonOrServiceKey);

    final origin = _originOf(url);
    if (_ownedInitialized) {
      if (_initializedOrigin == origin) {
        return;
      }
      throw JourneyDSupabaseInitException(
        'conflicting_initialization',
        'already_initialized_for_different_origin',
      );
    }
    if (_initializeInFlight) {
      throw JourneyDSupabaseInitException(
        'initialize_in_flight',
        'concurrent_initialize_refused',
      );
    }

    _initializeInFlight = true;
    try {
      // Do NOT read Supabase.instance here. In debug builds the getter asserts:
      // "You must initialize the supabase instance before calling Supabase.instance"
      await Supabase.initialize(
        url: url.trim(),
        anonKey: anonOrServiceKey.trim(),
        authOptions: FlutterAuthClientOptions(
          localStorage: const EmptyLocalStorage(),
          pkceAsyncStorage: JourneyDMemoryGotrueAsyncStorage(),
        ),
      );
      _ownedInitialized = true;
      _initializedOrigin = origin;
    } catch (_) {
      _ownedInitialized = false;
      _initializedOrigin = null;
      rethrow;
    } finally {
      _initializeInFlight = false;
    }
  }

  /// Redacted exception payload for durable ledgers (no secrets).
  static Map<String, Object?> redactException(Object error, StackTrace stack) {
    final raw = error.toString();
    final scrubbed = raw
        .replaceAll(RegExp(r'eyJ[A-Za-z0-9_\-\.]+'), '<jwt>')
        .replaceAll(
          RegExp(r'[A-Za-z0-9._%+-]+@example\.invalid'),
          '<email>',
        )
        .replaceAll(RegExp(r'Bearer\s+\S+', caseSensitive: false), 'Bearer <redacted>');
    final frames = stack
        .toString()
        .split('\n')
        .where((l) => l.contains('package:cohort_platform/'))
        .take(12)
        .map((l) => l.trim())
        .toList();
    return {
      'exception_type': error.runtimeType.toString(),
      'exception_message': scrubbed.length > 240
          ? scrubbed.substring(0, 240)
          : scrubbed,
      'application_stack_frames': frames,
    };
  }

  /// Local-only loopback HTTP proof (never staging mutation).
  static Future<int> runLoopbackHttpProof({
    required Map<String, String> env,
    required String resultPath,
    required String surface,
  }) async {
    final base = (env['S17_JD_LOOPBACK_BASE_URL'] ?? '').trim();
    final key = (env['S17_JD_LOOPBACK_API_KEY'] ?? 'loopback-proof-key').trim();
    if (base.isEmpty) {
      _write(resultPath, {
        'ok': false,
        'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
        'detail': 'S17_JD_LOOPBACK_BASE_URL required',
        'surface': surface,
      });
      return 2;
    }
    final uri = Uri.tryParse(base);
    if (uri == null ||
        (uri.host != '127.0.0.1' && uri.host != 'localhost') ||
        uri.scheme != 'http') {
      _write(resultPath, {
        'ok': false,
        'classification': 'JOURNEY_D_SCOPE_BLOCKED',
        'detail': 'loopback_base_must_be_http_127_0_0_1',
        'surface': surface,
      });
      return 2;
    }
    if (base.contains('otnhhdxs') || base.contains('tsbadngz')) {
      _write(resultPath, {
        'ok': false,
        'classification': 'JOURNEY_D_SCOPE_BLOCKED',
        'detail': 'loopback_must_not_use_hosted_targets',
        'surface': surface,
      });
      return 2;
    }

    try {
      refuseTestBinding(surface: surface);
    } on StateError catch (e) {
      _write(resultPath, {
        'ok': false,
        'classification': 'JOURNEY_D_VALIDATION_SOURCE_BLOCKED',
        'detail': e.message,
        'test_binding_present': true,
        'surface': surface,
      });
      return 2;
    }

    final client = HttpClient();
    try {
      final getReq = await client.getUrl(
        Uri.parse('$base/rest/v1/journey_d_loopback_ping?select=id'),
      );
      getReq.headers.set('apikey', key);
      getReq.headers.set('Authorization', 'Bearer $key');
      getReq.headers.set('X-Journey-D-Surface', surface);
      getReq.headers.set('X-Fixture-Marker', 's17_jd_adapt_loopback_proof');
      final getResp = await getReq.close().timeout(const Duration(seconds: 5));
      final getBody = await getResp.transform(utf8.decoder).join();
      if (getResp.statusCode < 200 || getResp.statusCode >= 300) {
        _write(resultPath, {
          'ok': false,
          'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
          'detail': 'loopback_get_non_2xx_${getResp.statusCode}',
          'test_binding_present': false,
          'plugin_init_required': false,
          'surface': surface,
        });
        return 2;
      }

      final authReq = await client.postUrl(
        Uri.parse('$base/rest/v1/journey_d_loopback_auth'),
      );
      authReq.headers.set('apikey', key);
      authReq.headers.set('Authorization', 'Bearer $key');
      authReq.headers.set('Content-Type', 'application/json');
      authReq.headers.set('X-Journey-D-Surface', surface);
      authReq.headers.set('X-Fixture-Marker', 's17_jd_adapt_loopback_proof');
      authReq.write(jsonEncode({'probe': 'auth', 'surface': surface}));
      final authResp = await authReq.close().timeout(
        const Duration(seconds: 5),
      );
      final authBody = await authResp.transform(utf8.decoder).join();
      if (authResp.statusCode < 200 || authResp.statusCode >= 300) {
        _write(resultPath, {
          'ok': false,
          'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
          'detail': 'loopback_auth_non_2xx_${authResp.statusCode}',
          'test_binding_present': false,
          'plugin_init_required': false,
          'surface': surface,
        });
        return 2;
      }

      final badReq = await client.getUrl(
        Uri.parse('$base/rest/v1/journey_d_loopback_fail'),
      );
      badReq.headers.set('apikey', key);
      badReq.headers.set('Authorization', 'Bearer $key');
      final badResp = await badReq.close().timeout(const Duration(seconds: 5));
      await badResp.drain<void>();
      if (badResp.statusCode >= 200 && badResp.statusCode < 300) {
        _write(resultPath, {
          'ok': false,
          'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
          'detail': 'loopback_fail_endpoint_unexpectedly_2xx',
          'surface': surface,
        });
        return 2;
      }

      _write(resultPath, {
        'ok': true,
        'classification': 'JOURNEY_D_LOOPBACK_HTTP_PROOF_OK',
        'surface': surface,
        'test_binding_present': false,
        'plugin_init_required': false,
        'shared_preferences_required': false,
        'real_http': true,
        'get_status': getResp.statusCode,
        'auth_status': authResp.statusCode,
        'fail_closed_status': badResp.statusCode,
        'get_body_prefix': getBody.length > 32
            ? getBody.substring(0, 32)
            : getBody,
        'auth_body_prefix': authBody.length > 32
            ? authBody.substring(0, 32)
            : authBody,
        'loopback_host': uri.host,
        'production_excluded': true,
      });
      return 0;
    } on SocketException catch (e) {
      _write(resultPath, {
        'ok': false,
        'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
        'detail': 'loopback_socket_${e.runtimeType}',
        'surface': surface,
      });
      return 2;
    } on HttpException catch (e) {
      _write(resultPath, {
        'ok': false,
        'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
        'detail': 'loopback_http_${e.runtimeType}',
        'surface': surface,
      });
      return 2;
    } on FormatException catch (_) {
      _write(resultPath, {
        'ok': false,
        'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
        'detail': 'loopback_malformed_response',
        'surface': surface,
      });
      return 2;
    } finally {
      client.close(force: true);
    }
  }

  static void _write(String path, Map<String, Object?> data) {
    File(
      path,
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
  }
}
