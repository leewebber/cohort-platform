import 'dart:async';
import 'dart:convert';
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
  final runtime = TrustedRuntimeHandler(
    importHandler: endpoint.call,
    logSink: stdout.writeln,
  );

  final server = await shelf_io.serve(
    runtime.call,
    config.bindAddress,
    config.port,
  );
  stdout.writeln(
    jsonEncode({
      'severity': 'INFO',
      'event': 'runtime_ready',
      'port': server.port,
    }),
  );

  final shutdown = Completer<void>();
  void requestShutdown(ProcessSignal _) {
    if (!shutdown.isCompleted) shutdown.complete();
  }

  final signalSubscriptions = <StreamSubscription<ProcessSignal>>[
    ProcessSignal.sigterm.watch().listen(requestShutdown),
    ProcessSignal.sigint.watch().listen(requestShutdown),
  ];

  await shutdown.future;
  stdout.writeln(jsonEncode({'severity': 'INFO', 'event': 'runtime_shutdown'}));
  await server.close(force: false);
  authClient.close();
  rpcClient.close();
  for (final subscription in signalSubscriptions) {
    await subscription.cancel();
  }
}
