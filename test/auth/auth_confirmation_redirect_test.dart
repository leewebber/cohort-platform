import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cohort_platform/features/auth/services/auth_confirmation_redirect.dart';
import 'package:cohort_platform/features/auth/services/auth_service.dart';

class CallbackPkceStorage extends GotrueAsyncStorage {
  final Map<String, String> values = {};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  test(
    'callback is native-only; web and other platforms preserve provider default',
    () {
      for (final p in TargetPlatform.values) {
        expect(authConfirmationRedirect(isWeb: true, platform: p), isNull);
        expect(
          authConfirmationRedirect(isWeb: false, platform: p),
          {
                TargetPlatform.iOS,
                TargetPlatform.android,
                TargetPlatform.macOS,
              }.contains(p)
              ? cohortNativeAuthCallback
              : null,
        );
      }
    },
  );
  test(
    'signup and resend request the exact native callback without exposing sessions',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <Uri>[];
      server.listen((r) async {
        requests.add(r.uri);
        await utf8.decoder.bind(r).join();
        r.response.headers.contentType = ContentType.json;
        r.response.write(
          r.uri.path.endsWith('/signup')
              ? jsonEncode({
                  'user': {
                    'id': 'f1100000-0000-4000-8000-000000000009',
                    'aud': 'authenticated',
                    'email': 'local-fixture@example.com',
                    'created_at': '2026-11-04T00:00:00Z',
                  },
                })
              : '{}',
        );
        await r.response.close();
      });
      final c = SupabaseClient(
        'http://127.0.0.1:${server.port}',
        'local-only-key',
        authOptions: AuthClientOptions(
          autoRefreshToken: false,
          pkceAsyncStorage: CallbackPkceStorage(),
        ),
      );
      addTearDown(c.dispose);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final auth = AuthService(client: c);
      final response = await auth.signUp(
        email: 'local-fixture@example.com',
        password: 'Local-fixture-only-aA1!',
      );
      expect(response.session, isNull);
      await auth.resendSignupVerification(email: 'local-fixture@example.com');
      expect(requests, hasLength(2));
      for (final uri in requests) {
        expect(uri.queryParameters['redirect_to'], cohortNativeAuthCallback);
      }
    },
  );
  test('native callback schemes match the one requested by AuthService', () {
    final ios = File('ios/Runner/Info.plist').readAsStringSync(),
        mac = File('macos/Runner/Info.plist').readAsStringSync(),
        android = File(
          'android/app/src/main/AndroidManifest.xml',
        ).readAsStringSync();
    for (final plist in [ios, mac]) {
      expect(plist, contains('<key>CFBundleURLSchemes</key>'));
      expect(plist, contains('<string>cohortplatform</string>'));
    }
    expect(ios, contains('<key>FlutterDeepLinkingEnabled</key>\n\t<false/>'));
    expect(
      android,
      contains('android:scheme="cohortplatform" android:host="auth-callback"'),
    );
    expect(
      android,
      contains(
        'android:name="flutter_deeplinking_enabled" android:value="false"',
      ),
    );
  });
}
