import 'dart:async';

import 'package:cohort_platform/features/admin/services/protocol_builder_service.dart';
import 'package:cohort_platform/features/authored_plan_package/authored_plan_package.dart';
import 'package:cohort_platform/models/protocol_draft.dart';

import 'journey_d_fixture_identity.dart';
import 'journey_d_live_ports.dart';
import 'journey_d_protocol_publication.dart';
import 'journey_d_publication_plan_builder.dart';
import 'journey_d_rebind_pipeline.dart';
import 'journey_d_write_accounting.dart';
import 'protocol_builder_journey_d_publisher.dart';

/// Deterministic Journey D live fixture creation (B4d.21d.1).
///
/// Callers must enforce Cohort Staging + `S17_JD_LIVE_CREATE=1` + explicit
/// marker before invoking [run]. Never calls [JourneyDProtocolPublisher] from
/// dry-run. Never executes Journey D. Never retries, resumes, cleans up,
/// compensates, deletes, or repairs.
class JourneyDLiveFixtureCreator {
  JourneyDLiveFixtureCreator({
    required this.preflight,
    required this.athleteFactory,
    required this.rebindPipeline,
    required this.programmeLifecycle,
    required this.enrolment,
    required this.materialisation,
    this.importGate = const JourneyDImportGate(),
    this.expectedPreRebindHash =
        '156dfe8cf262e43f4e7e47cab070a37f466d3271fe26b29ca80e5c5e49e8a7d7',
    this.lineageCode = 'PROG-S17-JD-ADAPT',
    this.onLedgerChanged,
    this.stageTimeout = const Duration(seconds: 120),
    ProtocolBuilderService? protocolBuilderService,
    ProtocolDraft Function(JourneyDProtocolPublicationIntent intent)?
        buildProtocolDraft,
  }) : protocolBuilderService =
           protocolBuilderService ?? ProtocolBuilderService(),
       buildProtocolDraft =
           buildProtocolDraft ?? ProtocolBuilderJourneyDPublisher.draftFor;

  final JourneyDLivePreflight preflight;
  final JourneyDLiveAthleteFactory athleteFactory;
  final JourneyDRebindPipeline rebindPipeline;
  final JourneyDLiveProgrammeLifecycle programmeLifecycle;
  final JourneyDLiveEnrolment enrolment;
  final JourneyDLiveMaterialisation materialisation;
  final JourneyDImportGate importGate;
  final String expectedPreRebindHash;
  final String lineageCode;

  /// Production builder used for mutation-free draft validation.
  final ProtocolBuilderService protocolBuilderService;

  /// Same draft translation as [ProtocolBuilderJourneyDPublisher.publish].
  final ProtocolDraft Function(JourneyDProtocolPublicationIntent intent)
      buildProtocolDraft;

  /// Optional durable progress sink (atomic writer owned by caller).
  final void Function(List<JourneyDLiveLedgerStage> stages)? onLedgerChanged;

  /// Per-stage deadline for mutating/network stages.
  final Duration stageTimeout;

  static const stageOrder = <String>[
    'validate_environment',
    'validate_inputs_and_marker',
    'compile_validate_package_local',
    'build_and_validate_current_protocol',
    'build_and_validate_later_protocol',
    'validate_rebind_import_assignment_materialisation_inputs',
    'check_marker_uniqueness_readonly',
    'create_synthetic_athlete',
    'publish_fixture_protocol_current',
    'publish_fixture_protocol_later',
    'rebind_validate_package_for_import',
    'import_programme_version_and_permissions',
    'publish_approve_staging_fixture_version',
    'enrol_assignment',
    'materialise_schedule',
    'stop_prepare_ready',
    'stop_without_journey_d',
  ];

  static const mutatingStages = <String>{
    'create_synthetic_athlete',
    'publish_fixture_protocol_current',
    'publish_fixture_protocol_later',
    'rebind_validate_package_for_import',
    'import_programme_version_and_permissions',
    'publish_approve_staging_fixture_version',
    'enrol_assignment',
    'materialise_schedule',
  };

