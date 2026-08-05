import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/application/adaptation/programme_adaptation_acceptance_service.dart';
import 'package:cohort_platform/application/adaptation/programme_adaptation_proposal_service.dart';
import 'package:cohort_platform/core/persistence/athlete_local_repository.dart';
import 'package:cohort_platform/core/persistence/local_kv_store.dart';
import 'package:cohort_platform/data/repositories/programme_assignment_supabase_store.dart';
import 'package:cohort_platform/data/repositories/programme_version_supabase_store.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_authored_slot_resolver.dart';
import 'package:cohort_platform/features/programme/services/athlete_programme_session_prepare_service.dart';
import 'package:cohort_platform/features/session/services/session_execution_loader.dart';
import 'package:flutter/widgets.dart';

import 'journey_d_credential_handoff.dart';
import 'journey_d_execute_workflow.dart';
import 'journey_d_hosted_execute_ports.dart';
import 'journey_d_non_test_runtime.dart';

/// Dedicated Journey D execute entry for `s17_jd_adapt_*` / PROG-S17-JD-ADAPT.
///
/// Must be launched via the non-test Flutter executable
/// (`tool/staging/run_s17_journey_d_execute_dart.sh`). Hosted mode refuses
/// Flutter test bindings. Consumes private credential only after eligibility.
Future<int> runJourneyDExecuteEntrypoint({
  Map<String, String>? environment,
  bool ensureFlutterBinding = true,
  JourneyDExecutePorts? portsOverride,
  JourneyDExecuteWorkflow? workflowOverride,
  AthleteProgrammeSessionPrepareService? prepareOverride,
  ProgrammeAdaptationProposalService? proposalOverride,
}) async {
  final env = environment ?? Platform.environment;
  final reqPath = env['S17_JD_EXECUTE_REQUEST_FILE'];
  final outPath = env['S17_JD_EXECUTE_RESULT_FILE'];
  final credPath = env['S17_JD_CREDENTIAL_FILE'];
  final handoff = JourneyDCredentialHandoff();
  File? credFile = credPath == null || credPath.trim().isEmpty
      ? null
      : File(credPath.trim());
  var shredded = false;

  if (outPath != null && env[JourneyDNonTestRuntime.loopbackProofEnv] == '1') {
    return JourneyDNonTestRuntime.runLoopbackHttpProof(
      env: env,
      resultPath: outPath,
      surface: 'execute',
    );
  }

  void shredCred() {
    if (credFile != null && !shredded) {
      handoff.shred(credFile!);
      shredded = true;
    }
  }

  if (reqPath == null || outPath == null) {
    stderr.writeln('REFUSED: execute request/result env missing');
    shredCred();
    return 2;
  }

  Map<String, dynamic> request;
  try {
    request =
        jsonDecode(File(reqPath).readAsStringSync()) as Map<String, dynamic>;
  } catch (_) {
    _write(outPath, {
      'ok': false,
      'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
      'detail': 'request_json_parse_failed',
      'journey_d_executed': false,
    });
    shredCred();
    return 2;
  }

  final marker = (request['marker'] as String?)?.trim() ?? '';
  try {
    JourneyDCredentialHandoff.validateMarker(marker);
  } catch (_) {
    _write(outPath, {
      'ok': false,
      'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
      'detail': 'invalid_or_reserved_marker',
      'marker': marker,
      'journey_d_executed': false,
    });
    shredCred();
    return 2;
  }

  final eligibilityPassed = request['eligibility_passed'] == true;
  if (!eligibilityPassed) {
    _write(outPath, {
      'ok': false,
      'classification': 'JOURNEY_D_FIXTURE_INELIGIBLE',
      'detail': 'eligibility_must_pass_before_execute',
      'marker': marker,
      'journey_d_executed': false,
      'credential_consumed': false,
    });
    shredCred();
    return 2;
  }

  if (credFile == null || !credFile.existsSync()) {
    _write(outPath, {
      'ok': false,
      'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
      'detail': 'credential_file_missing',
      'marker': marker,
      'journey_d_executed': false,
    });
    return 2;
  }

  final portsMode = (env['S17_JD_EXECUTE_PORTS'] ?? 'hosted').trim();
  final allowFake = env['S17_JD_ALLOW_FAKE_PORTS'] == '1';

  if (portsMode == 'fake') {
    if (!allowFake) {
      _write(outPath, {
        'ok': false,
        'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
        'detail': 'fake_ports_refused_without_allow',
        'marker': marker,
        'journey_d_executed': false,
        'ports_mode': 'fake_refused',
      });
      shredCred();
      return 2;
    }
  } else if (portsMode != 'hosted') {
    _write(outPath, {
      'ok': false,
      'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
      'detail': 'unknown_ports_mode',
      'marker': marker,
      'journey_d_executed': false,
    });
    shredCred();
    return 2;
  }

  JourneyDPrivateCredential credential;
  try {
    credential = handoff.consumeOnce(
      file: credFile,
      expectedMarker: marker,
    );
  } on JourneyDCredentialHandoffException catch (e) {
    _write(outPath, {
      'ok': false,
      'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
      'detail': e.code,
      'marker': marker,
      'journey_d_executed': false,
      'credential_consumed': e.code == 'already_consumed',
    });
    shredCred();
    return 2;
  }

  try {
    if (portsMode == 'fake') {
      if (portsOverride == null ||
          workflowOverride == null ||
          prepareOverride == null) {
        _write(outPath, {
          'ok': false,
          'classification': 'JOURNEY_D_VALIDATION_SOURCE_BLOCKED',
          'detail': 'fake_execute_requires_injected_ports',
          'marker': marker,
          'journey_d_executed': false,
          'credential_consumed': true,
        });
        return 2;
      }
      final result = await workflowOverride.run(
        marker: marker,
        credential: credential,
        prepareService: prepareOverride,
        eligibilityPassed: true,
      );
      final json = result.toJson();
      json['ports_mode'] = 'fake';
      json['credential_shredded'] = false;
      json['hosted_contact'] = false;
      _write(outPath, json);
      return result.ok ? 0 : 2;
    }

    if (ensureFlutterBinding) {
      WidgetsFlutterBinding.ensureInitialized();
    }

    final apiEnvPath =
        request['api_env_path'] as String? ?? '/tmp/s13b_api.env';
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
        'classification': 'JOURNEY_D_CONTRACT_BLOCKED',
        'detail': 'missing_api_env',
        'marker': marker,
        'journey_d_executed': false,
        'credential_consumed': true,
      });
      return 2;
    }
    if (url.contains('otnhhdxs')) {
      _write(outPath, {
        'ok': false,
        'classification': 'JOURNEY_D_SCOPE_BLOCKED',
        'detail': 'production_url_refused',
        'marker': marker,
        'journey_d_executed': false,
        'credential_consumed': true,
      });
      return 2;
    }
    if (!url.contains('tsbadngz')) {
      _write(outPath, {
        'ok': false,
        'classification': 'JOURNEY_D_SCOPE_BLOCKED',
        'detail': 'non_staging_url_refused',
        'marker': marker,
        'journey_d_executed': false,
        'credential_consumed': true,
      });
      return 2;
    }

    try {
      JourneyDNonTestRuntime.refuseTestBinding(
        surface: 'journey_d_execute_hosted',
      );
    } on StateError catch (e) {
      _write(outPath, {
        'ok': false,
        'classification': 'JOURNEY_D_VALIDATION_SOURCE_BLOCKED',
        'detail': e.message,
        'marker': marker,
        'journey_d_executed': false,
        'credential_consumed': true,
        'test_binding_present': true,
      });
      return 2;
    }

    await JourneyDNonTestRuntime.initializeSupabase(
      url: url,
      anonOrServiceKey: anon,
    );

    final ports =
        portsOverride ??
        HostedJourneyDExecutePorts(
          apiUrl: url,
          serviceKey: service,
          anonKey: anon,
        );
    final prepare =
        prepareOverride ??
        (ports is HostedJourneyDExecutePorts
            ? ports.prepareService
            : AthleteProgrammeSessionPrepareService(
                assignmentStore: const ProgrammeAssignmentSupabaseStore(),
                slotResolver: const AthleteProgrammeAuthoredSlotResolver(
                  versionStore: ProgrammeVersionSupabaseStore(),
                ),
                sessionLoader: SessionExecutionLoader(),
                localRepository: AthleteLocalRepository(InMemoryKvStore()),
              ));

    final permissions = await ports.loadPermissions(
      versionId: credential.versionId,
    );
    final proposalService =
        proposalOverride ??
        ProgrammeAdaptationProposalService(
          loadAdaptationPermissions: (_) async => permissions,
        );
    final workflow =
        workflowOverride ??
        JourneyDExecuteWorkflow(
          ports: ports,
          proposalService: proposalService,
          acceptanceFactory: (prep) => ProgrammeAdaptationAcceptanceService(
            prepareService: prep,
            loadAdaptationPermissions: (_) async => permissions,
          ),
        );

    final result = await workflow.run(
      marker: marker,
      credential: credential,
      prepareService: prepare,
      eligibilityPassed: true,
    );
    final json = result.toJson();
    json['ports_mode'] = 'hosted';
    json['hosted_contact'] = true;
    json['production_excluded'] = true;
    _write(outPath, json);
    return result.ok ? 0 : 2;
  } finally {
    shredCred();
    if (outPath.isNotEmpty && File(outPath).existsSync()) {
      try {
        final existing =
            jsonDecode(File(outPath).readAsStringSync()) as Map<String, dynamic>;
        existing['credential_shredded'] = shredded;
        // Ensure secrets never persist in result.
        existing.remove('password');
        existing.remove('email');
        existing.remove('athlete_password');
        _write(outPath, existing);
      } catch (_) {}
    }
  }
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
