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
  final approvalStore = config.eventDeliveryCredential == null
      ? null
      : SupabasePublicationApprovalStore(
          supabaseUrl: config.supabaseUrl,
          anonKey: config.supabaseAnonKey,
          writerCredential: config.approvalWriterCredential,
          deliveryCredential: config.eventDeliveryCredential!,
          client: rpcClient,
        );
  final v3 = TrustedV3PublicationEndpoint(
    founderPublication: TrustedV3FounderPublication(
      auth: SupabaseAuthTokenVerifier(
        supabaseUrl: config.supabaseUrl,
        anonKey: config.supabaseAnonKey,
        client: authClient,
      ),
      founder: AllowlistedFounderAuthority(config.founderEmails),
      publication: AuthoritativeV3Publication(
        SupabaseV3PublicationAuthority(
          supabaseUrl: config.supabaseUrl,
          serviceRoleKey: config.supabaseServiceRoleKey,
          client: rpcClient,
        ),
      ),
    ),
    events: config.eventSourceMode == 'internal_store'
        ? approvalStore
        : config.publicationEventsUrl == null
        ? null
        : HttpVerifiedPublicationEvents(
            baseUrl: config.publicationEventsUrl!,
            credential: config.publicationEventsCredential!,
            client: rpcClient,
          ),
    exerciseProducer: config.exerciseProducerCredential == null
        ? null
        : SupabaseExercisePublicationProducer(
            supabaseUrl: config.supabaseUrl,
            anonKey: config.supabaseAnonKey,
            producerCredential: config.exerciseProducerCredential!,
            client: rpcClient,
          ),
  );
  final approvals = DurablePublicationApprovalEndpoint(
    founder: v3.founderPublication,
    store: config.approvalsEnabled ? approvalStore : null,
    deliveryHandler: config.exerciseProducerCredential == null ? null : v3.call,
  );
  final runtime = TrustedRuntimeHandler(
    publicationApprovalHandler: approvals.call,
    importHandler: endpoint.call,
    v3PublicationHandler: v3.call,
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
