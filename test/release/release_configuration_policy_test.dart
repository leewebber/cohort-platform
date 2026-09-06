import 'package:cohort_platform/core/config/app_build_provenance.dart';
import 'package:cohort_platform/core/config/app_release_configuration.dart';
import 'package:cohort_platform/core/config/build_environment.dart';
import 'package:cohort_platform/core/config/release_configuration_code.dart';
import 'package:cohort_platform/core/config/release_configuration_policy.dart';
import 'package:cohort_platform/core/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_jwts.dart';

void main() {
  const policy = ReleaseConfigurationPolicy();
  const productionUrl = 'https://${BuildEnvironment.productionHost}';
  const loopbackUrl = 'http://127.0.0.1:54321';

  ReleaseConfigurationResult validate({
    required BuildEnvironment environment,
    required String url,
    required String key,
  }) {
    return policy.validate(
      AppReleaseConfiguration(
        environment: environment,
        supabaseUrl: url,
        supabaseAnonKey: key,
      ),
    );
  }

  test('production accepts hosted https and anon role', () {
    final result = validate(
      environment: BuildEnvironment.production,
      url: productionUrl,
      key: SyntheticJwts.anon,
    );
    expect(result.isConfigured, isTrue);
  });

  test('production rejects loopback', () {
    final httpLoopback = validate(
      environment: BuildEnvironment.production,
      url: loopbackUrl,
      key: SyntheticJwts.anon,
    );
    final httpsLoopback = validate(
      environment: BuildEnvironment.production,
      url: 'https://127.0.0.1',
      key: SyntheticJwts.anon,
    );
    expect(httpLoopback.isConfigured, isFalse);
    expect(httpsLoopback.isConfigured, isFalse);
    expect(httpLoopback.code, ReleaseConfigurationCode.productionScheme);
    expect(httpsLoopback.code, ReleaseConfigurationCode.productionHost);
    expect(
      httpLoopback.athleteMessage,
      'This build has invalid Production configuration.',
    );
  });

  test('production rejects private IP', () {
    final result = validate(
      environment: BuildEnvironment.production,
      url: 'https://192.168.1.20',
      key: SyntheticJwts.anon,
    );
    expect(result.isConfigured, isFalse);
    expect(result.code, ReleaseConfigurationCode.productionHost);
  });

  test('production rejects placeholder host', () {
    final result = validate(
      environment: BuildEnvironment.production,
      url: 'https://your-project.supabase.co',
      key: SyntheticJwts.anon,
    );
    expect(result.isConfigured, isFalse);
    expect(result.code, ReleaseConfigurationCode.placeholderHost);
  });

  test('preview accepts loopback http', () {
    final result = validate(
      environment: BuildEnvironment.loopbackPreview,
      url: loopbackUrl,
      key: SyntheticJwts.anon,
    );
    expect(result.isConfigured, isTrue);
  });

  test('preview accepts localhost and ipv6 loopback', () {
    expect(
      validate(
        environment: BuildEnvironment.loopbackPreview,
        url: 'http://localhost:54321',
        key: SyntheticJwts.anon,
      ).isConfigured,
      isTrue,
    );
    expect(
      validate(
        environment: BuildEnvironment.loopbackPreview,
        url: 'http://[::1]:54321',
        key: SyntheticJwts.anon,
      ).isConfigured,
      isTrue,
    );
  });

  test('preview rejects hosted https', () {
    final result = validate(
      environment: BuildEnvironment.loopbackPreview,
      url: productionUrl,
      key: SyntheticJwts.anon,
    );
    expect(result.isConfigured, isFalse);
    expect(result.code, ReleaseConfigurationCode.previewScheme);
  });

  test('preview rejects LAN IP', () {
    final result = validate(
      environment: BuildEnvironment.loopbackPreview,
      url: 'http://10.0.0.8:8000',
      key: SyntheticJwts.anon,
    );
    expect(result.isConfigured, isFalse);
    expect(result.code, ReleaseConfigurationCode.previewLan);
  });

  test('missing and malformed URLs are rejected', () {
    expect(
      validate(
        environment: BuildEnvironment.production,
        url: '',
        key: SyntheticJwts.anon,
      ).code,
      ReleaseConfigurationCode.missingUrl,
    );
    expect(
      validate(
        environment: BuildEnvironment.production,
        url: 'not-a-url',
        key: SyntheticJwts.anon,
      ).code,
      ReleaseConfigurationCode.malformedUrl,
    );
  });

  test('malformed JWT is rejected', () {
    expect(
      validate(
        environment: BuildEnvironment.production,
        url: productionUrl,
        key: 'not-a-jwt',
      ).code,
      ReleaseConfigurationCode.malformedKey,
    );
  });

  test('anon JWT is accepted and privileged roles are rejected', () {
    expect(
      validate(
        environment: BuildEnvironment.production,
        url: productionUrl,
        key: SyntheticJwts.anon,
      ).isConfigured,
      isTrue,
    );
    expect(
      validate(
        environment: BuildEnvironment.production,
        url: productionUrl,
        key: SyntheticJwts.serviceRole,
      ).code,
      ReleaseConfigurationCode.privilegedKey,
    );
    expect(
      validate(
        environment: BuildEnvironment.production,
        url: productionUrl,
        key: SyntheticJwts.authenticated,
      ).code,
      ReleaseConfigurationCode.privilegedKey,
    );
    expect(
      validate(
        environment: BuildEnvironment.production,
        url: productionUrl,
        key: SyntheticJwts.customAdmin,
      ).code,
      ReleaseConfigurationCode.privilegedKey,
    );
  });

  test('missing environment fails closed', () {
    final result = policy.validate(
      AppReleaseConfiguration(
        environment: null,
        supabaseUrl: productionUrl,
        supabaseAnonKey: SyntheticJwts.anon,
      ),
    );
    expect(result.code, ReleaseConfigurationCode.missingEnvironment);
  });

  test('development is constrained to loopback or allowlisted hosts', () {
    expect(
      validate(
        environment: BuildEnvironment.development,
        url: loopbackUrl,
        key: SyntheticJwts.anon,
      ).isConfigured,
      isTrue,
    );
    expect(
      validate(
        environment: BuildEnvironment.development,
        url: productionUrl,
        key: SyntheticJwts.anon,
      ).isConfigured,
      isTrue,
    );
    expect(
      validate(
        environment: BuildEnvironment.development,
        url: 'https://${BuildEnvironment.stagingHost}',
        key: SyntheticJwts.anon,
      ).isConfigured,
      isTrue,
    );
    expect(
      validate(
        environment: BuildEnvironment.development,
        url: 'https://other-project.supabase.co',
        key: SyntheticJwts.anon,
      ).code,
      ReleaseConfigurationCode.developmentEndpoint,
    );
  });

  test('validation happens before any Supabase client initialization', () async {
    var initializeCount = 0;
    final result = await SupabaseService.tryInitialize(
      configuration: AppReleaseConfiguration(
        environment: BuildEnvironment.production,
        supabaseUrl: loopbackUrl,
        supabaseAnonKey: SyntheticJwts.anon,
      ),
      initializeClient: ({required url, required anonKey}) async {
        initializeCount += 1;
      },
    );

    expect(result.isConfigured, isFalse);
    expect(result.attemptedClientInitialization, isFalse);
    expect(initializeCount, 0);
    expect(result.errorMessage, isNot(contains('127.0.0.1')));
    expect(result.errorMessage, isNot(contains(SyntheticJwts.anon)));
  });

  test('accepted configuration is the only path that initializes the client', () async {
    var initializeCount = 0;
    final result = await SupabaseService.tryInitialize(
      configuration: AppReleaseConfiguration(
        environment: BuildEnvironment.loopbackPreview,
        supabaseUrl: loopbackUrl,
        supabaseAnonKey: SyntheticJwts.anon,
      ),
      initializeClient: ({required url, required anonKey}) async {
        initializeCount += 1;
        expect(url, loopbackUrl);
      },
    );

    expect(result.isConfigured, isTrue);
    expect(initializeCount, 1);
  });

  test('diagnostics never include URL, key, or token material', () {
    AppBuildProvenance.debugOverride = const AppBuildProvenance(
      environment: BuildEnvironment.production,
      appVersion: '1.0.0',
      buildNumber: '42',
      gitCommit: '388cc4ad42f12f0157ddfe106ae3952ffe241deb',
    );
    addTearDown(() => AppBuildProvenance.debugOverride = null);

    final text = AppBuildProvenance.current.environmentLabel;
    expect(text, 'Production');
    expect(AppBuildProvenance.current.shortCommit, '388cc4a');
    expect(text.toLowerCase(), isNot(contains('supabase')));
    expect(text, isNot(contains(BuildEnvironment.productionHost)));
  });
}