  /// Runs the full live sequence for an already-validated explicit [marker].
  Future<JourneyDLiveCreateResult> run({
    required String marker,
    required String protocolIntentJson,
    required String packageYaml,
    required bool stagingConfirmed,
    required bool liveAuthorized,
  }) async {
    final stages = {
      for (final name in stageOrder)
        name: JourneyDLiveLedgerStage(
          name: name,
          status: JourneyDPublicationStageState.notStarted,
          mutating: mutatingStages.contains(name),
        ),
    };

    var hostedWrites = 0;
    var publishDraftInvocations = 0;
    var furtherProhibited = false;
    String? lastApplied;
    String? firstFailedOrUnknown;
    JourneyDRebindPipelineResult? rebindResult;
    String? versionId;
    String? assignmentId;
    String? assignmentIdRedacted;
    String? reboundHash;
    String? privateAthleteId;
    String? privatePassword;
    String? privateEmail;
    final writeAccountingByStage = <String, JourneyDWriteAccounting>{};
    JourneyDPublicationPlan? publicationPlan;
    var ok = false;

    JourneyDLiveCreateResult finish({required String classification}) {
      JourneyDLiveCredentialSeed? seed;
      if (ok &&
          privateAthleteId != null &&
          privatePassword != null &&
          privateEmail != null &&
          assignmentId != null &&
          versionId != null) {
        seed = JourneyDLiveCredentialSeed(
          marker: marker,
          athleteId: privateAthleteId!,
          email: privateEmail!,
          password: privatePassword!,
          assignmentId: assignmentId!,
          versionId: versionId!,
        );
      }
      return JourneyDLiveCreateResult(
        ok: ok,
        classification: classification,
        marker: marker,
        stages: List.unmodifiable(stageOrder.map((n) => stages[n]!)),
        hostedWritesExecuted: hostedWrites,
        publishDraftInvocations: publishDraftInvocations,
        furtherMutationProhibited: furtherProhibited,
        lastAppliedStage: lastApplied,
        firstFailedOrUnknownStage: firstFailedOrUnknown,
        reboundContentHashSha256: reboundHash,
        versionIdRedacted: versionId == null
            ? null
            : '${versionId.substring(0, 8)}…',
        assignmentIdRedacted: assignmentIdRedacted,
        retry: false,
        resume: false,
        cleanup: false,
        compensation: false,
        delete: false,
        repair: false,
        journeyDExecuted: false,
        adaptationInvoked: false,
        credentialSeed: seed,
        writeAccountingByStage: Map.unmodifiable(writeAccountingByStage),
      );
    }

    void emit() {
      onLedgerChanged?.call(
        List.unmodifiable(stageOrder.map((n) => stages[n]!)),
      );
    }

    void mark(
      String name,
      JourneyDPublicationStageState state, {
      String detail = '',
    }) {
      stages[name] = stages[name]!.copyWith(status: state, detail: detail);
      if (state == JourneyDPublicationStageState.applied) {
        lastApplied = name;
      } else if (state == JourneyDPublicationStageState.failed ||
          state == JourneyDPublicationStageState.unknown ||
          state == JourneyDPublicationStageState.timedOut) {
        firstFailedOrUnknown ??= name;
        furtherProhibited = true;
      }
      emit();
    }

    Future<T> withStageTimeout<T>(
      String name,
      Future<T> Function() run, {
      required T Function(bool dispatchedLikely) onTimeout,
    }) async {
      mark(name, JourneyDPublicationStageState.inProgress, detail: 'started');
      try {
        return await run().timeout(stageTimeout);
      } on TimeoutException {
        // Outer stage deadline elapsed. Prefer outcome_uncertain once a
        // mutating stage may have dispatched; definite timed_out otherwise.
        final mutating = mutatingStages.contains(name);
        return onTimeout(mutating);
      }
    }

    void blockRemaining(String after) {
      var seen = false;
      for (final name in stageOrder) {
        if (name == after) {
          seen = true;
          continue;
        }
        if (seen &&
            stages[name]!.status == JourneyDPublicationStageState.notStarted) {
          stages[name] = stages[name]!.copyWith(
            detail: 'blocked_by_prior_failure_or_uncertainty',
          );
        }
      }
    }

    if (!stagingConfirmed) {
      mark(
        'validate_environment',
        JourneyDPublicationStageState.failed,
        detail: 'staging_not_confirmed',
      );
      blockRemaining('validate_environment');
      return finish(classification: 'B4D21D1_LIVE_REFUSED_STAGING');
    }
    mark('validate_environment', JourneyDPublicationStageState.applied);

    if (!liveAuthorized) {
      mark(
        'validate_inputs_and_marker',
        JourneyDPublicationStageState.failed,
        detail: 'live_flag_required',
      );
      blockRemaining('validate_inputs_and_marker');
      return finish(classification: 'B4D21D1_LIVE_REFUSED_FLAG');
    }
    if (marker.trim().isEmpty) {
      mark(
        'validate_inputs_and_marker',
        JourneyDPublicationStageState.failed,
        detail: 'explicit_marker_required',
      );
      blockRemaining('validate_inputs_and_marker');
      return finish(classification: 'B4D21D1_LIVE_MARKER_REQUIRED');
    }
    mark(
      'validate_inputs_and_marker',
      JourneyDPublicationStageState.applied,
      detail: marker,
    );

    final compile = const PlanPackageCompiler().compile(packageYaml);
    if (!compile.isValid || compile.manifest == null) {
      mark(
        'compile_validate_package_local',
        JourneyDPublicationStageState.failed,
        detail: 'package_compile_failed',
      );
      blockRemaining('compile_validate_package_local');
      return finish(classification: 'B4D21D1_PACKAGE_COMPILE_FAILED');
    }
    if (compile.contentHashSha256 != expectedPreRebindHash) {
      mark(
        'compile_validate_package_local',
        JourneyDPublicationStageState.failed,
        detail: 'pre_rebind_hash_mismatch',
      );
      blockRemaining('compile_validate_package_local');
      return finish(classification: 'B4D21D1_PRE_REBIND_HASH_MISMATCH');
    }
    if (compile.manifest!.programme.lineageCode != lineageCode) {
      mark(
        'compile_validate_package_local',
        JourneyDPublicationStageState.failed,
        detail: 'lineage_mismatch',
      );
      blockRemaining('compile_validate_package_local');
      return finish(classification: 'B4D21D1_LINEAGE_MISMATCH');
    }
    mark(
      'compile_validate_package_local',
      JourneyDPublicationStageState.applied,
    );

    // Mutation-free protocol preflight (same draft + builder as publication).
    try {
      publicationPlan = const JourneyDPublicationPlanBuilder().build(
        protocolIntentJson: protocolIntentJson,
        packageManifest: compile.manifest!,
      );
    } on JourneyDRebindException catch (error) {
      mark(
        'build_and_validate_current_protocol',
        JourneyDPublicationStageState.failed,
        detail: 'publication_plan_refused:${error.message}',
      );
      blockRemaining('build_and_validate_current_protocol');
      return finish(classification: 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
    }

    final intents = publicationPlan!.intents;
    if (intents.isEmpty) {
      mark(
        'build_and_validate_current_protocol',
        JourneyDPublicationStageState.failed,
        detail: 'publication_plan_empty',
      );
      blockRemaining('build_and_validate_current_protocol');
      return finish(classification: 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
    }

    final currentIntent = intents.first;
    try {
      final currentDraft = buildProtocolDraft(currentIntent);
      protocolBuilderService.validateDraft(currentDraft);
      writeAccountingByStage['build_and_validate_current_protocol'] =
          const JourneyDWriteAccounting(invocationAttempted: true);
      mark(
        'build_and_validate_current_protocol',
        JourneyDPublicationStageState.applied,
        detail:
            'builder_ok:${currentIntent.protocolId}:${currentDraft.sessionFormat}',
      );
    } on ProtocolBuilderException catch (error) {
      writeAccountingByStage['build_and_validate_current_protocol'] =
          JourneyDWriteAccounting.preNetworkSourceFailure;
      mark(
        'build_and_validate_current_protocol',
        JourneyDPublicationStageState.failed,
        detail: _redactPreflightDetail(error.message),
      );
      blockRemaining('build_and_validate_current_protocol');
      return finish(classification: 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
    } on Object catch (error) {
      writeAccountingByStage['build_and_validate_current_protocol'] =
          JourneyDWriteAccounting.preNetworkSourceFailure;
      mark(
        'build_and_validate_current_protocol',
        JourneyDPublicationStageState.failed,
        detail: 'builder_preflight_exception:${error.runtimeType}',
      );
      blockRemaining('build_and_validate_current_protocol');
      return finish(classification: 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
    }

    if (intents.length < 2) {
      mark(
        'build_and_validate_later_protocol',
        JourneyDPublicationStageState.failed,
        detail: 'later_intent_missing',
      );
      blockRemaining('build_and_validate_later_protocol');
      return finish(classification: 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
    }

    final laterIntent = intents[1];
    try {
      final laterDraft = buildProtocolDraft(laterIntent);
      protocolBuilderService.validateDraft(laterDraft);
      writeAccountingByStage['build_and_validate_later_protocol'] =
          const JourneyDWriteAccounting(invocationAttempted: true);
      mark(
        'build_and_validate_later_protocol',
        JourneyDPublicationStageState.applied,
        detail:
            'builder_ok:${laterIntent.protocolId}:${laterDraft.sessionFormat}',
      );
    } on ProtocolBuilderException catch (error) {
      writeAccountingByStage['build_and_validate_later_protocol'] =
          JourneyDWriteAccounting.preNetworkSourceFailure;
      mark(
        'build_and_validate_later_protocol',
        JourneyDPublicationStageState.failed,
        detail: _redactPreflightDetail(error.message),
      );
      blockRemaining('build_and_validate_later_protocol');
      return finish(classification: 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
    } on Object catch (error) {
      writeAccountingByStage['build_and_validate_later_protocol'] =
          JourneyDWriteAccounting.preNetworkSourceFailure;
      mark(
        'build_and_validate_later_protocol',
        JourneyDPublicationStageState.failed,
        detail: 'builder_preflight_exception:${error.runtimeType}',
      );
      blockRemaining('build_and_validate_later_protocol');
      return finish(classification: 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
    }

    // Local rebind/import/assignment/materialisation input readiness.
    try {
      if (currentIntent.exerciseId != 'cohort.exercise.back_squat' ||
          currentIntent.replacementExerciseId !=
              'cohort.exercise.goblet_squat' ||
          currentIntent.substitutionRuleId !=
              'cohort.substitution.back_squat_to_goblet_squat' ||
          !currentIntent.canReplaceExercises ||
          laterIntent.exerciseId != 'cohort.exercise.push_up') {
        throw JourneyDRebindException(
          'REFUSED: journey_d_coaching_semantics_mismatch',
        );
      }
      mark(
        'validate_rebind_import_assignment_materialisation_inputs',
        JourneyDPublicationStageState.applied,
        detail: 'local_inputs_ok',
      );
    } on JourneyDRebindException catch (error) {
      mark(
        'validate_rebind_import_assignment_materialisation_inputs',
        JourneyDPublicationStageState.failed,
        detail: error.message,
      );
      blockRemaining('validate_rebind_import_assignment_materialisation_inputs');
      return finish(classification: 'B4D21D1_PROTOCOL_PREFLIGHT_FAILED');
    }

    final unique = await withStageTimeout(
      'check_marker_uniqueness_readonly',
      () => preflight.checkUnique(marker: marker, lineageCode: lineageCode),
      onTimeout: (_) => const JourneyDLiveStageOutcome(
        state: JourneyDPublicationStageState.timedOut,
        detail: 'check_marker_uniqueness_readonly_timed_out',
      ),
    );
    mark(
      'check_marker_uniqueness_readonly',
      unique.state,
      detail: unique.detail,
    );
    if (!unique.isApplied) {
      blockRemaining('check_marker_uniqueness_readonly');
      final timed =
          unique.state == JourneyDPublicationStageState.timedOut ||
          unique.detail.contains('timed_out');
      final uncertain =
          unique.state == JourneyDPublicationStageState.unknown ||
          unique.detail.contains('dispatched');
      return finish(
        classification: uncertain
            ? 'B4D21D1_PREFLIGHT_OUTCOME_UNCERTAIN'
            : timed
            ? 'B4D21D1_PREFLIGHT_TIMED_OUT'
            : 'B4D21D1_PREFLIGHT_COLLISION',
      );
    }

    final email = journeyDFixtureEmail(marker);
    final athlete = await withStageTimeout(
      'create_synthetic_athlete',
      () => athleteFactory.create(
        marker: marker,
        email: email,
        displayName: 'S17 Journey D Adaptation Athlete',
      ),
      onTimeout: (mutating) => JourneyDLiveAthleteResult(
        state: mutating
            ? JourneyDPublicationStageState.unknown
            : JourneyDPublicationStageState.timedOut,
        detail: mutating
            ? 'create_synthetic_athlete_timed_out_dispatched'
            : 'create_synthetic_athlete_timed_out',
        writeAccounting: JourneyDWriteAccounting(
          invocationAttempted: true,
          requestDispatched: mutating,
          outcomeUncertain: mutating,
        ),
      ),
    );
    writeAccountingByStage['create_synthetic_athlete'] = athlete.writeAccounting;
    mark('create_synthetic_athlete', athlete.state, detail: athlete.detail);
    // Count only confirmed mutations — not bare response/application success.
    // Legacy applied results without accounting still count (tests / older ports).
    if (athlete.writeAccounting.mutationConfirmed ||
        (athlete.isApplied && !athlete.writeAccounting.invocationAttempted)) {
      hostedWrites += 1;
    }
    if (!athlete.isApplied) {
      blockRemaining('create_synthetic_athlete');
      final uncertain =
          athlete.state == JourneyDPublicationStageState.unknown ||
          athlete.detail.contains('dispatched') ||
          athlete.writeAccounting.outcomeUncertain;
      return finish(
        classification: uncertain
            ? 'B4D21D1_ATHLETE_CREATE_OUTCOME_UNCERTAIN'
            : 'B4D21D1_ATHLETE_CREATE_FAILED',
      );
    }
    privateAthleteId = athlete.privateUserId;
    privatePassword = athlete.privatePassword;
    privateEmail = athlete.privateEmail ?? email;

    // Publication + typed rebind (canonical publisher only).
    mark(
      'publish_fixture_protocol_current',
      JourneyDPublicationStageState.inProgress,
      detail: 'started',
    );
    try {
      rebindResult = await rebindPipeline
          .run(
            protocolIntentJson: protocolIntentJson,
            originalPackage: compile.manifest!,
          )
          .timeout(stageTimeout * 2);
    } on TimeoutException {
      mark(
        'publish_fixture_protocol_current',
        JourneyDPublicationStageState.unknown,
        detail: 'publication_or_rebind_timed_out_dispatched',
      );
      blockRemaining('publish_fixture_protocol_current');
      return finish(
        classification: 'B4D21D1_PUBLICATION_OUTCOME_UNCERTAIN',
      );
    }
    // Count publisher invocations that were actually attempted (not blocked).
    publishDraftInvocations = 0;
    for (final r in rebindResult.publicationResults) {
      if (r.detail == 'blocked_by_prior_failure') continue;
      publishDraftInvocations += 1;
    }

    final pubs = rebindResult.publicationResults;
    if (pubs.isEmpty) {
      mark(
        'publish_fixture_protocol_current',
        JourneyDPublicationStageState.failed,
        detail: 'no_publication_results',
      );
      blockRemaining('publish_fixture_protocol_current');
      return finish(classification: 'B4D21D1_PUBLICATION_FAILED');
    }

    writeAccountingByStage['publish_fixture_protocol_current'] =
        pubs[0].writeAccounting;
    mark(
      'publish_fixture_protocol_current',
      pubs[0].state,
      detail: pubs[0].detail,
    );
    if (pubs[0].writeAccounting.mutationConfirmed ||
        (pubs[0].isApplied && !pubs[0].writeAccounting.invocationAttempted)) {
      hostedWrites += 1;
    }
    if (!pubs[0].isApplied) {
      if (pubs.length > 1) {
        mark(
          'publish_fixture_protocol_later',
          pubs[1].state,
          detail: pubs[1].detail,
        );
      }
      mark(
        'rebind_validate_package_for_import',
        JourneyDPublicationStageState.notStarted,
        detail: 'blocked_by_prior_failure_or_uncertainty',
      );
      blockRemaining('publish_fixture_protocol_current');
      return finish(classification: 'B4D21D1_PUBLICATION_FAILED');
    }

    if (pubs.length < 2) {
      mark(
        'publish_fixture_protocol_later',
        JourneyDPublicationStageState.failed,
        detail: 'missing_later_publication_result',
      );
      blockRemaining('publish_fixture_protocol_later');
      return finish(classification: 'B4D21D1_PUBLICATION_FAILED');
    }
    writeAccountingByStage['publish_fixture_protocol_later'] =
        pubs[1].writeAccounting;
    mark(
      'publish_fixture_protocol_later',
      pubs[1].state,
      detail: pubs[1].detail,
    );
    if (pubs[1].writeAccounting.mutationConfirmed ||
        (pubs[1].isApplied && !pubs[1].writeAccounting.invocationAttempted)) {
      hostedWrites += 1;
    }
    if (!pubs[1].isApplied) {
      mark(
        'rebind_validate_package_for_import',
        JourneyDPublicationStageState.notStarted,
        detail: 'blocked_by_prior_failure_or_uncertainty',
      );
      blockRemaining('publish_fixture_protocol_later');
      return finish(classification: 'B4D21D1_PUBLICATION_FAILED');
    }

    if (!rebindResult.importReady || rebindResult.rebound == null) {
      mark(
        'rebind_validate_package_for_import',
        JourneyDPublicationStageState.failed,
        detail: rebindResult.detail.isEmpty
            ? 'rebind_or_attribution_failed'
            : rebindResult.detail,
      );
      blockRemaining('rebind_validate_package_for_import');
      return finish(classification: 'B4D21D1_REBIND_FAILED');
    }
    mark(
      'rebind_validate_package_for_import',
      JourneyDPublicationStageState.applied,
      detail: 'typed_rebind_ok',
    );
    reboundHash = rebindResult.rebound!.contentHashSha256;
    // Rebind is local — not a hosted write.

    Map<String, Object?> payload;
    try {
      payload = importGate.payloadForImport(
        pipelineResult: rebindResult,
        importedBy: 's17_jd_live_creator',
      );
    } on JourneyDRebindException catch (e) {
      mark(
        'import_programme_version_and_permissions',
        JourneyDPublicationStageState.failed,
        detail: e.message,
      );
      blockRemaining('import_programme_version_and_permissions');
      return finish(classification: 'B4D21D1_IMPORT_GATE_BLOCKED');
    }

    final imported = await programmeLifecycle.importValidatedPackage(
      payload: payload,
      importedBy: 's17_jd_live_creator',
    );
    mark(
      'import_programme_version_and_permissions',
      imported.state,
      detail: imported.detail,
    );
    if (imported.isApplied) {
      hostedWrites += 1;
      versionId = imported.versionId;
    }
    if (!imported.isApplied) {
      blockRemaining('import_programme_version_and_permissions');
      return finish(classification: 'B4D21D1_IMPORT_FAILED');
    }
    final importedVersionId = versionId;
    if (importedVersionId == null || importedVersionId.isEmpty) {
      mark(
        'publish_approve_staging_fixture_version',
        JourneyDPublicationStageState.unknown,
        detail: 'import_applied_without_version_id',
      );
      blockRemaining('publish_approve_staging_fixture_version');
      return finish(classification: 'B4D21D1_IMPORT_VERSION_UNKNOWN');
    }

    final published = await programmeLifecycle.publishAndApprove(
      versionId: importedVersionId,
      actor: 's17_jd_live_creator',
    );
    mark(
      'publish_approve_staging_fixture_version',
      published.state,
      detail: published.detail,
    );
    if (published.isApplied) hostedWrites += 1;
    if (!published.isApplied) {
      blockRemaining('publish_approve_staging_fixture_version');
      return finish(classification: 'B4D21D1_PUBLISH_APPROVE_FAILED');
    }

    final enrolled = await enrolment.enrol(
      programmeVersionId: importedVersionId,
    );
    mark('enrol_assignment', enrolled.state, detail: enrolled.detail);
    if (enrolled.isApplied) {
      hostedWrites += 1;
      assignmentId = enrolled.assignmentId;
      assignmentIdRedacted = enrolled.assignmentIdRedacted;
    }
    if (!enrolled.isApplied) {
      blockRemaining('enrol_assignment');
      return finish(classification: 'B4D21D1_ENROL_FAILED');
    }
    if (assignmentId == null || assignmentId!.isEmpty) {
      mark(
        'materialise_schedule',
        JourneyDPublicationStageState.unknown,
        detail: 'enrol_applied_without_assignment_id',
      );
      blockRemaining('materialise_schedule');
      return finish(classification: 'B4D21D1_ENROL_ASSIGNMENT_UNKNOWN');
    }

    final materialised = await materialisation.materialise(
      programmeAssignmentId: assignmentId!,
    );
    mark(
      'materialise_schedule',
      materialised.state,
      detail: materialised.detail,
    );
    if (materialised.isApplied) hostedWrites += 1;
    if (!materialised.isApplied) {
      blockRemaining('materialise_schedule');
      return finish(classification: 'B4D21D1_MATERIALISE_FAILED');
    }

    mark('stop_prepare_ready', JourneyDPublicationStageState.applied);
    mark(
      'stop_without_journey_d',
      JourneyDPublicationStageState.applied,
      detail: 'Journey D execution unreachable from creator',
    );
    ok = true;
    return finish(classification: 'B4D21D1_LIVE_CREATE_OK');
  }
}

class JourneyDLiveLedgerStage {
  const JourneyDLiveLedgerStage({
    required this.name,
    required this.status,
    required this.mutating,
    this.detail = '',
  });

  final String name;
  final JourneyDPublicationStageState status;
  final bool mutating;
  final String detail;

  JourneyDLiveLedgerStage copyWith({
    JourneyDPublicationStageState? status,
    String? detail,
  }) {
    return JourneyDLiveLedgerStage(
      name: name,
      status: status ?? this.status,
      mutating: mutating,
      detail: detail ?? this.detail,
    );
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'status': statusWire(status),
    'mutating': mutating,
    'detail': detail,
  };

  static String statusWire(JourneyDPublicationStageState s) {
    switch (s) {
      case JourneyDPublicationStageState.notStarted:
        return 'not_started';
      case JourneyDPublicationStageState.inProgress:
        return 'in_progress';
      case JourneyDPublicationStageState.applied:
        return 'succeeded';
      case JourneyDPublicationStageState.failed:
        return 'failed';
      case JourneyDPublicationStageState.timedOut:
        return 'timed_out';
      case JourneyDPublicationStageState.unknown:
        return 'outcome_uncertain';
    }
  }
}

/// In-process credential seed — never serialized by [JourneyDLiveCreateResult.toJson].
class JourneyDLiveCredentialSeed {
  const JourneyDLiveCredentialSeed({
    required this.marker,
    required this.athleteId,
    required this.email,
    required this.password,
    required this.assignmentId,
    required this.versionId,
  });

  final String marker;
  final String athleteId;
  final String email;
  final String password;
  final String assignmentId;
  final String versionId;
}

class JourneyDLiveCreateResult {
  const JourneyDLiveCreateResult({
    required this.ok,
    required this.classification,
    required this.marker,
    required this.stages,
    required this.hostedWritesExecuted,
    required this.publishDraftInvocations,
    required this.furtherMutationProhibited,
    required this.lastAppliedStage,
    required this.firstFailedOrUnknownStage,
    required this.reboundContentHashSha256,
    required this.versionIdRedacted,
    required this.assignmentIdRedacted,
    required this.retry,
    required this.resume,
    required this.cleanup,
    required this.compensation,
    required this.delete,
    required this.repair,
    required this.journeyDExecuted,
    required this.adaptationInvoked,
    this.credentialSeed,
    this.writeAccountingByStage = const {},
  });

  final bool ok;
  final String classification;
  final String marker;
  final List<JourneyDLiveLedgerStage> stages;
  final int hostedWritesExecuted;
  final int publishDraftInvocations;
  final bool furtherMutationProhibited;
  final String? lastAppliedStage;
  final String? firstFailedOrUnknownStage;
  final String? reboundContentHashSha256;
  final String? versionIdRedacted;
  final String? assignmentIdRedacted;
  final bool retry;
  final bool resume;
  final bool cleanup;
  final bool compensation;
  final bool delete;
  final bool repair;
  final bool journeyDExecuted;
  final bool adaptationInvoked;

  /// Private — omitted from [toJson].
  final JourneyDLiveCredentialSeed? credentialSeed;

  /// Per-stage write evidence strength (redacted; no private identifiers).
  final Map<String, JourneyDWriteAccounting> writeAccountingByStage;

  Map<String, Object?> toJson() => {
    'ok': ok,
    'classification': classification,
    'marker': marker,
    'fixture_marker': marker,
    'ledger': {'stages': stages.map((s) => s.toJson()).toList()},
    'stages': stages.map((s) => s.toJson()).toList(),
    'hosted_writes_executed': hostedWritesExecuted,
    'publish_draft_invocations': publishDraftInvocations,
    'further_mutation_prohibited': furtherMutationProhibited,
    'last_applied_stage': lastAppliedStage,
    'first_failed_or_unknown_stage': firstFailedOrUnknownStage,
    'rebound_content_hash_sha256': reboundContentHashSha256,
    'version_id_redacted': versionIdRedacted,
    'assignment_id_redacted': assignmentIdRedacted,
    'retry': retry,
    'resume': resume,
    'cleanup': cleanup,
    'compensation': compensation,
    'deletion': delete,
    'delete': delete,
    'repair': repair,
    'journey_d_executed': journeyDExecuted,
    'adaptation_invoked': adaptationInvoked,
    'credential_handoff_ready': credentialSeed != null,
    'rebind_path': 'REBIND_PATH_READY',
    'mutation_backend': 'hosted',
    'write_accounting': {
      for (final e in writeAccountingByStage.entries) e.key: e.value.toJson(),
    },
  };
}

String _redactPreflightDetail(String message) {
  var redacted = message.trim();
  redacted = redacted.replaceAll(
    RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'),
    '***email***',
  );
  redacted = redacted.replaceAll(
    RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ),
    '***id***',
  );
  if (redacted.length > 240) {
    redacted = '${redacted.substring(0, 240)}…';
  }
  return 'builder_validation:$redacted';
}
