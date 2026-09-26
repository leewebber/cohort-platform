import 'dart:convert';
import 'dart:io';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:supabase/supabase.dart';

import 'package:cohort_platform/features/private_programme/private_protocol_graph_builder.dart';

/// Service-role incomplete private graph repair. Does not enrol or mutate assignments.
Future<void> main(List<String> args) async {
  final url = _arg(args, '--url') ?? Platform.environment['SUPABASE_URL'];
  final serviceKey =
      _arg(args, '--service-role-key') ??
      Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  final ownerId = _arg(args, '--owner-id');
  final packagePath =
      _arg(args, '--package') ??
      'tool/programmes/bali_hybrid_base_v1.plan-package.yaml';
  final publicationPath =
      _arg(args, '--publication') ??
      'content/programmes/bali_hybrid_base/v1/bali_hybrid_base.publication.json';
  final founderPath =
      _arg(args, '--founder') ??
      'tool/programmes/bali_hybrid_base_v1.founder.yaml';

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
  if (expectedHash == null || expectedId == null) {
    stderr.writeln('Publication artifact missing identity/hash');
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
  final graphs = const PrivateProtocolGraphBuilder().build(
    compileResult: compiled,
    founderYaml: File(founderPath).readAsStringSync(),
  );
  if (graphs.missingProtocolIds.isNotEmpty) {
    stderr.writeln('Founder YAML is missing executable bodies');
    exit(2);
  }
  payload['protocol_graphs'] = graphs.graphs;
  payload['publication_kind'] = 'private_exact_version';
  payload['programme_version_id'] = expectedId;
  payload['library_scope'] = 'coach_private';
  payload['owner_id'] = ownerId;

  final client = SupabaseClient(url, serviceKey);
  try {
    final response = await client.rpc(
      'repair_incomplete_private_programme_graph',
      params: {'payload': payload},
    );
    final map = response is Map
        ? Map<String, dynamic>.from(response)
        : <String, dynamic>{'raw': response.toString()};
    stdout.writeln('status=${map['status']}');
    stdout.writeln('inserted_blocks=${map['inserted_blocks']}');
    stdout.writeln('existing_blocks=${map['existing_blocks']}');
    stdout.writeln('inserted_exercises=${map['inserted_exercises']}');
    stdout.writeln('existing_exercises=${map['existing_exercises']}');
    if (map['status'] != 'repaired') {
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
