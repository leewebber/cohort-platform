import 'dart:io';

import 'package:test/test.dart';
import 'package:trusted_plan_package_import/trusted_plan_package_import.dart';

void main() {
  final root = Directory.current.path;

  test('production container is multi-stage and non-root', () {
    final dockerfile = File('$root/Dockerfile').readAsStringSync();

    expect(
      RegExp(r'^FROM ', multiLine: true).allMatches(dockerfile),
      hasLength(2),
    );
    expect(dockerfile, contains('dart compile exe'));
    expect(dockerfile, contains('distroless'));
    expect(dockerfile, contains('USER 65532:65532'));
    expect(dockerfile, contains('org.opencontainers.image.revision'));
    expect(dockerfile, isNot(contains('COPY . ')));
  });

  test('Docker build context is allowlisted and excludes secret material', () {
    final ignore = File('$root/Dockerfile.dockerignore').readAsStringSync();

    expect(ignore.trimLeft(), startsWith('**'));
    expect(ignore, contains('**/.env'));
    expect(ignore, contains('**/.git'));
    expect(ignore, contains('**/.dart_tool'));
    expect(ignore, contains('**/test'));
    expect(ignore, contains('!packages/cohort_plan_package/lib/**'));
    expect(ignore, contains('!server/trusted_plan_package_import/bin/**'));
  });

  test('runtime handles Cloud Run termination gracefully', () {
    final source = File('$root/bin/server.dart').readAsStringSync();

    expect(source, contains('ProcessSignal.sigterm'));
    expect(source, contains('server.close(force: false)'));
    expect(source, contains('authClient.close()'));
    expect(source, contains('rpcClient.close()'));
  });

  test(
    'deployment script pins project region commit digest and secret versions',
    () {
      final script = File(
        '../../tool/deploy/deploy_trusted_plan_import_cloud_run.sh',
      ).readAsStringSync();

      expect(script, contains("PROJECT_ID='cohort-platform-production'"));
      expect(script, contains("REGION='europe-west1'"));
      expect(script, contains("SERVICE='cohort-trusted-plan-import'"));
      expect(script, contains(r'git archive "$SOURCE_COMMIT"'));
      expect(script, contains(r'@${IMAGE_DIGEST}'));
      expect(script, isNot(contains(':latest')));
      expect(script, contains('--min=0'));
      expect(script, contains('--max=2'));
      expect(script, contains('--concurrency=4'));
      expect(script, contains('--memory=512Mi'));
      expect(script, isNot(contains('--memory=256Mi')));
      expect(script, contains('FOUNDER_ALLOWLIST_SECRET_VERSION=\'1\''));
      expect(script, contains('SERVICE_ROLE_SECRET_VERSION=\'1\''));
    },
  );

  test('production target remains Cohort Field Manual only', () {
    expect(
      TrustedImportServerConfig.productionSupabaseHost,
      'otnhhdxstdnwccehacku.supabase.co',
    );
  });

  test('no debugging or configuration endpoint is exposed', () {
    final sources = Directory('$root/lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(sources, isNot(contains('/debug')));
    expect(sources, isNot(contains('/swagger')));
    expect(sources, isNot(contains('/openapi')));
    expect(sources, isNot(contains('/config')));
    expect(sources, isNot(contains('Platform.environment.toString')));
  });
}
