import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:supabase/supabase.dart';

/// Service-role private publication. Does not enrol athletes.
///
/// Required: --owner-id, --url, --service-role-key
/// Optional: --package, --publication
Future<void> main(List<String> args) async {
  final ownerId = _arg(args, '--owner-id');
  final url = _arg(args, '--url') ?? Platform.environment['SUPABASE_URL'];
  final serviceKey =
      _arg(args, '--service-role-key') ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  final packagePath =
      _arg(args, '--package') ??
      'tool/programmes/bali_hybrid_base_v1.plan-package.yaml';
  final publicationPath =
      _arg(args, '--publication') ??
      'content/programmes/bali_hybrid_base/v1/bali_hybrid_base.publication.json';

  if (ownerId == null || ownerId.isEmpty) {
    stderr.writeln('Missing --owner-id');
    exit(2);
  }
  if (url == null ||
      url.contains('your-project') ||
      url.contains('placeholder')) {
    stderr.writeln('Refusing placeholder SUPABASE_URL');
    exit(2);
  }
  if (serviceKey == null || serviceKey.isEmpty) {
    stderr.writeln('Missing service role key');
    exit(2);
  }

  final publication =
      jsonDecode(File(publicationPath).readAsStringSync()) as Map<String, dynamic>;
  final expectedHash = publication['source_package_hash']?.toString();
  final expectedId = publication['programme_version_id']?.toString();
  final expectedKind = publication['publication_kind']?.toString();
  final expectedScope = publication['library_scope']?.toString();
  if (expectedHash == null || expectedId == null) {
    stderr.writeln('Publication artifact missing identity/hash');
    exit(2);
  }
  if (expectedKind != 'private_exact_version' || expectedScope != 'coach_private') {
    stderr.writeln('Publication artifact is not a private exact version');
    exit(2);
  }

  final compiled = const PlanPackageCompiler().compile(
    File(packagePath).readAsStringSync(),
  );
  if (!compiled.isValid || compiled.contentHashSha256 != expectedHash) {
    stderr.writeln('Compiled package hash does not match the approved artifact');
    exit(2);
  }

  final payload = PlanPackageImportPayloadBuilder().build(
    compileResult: compiled,
    importedBy: 'private-exact-publisher',
  );
  payload['publication_kind'] = expectedKind;
  payload['programme_version_id'] = expectedId;
  payload['library_scope'] = expectedScope;
  payload['owner_id'] = ownerId;
  payload['authorised_timezone'] = 'Asia/Makassar';
  payload['authorised_local_start_date'] = '2026-09-26';

  final client = SupabaseClient(url, serviceKey);
  try {
    final response = await client.rpc(
      'publish_private_exact_programme_version',
      params: {'payload': payload},
    );
    final map = response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{'raw': response.toString()};
    stdout.writeln('status=${map['status']}');
    stdout.writeln('programme_version_id=${map['programme_version_id']}');
    stdout.writeln('session_count=${map['session_count']}');
    stdout.writeln('library_scope=${map['library_scope']}');
    if (map['status'] != 'published' && map['status'] != 'already_published') {
      stderr.writeln('code=${map['code']}');
      exit(1);
    }
  } finally {
    client.dispose();
  }
}

String? _arg(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}
