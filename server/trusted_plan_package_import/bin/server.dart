import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:trusted_plan_package_import/trusted_plan_package_import.dart';

Future<void> main() async {
  final config = TrustedImportServerConfig.fromEnvironment(
    Platform.environment,
  );
  final authClient = http.Client();
  final rpcClient = http.Client();
  final endpoint = TrustedFounderPlanPackageImportEndpoint(
    authVerifier: SupabaseAuthTokenVerifier(
      supabaseUrl: config.supabaseUrl,
      anonKey: config.supabaseAnonKey,
      client: authClient,
    ),
    founderAuthority: AllowlistedFounderAuthority(config.founderEmails),
    importRpc: SupabasePlanPackageImportRpc(
      supabaseUrl: config.supabaseUrl,
      serviceRoleKey: config.supabaseServiceRoleKey,
      client: rpcClient,
    ),
    maxYamlBytes: config.maxYamlBytes,
  );

  final server = await shelf_io.serve(
    endpoint.call,
    config.bindAddress,
    config.port,
  );
  stdout.writeln(
    'Trusted Plan Package import runtime listening on port ${server.port}.',
  );
}
