import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'journey_d_memory_gotrue_storage.dart';

/// Shared guards + Supabase bootstrap for Journey D non-test live executables.
///
/// Must not run under [TestWidgetsFlutterBinding]. Uses EmptyLocalStorage so
/// SharedPreferences / plugin persistence is not required.
class JourneyDNonTestRuntime {
  JourneyDNonTestRuntime._();

  static const loopbackProofEnv = 'S17_JD_LOOPBACK_PROOF';

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

  /// Initialize supabase_flutter without SharedPreferences plugins.
  static Future<void> initializeSupabase({
    required String url,
    required String anonOrServiceKey,
  }) async {
    refuseTestBinding(surface: 'Supabase.initialize');
    if (Supabase.instance.isInitialized) {
      return;
    }
    await Supabase.initialize(
      url: url,
      anonKey: anonOrServiceKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: JourneyDMemoryGotrueAsyncStorage(),
      ),
    );
  }

  /// Local-only loopback HTTP proof (never staging mutation).
  ///
  /// Proves the non-test executable can perform real GET + authenticated
  /// requests against a repository-owned loopback server.
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
      // Real GET
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

      // Authenticated POST-style request (still fixture-scoped header)
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

      // Fail-closed probes against the same server (optional endpoints).
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
        'get_body_prefix': getBody.length > 32 ? getBody.substring(0, 32) : getBody,
        'auth_body_prefix':
            authBody.length > 32 ? authBody.substring(0, 32) : authBody,
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
