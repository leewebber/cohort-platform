import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/data/repositories/session_lineage_supabase_store.dart';
import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/staging_tooling/journey_d/journey_d_rebind.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hosted Journey D live entrypoint (B4d.21d.1).
///
/// Invoked by tool/staging/run_s17_journey_d_live_dart.sh after Python guards.
/// Reads S17_JD_LIVE_REQUEST_FILE / writes S17_JD_LIVE_RESULT_FILE.
Future<void> main(List<String> args) async {
  final reqPath = Platform.environment['S17_JD_LIVE_REQUEST_FILE'];
  final outPath = Platform.environment['S17_JD_LIVE_RESULT_FILE'];
  if (reqPath == null || outPath == null) {
    stderr.writeln('REFUSED: live request/result env missing');
    exit(2);
  }
  final request =
      jsonDecode(File(reqPath).readAsStringSync()) as Map<String, dynamic>;
  final root = Directory(request['root'] as String);
  final marker = request['marker'] as String;
  final packageYaml = File(
    '${root.path}/${request['package_rel']}',
  ).readAsStringSync();
  final intentJson = File(
    '${root.path}/${request['protocol_intent_rel']}',
  ).readAsStringSync();

  WidgetsFlutterBinding.ensureInitialized();

  final apiEnvPath = request['api_env_path'] as String? ?? '/tmp/s13b_api.env';
  final creds = _loadEnv(File(apiEnvPath));
  final url = (creds['S13_API_URL'] ?? creds['SUPABASE_URL'] ?? '').trim();
  final anon = (creds['S13_ANON_KEY'] ?? creds['SUPABASE_ANON_KEY'] ?? '')
      .trim();
  final service =
      (creds['S13_SERVICE_KEY'] ?? creds['SUPABASE_SERVICE_ROLE_KEY'] ?? '')
          .trim();
  if (url.isEmpty || anon.isEmpty || service.isEmpty) {
    _write(outPath, {
      'ok': false,
      'classification': 'B4D21D1_HOSTED_CONFIG_MISSING',
      'marker': marker,
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
      'detail': 'missing_api_env',
    });
    exit(2);
  }
  if (url.contains('otnhhdxs')) {
    _write(outPath, {
      'ok': false,
      'classification': 'B4D21D1_PRODUCTION_URL_REFUSED',
      'marker': marker,
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
    });
    exit(2);
  }
  if (!url.contains('tsbadngz')) {
    _write(outPath, {
      'ok': false,
      'classification': 'B4D21D1_NON_STAGING_URL_REFUSED',
      'marker': marker,
      'hosted_writes_executed': 0,
      'publish_draft_invocations': 0,
    });
    exit(2);
  }

  // Service-role client for ProtocolBuilder persistence + lineage lookup.
  await Supabase.initialize(url: url, anonKey: service);

  final publisher = ProtocolBuilderJourneyDPublisher(
    protocolBuilderService: ProtocolBuilderService(),
    sessionLineageStore: const SessionLineageSupabaseStore(),
  );
  final creator = JourneyDLiveFixtureCreator(
    preflight: JourneyDHostedHttpPreflight(apiUrl: url, serviceKey: service),
    athleteFactory: JourneyDHostedHttpAthleteFactory(
      apiUrl: url,
      serviceKey: service,
      anonKey: anon,
    ),
    rebindPipeline: JourneyDRebindPipeline(publisher: publisher),
    programmeLifecycle: JourneyDHostedProgrammeLifecycle(
      apiUrl: url,
      serviceKey: service,
    ),
    enrolment: JourneyDHostedEnrolment(apiUrl: url, anonKey: anon),
    materialisation: JourneyDHostedMaterialisation(apiUrl: url, anonKey: anon),
  );

  final result = await creator.run(
    marker: marker,
    protocolIntentJson: intentJson,
    packageYaml: packageYaml,
    stagingConfirmed: true,
    liveAuthorized: true,
  );
  _write(outPath, result.toJson());
  exit(result.ok ? 0 : 2);
}

Map<String, String> _loadEnv(File file) {
  final out = <String, String>{};
  if (!file.existsSync()) return out;
  for (final line in file.readAsLinesSync()) {
    var text = line.trim();
    if (text.startsWith('export ')) text = text.substring(7);
    if (text.isEmpty || text.startsWith('#') || !text.contains('=')) continue;
    final i = text.indexOf('=');
    final k = text.substring(0, i).trim();
    var v = text.substring(i + 1).trim();
    if ((v.startsWith('"') && v.endsWith('"')) ||
        (v.startsWith("'") && v.endsWith("'"))) {
      v = v.substring(1, v.length - 1);
    }
    out[k] = v;
  }
  return out;
}

void _write(String path, Map<String, Object?> data) {
  File(
    path,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(data));
}
