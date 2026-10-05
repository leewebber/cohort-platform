import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_exception.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';

import '../../../domain/running_workout/running_workout.dart';
import '../../private_programme/reviewed_protocol_graph_artifact.dart';
import '../domain/programme_review_models.dart';
import 'executable_protocol_sql_reader.dart';
import 'founder_protocol_review_mapper.dart';
import 'programme_review_json.dart';
import 'programme_review_source.dart';

class ProgrammeReviewProjector {
  const ProgrammeReviewProjector({
    this.compiler = const PlanPackageCompiler(),
    this.founderParser = const FounderProgrammeYamlParser(),
    this.founderMapper = const FounderProtocolReviewMapper(),
    this.protocolReader = const ExecutableProtocolSqlReader(),
  });

  final PlanPackageCompiler compiler;
  final FounderProgrammeYamlParser founderParser;
  final FounderProtocolReviewMapper founderMapper;
  final ExecutableProtocolSqlReader protocolReader;

  ProgrammeReviewCatalog project(ProgrammeReviewProjectionRequest request) {
    final programmes = <ProgrammeReviewProgramme>[];
    final fixtures = <ProgrammeReviewProgramme>[];
    final inputs = <String>{};

    for (final bundle in request.bundles) {
      inputs.add(bundle.spec.planPackagePath);
      if (bundle.spec.founderYamlPath != null) {
        inputs.add(bundle.spec.founderYamlPath!);
      }
      if (bundle.spec.publicationJsonPath != null) {
        inputs.add(bundle.spec.publicationJsonPath!);
      }
      if (bundle.spec.reviewedProtocolGraphPath != null) {
        inputs.add(bundle.spec.reviewedProtocolGraphPath!);
      }
      inputs.addAll(bundle.spec.executableProtocolSqlPaths);
      inputs.addAll(bundle.spec.correctionSqlPaths);
      final projected = projectBundle(bundle);
      if (bundle.spec.fixture) {
        fixtures.add(projected);
      } else {
        programmes.add(projected);
      }
    }

    programmes.sort((a, b) => a.catalogId.compareTo(b.catalogId));
    fixtures.sort((a, b) => a.catalogId.compareTo(b.catalogId));
    final planned = [...request.plannedFamilies]
      ..sort((a, b) => a.buildOrder.compareTo(b.buildOrder));
    final inputList = inputs.toList()..sort();

    return ProgrammeReviewCatalog(
      authority: ProgrammeReviewCatalog.derivedAuthority,
      sourceInputs: inputList,
      programmes: List<ProgrammeReviewProgramme>.unmodifiable(programmes),
      plannedFamilies: List<ProgrammeReviewPlannedFamily>.unmodifiable(planned),
      developerFixtures: List<ProgrammeReviewProgramme>.unmodifiable(fixtures),
    );
  }

  String projectCanonicalJson(ProgrammeReviewProjectionRequest request) {
    return encodeProgrammeReviewCatalog(project(request));
  }

  ProgrammeReviewProgramme projectBundle(ProgrammeReviewSourceBundle bundle) {
    final findings = <ProgrammeReviewFinding>[];
    final compile = compiler.compile(bundle.planPackageYaml);
    final compileReport = _compileReport(compile);

    if (!compile.isValid || compile.manifest == null) {
      findings.add(
        const ProgrammeReviewFinding(
          code: 'package_compile_failed',
          severity: ProgrammeReviewFindingSeverity.error,
          message:
              'Plan Package compile failed. Session structure is not invented.',
        ),
      );
      return _failedProgramme(bundle, compileReport, findings);
    }

    final manifest = compile.manifest!;
    FounderProgrammeYamlDocument? founder;
    if (bundle.founderYaml != null) {
      try {
        founder = founderParser.parse(bundle.founderYaml!);
      } on FounderProgrammeImportException catch (error) {
        findings.add(
          ProgrammeReviewFinding(
            code: 'founder_yaml_malformed',
            severity: ProgrammeReviewFindingSeverity.error,
            message: error.message,
            sourceContext: bundle.spec.founderYamlPath,
          ),
        );
      }
    }

    final protocolRead = protocolReader.readWithCorrections(
      insertSql: bundle.executableProtocolSql,
      corrections: bundle.correctionSql,
    );
    final protocols = protocolRead.protocols;
    findings.addAll(protocolRead.findings);
    final publication = _publication(bundle, compile.contentHashSha256);
    final reviewedGraph = _reviewedGraph(bundle, compile, findings);

    _metadataFindings(manifest, founder, findings);

    final weeks = _weeks(
      manifest: manifest,
      founder: founder,
      protocols: protocols,
      reviewedGraph: reviewedGraph,
      reviewedGraphPath: bundle.spec.reviewedProtocolGraphPath,
      findings: findings,
    );

    if (bundle.spec.classification ==
        ProgrammeReviewClassification.internalPersonal) {
      findings.add(
        const ProgrammeReviewFinding(
          code: 'internal_personal_not_launch_sku',
          severity: ProgrammeReviewFindingSeverity.info,
          message:
              'Classified as internal/personal. Not a commercial launch product.',
        ),
      );
    }
    if (bundle.spec.classification ==
        ProgrammeReviewClassification.internalPrivate) {
      findings.add(
        const ProgrammeReviewFinding(
          code: 'internal_private_not_public_catalogue',
          severity: ProgrammeReviewFindingSeverity.info,
          message:
              'Classified as internal/private. Withheld from the public '
              'catalogue. Not commercial HYROX Base.',
        ),
      );
    }
    if (bundle.spec.classification ==
        ProgrammeReviewClassification.legacyWithheld) {
      findings.add(
        const ProgrammeReviewFinding(
          code: 'legacy_withheld',
          severity: ProgrammeReviewFindingSeverity.info,
          message:
              'Classified as legacy/withheld. Not deleted or mutated. Not a '
              'multi-week launch family.',
        ),
      );
    }

    final programme = ProgrammeReviewProgramme(
      catalogId: bundle.spec.catalogId,
      classification: bundle.spec.classification,
      title: manifest.programme.name,
      lineageCode: manifest.programme.lineageCode,
      versionNumber: manifest.programme.versionNumber,
      programmeVersionId: publication.programmeVersionId,
      sourcePaths: _sourcePaths(bundle.spec),
      description: manifest.programme.description,
      coachingIntent: manifest.programme.coachingIntent,
      primaryGoal: manifest.programme.primaryGoal,
      durationWeeks: manifest.programme.durationWeeks,
      sessionsPerWeek: manifest.programme.sessionsPerWeek,
      libraryScope: manifest.programme.libraryScope.name,
      scheduledWeekCount: manifest.weeks.length,
      compile: compileReport,
      publication: publication,
      weeks: weeks,
      assessments: manifest.assessments
          .map(
            (item) => {
              'id': item.id,
              'slot_ref': item.slotRef,
              'label': item.label,
            },
          )
          .toList(growable: false),
      evidenceRequirements: manifest.performanceEvidenceRequirements
          .map(
            (item) => {
              'id': item.id,
              'metric': item.metric,
              'required': item.required,
            },
          )
          .toList(growable: false),
      comparisonIdentities: manifest.comparisonIdentities
          .map(
            (item) => {
              'id': item.id,
              'session_lineage_id': item.sessionLineageId,
              'label': item.label,
            },
          )
          .toList(growable: false),
      readiness: const [],
      findings: findings,
    );

    return ProgrammeReviewProgramme(
      catalogId: programme.catalogId,
      classification: programme.classification,
      title: programme.title,
      lineageCode: programme.lineageCode,
      versionNumber: programme.versionNumber,
      programmeVersionId: programme.programmeVersionId,
      sourcePaths: programme.sourcePaths,
      description: programme.description,
      coachingIntent: programme.coachingIntent,
      primaryGoal: programme.primaryGoal,
      durationWeeks: programme.durationWeeks,
      sessionsPerWeek: programme.sessionsPerWeek,
      libraryScope: programme.libraryScope,
      scheduledWeekCount: programme.scheduledWeekCount,
      compile: programme.compile,
      publication: programme.publication,
      weeks: programme.weeks,
      assessments: programme.assessments,
      evidenceRequirements: programme.evidenceRequirements,
      comparisonIdentities: programme.comparisonIdentities,
      readiness: _readiness(programme),
      findings: programme.findings,
    );
  }

  ProgrammeReviewProgramme _failedProgramme(
    ProgrammeReviewSourceBundle bundle,
    ProgrammeReviewCompileReport compile,
    List<ProgrammeReviewFinding> findings,
  ) {
    return ProgrammeReviewProgramme(
      catalogId: bundle.spec.catalogId,
      classification: bundle.spec.classification,
      title: bundle.spec.catalogId,
      lineageCode: bundle.spec.catalogId,
      versionNumber: 0,
      sourcePaths: _sourcePaths(bundle.spec),
      compile: compile,
      publication: const ProgrammeReviewPublicationEvidence(
        establishedLocally: false,
        detail: 'Publication evidence is not evaluated when compile fails.',
      ),
      readiness: _readinessForFailure(compile),
      findings: findings,
    );
  }

  ProgrammeReviewCompileReport _compileReport(
    PlanPackageCompileResult compile,
  ) {
    if (compile.isValid) {
      return ProgrammeReviewCompileReport(
        parseOk: true,
        validationOk: true,
        canonicalisationOk: true,
        state: ProgrammeReviewCompileState.valid,
        contentHashSha256: compile.contentHashSha256,
      );
    }
    final parseFailed = compile.issues.any(
      (issue) => (issue.code ?? '').contains('parse') || issue.path == r'$',
    );
    return ProgrammeReviewCompileReport(
      parseOk: !parseFailed,
      validationOk: false,
      canonicalisationOk: false,
      state: ProgrammeReviewCompileState.invalid,
      issues: [
        for (final issue in compile.issues)
          ProgrammeReviewFinding(
            code: issue.code ?? 'package_issue',
            severity: ProgrammeReviewFindingSeverity.error,
            message: issue.message,
            sourceContext: issue.path,
          ),
      ],
    );
  }

  ProgrammeReviewPublicationEvidence _publication(
    ProgrammeReviewSourceBundle bundle,
    String? compileHash,
  ) {
    final raw = bundle.publicationJson;
    if (raw == null) {
      return const ProgrammeReviewPublicationEvidence(
        establishedLocally: false,
        detail:
            'No committed publication artifact. Hosted default cannot be '
            'established locally.',
      );
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('Publication artifact is not an object.');
      }
      final versionId = decoded['programme_version_id']?.toString();
      final hash = decoded['source_package_hash']?.toString();
      final kind = decoded['publication_kind']?.toString();
      final hashMatches =
          hash != null && compileHash != null && hash == compileHash;
      final privateExact = kind == 'private_exact_version';
      return ProgrammeReviewPublicationEvidence(
        establishedLocally: versionId != null && hash != null,
        programmeVersionId: versionId,
        sourcePackageHash: hash,
        artifactPath: bundle.spec.publicationJsonPath,
        detail: privateExact
            ? (hashMatches
                  ? 'Private publication artifact hash matches the compiled '
                        'package. Hosted private publication is not established '
                        'locally. Not a public-catalogue default.'
                  : 'Private publication artifact present. Hash does not match '
                        'the compiled package. Hosted publication is not '
                        'established locally.')
            : (hashMatches
                  ? 'M9 publication artifact hash matches the compiled package. '
                        'Hosted catalogue default cannot be established locally.'
                  : 'M9 publication artifact present. Hash ${hashMatches ? 'matches' : 'does not match'} '
                        'compiled package. Hosted default cannot be established locally.'),
      );
    } catch (error) {
      return ProgrammeReviewPublicationEvidence(
        establishedLocally: false,
        artifactPath: bundle.spec.publicationJsonPath,
        detail: 'Publication artifact could not be read: $error',
      );
    }
  }

  ReviewedProtocolGraphResult? _reviewedGraph(
    ProgrammeReviewSourceBundle bundle,
    PlanPackageCompileResult compile,
    List<ProgrammeReviewFinding> findings,
  ) {
    final graphSource = bundle.reviewedProtocolGraphJson;
    final graphPath = bundle.spec.reviewedProtocolGraphPath;
    if (graphSource == null && graphPath == null) return null;
    if (graphSource == null || graphPath == null) {
      findings.add(
        const ProgrammeReviewFinding(
          code: 'reviewed_protocol_graph_missing',
          severity: ProgrammeReviewFindingSeverity.error,
          message:
              'The reviewed protocol graph path and bytes must both be present.',
        ),
      );
      return null;
    }
    try {
      final publication = jsonDecode(bundle.publicationJson ?? '');
      if (publication is! Map) {
        throw const FormatException('Publication artifact is not an object.');
      }
      final publishedPath = publication['protocol_graph_path']?.toString();
      final expectedHash = publication['protocol_graph_sha256']?.toString();
      final expectedPackageHash = publication['source_package_hash']
          ?.toString();
      if (publishedPath != graphPath ||
          expectedHash == null ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(expectedHash) ||
          expectedPackageHash != compile.contentHashSha256) {
        throw const ReviewedProtocolGraphArtifactException(
          'protocol_graph_attestation_missing',
          'Publication evidence must pin the exact package hash, reviewed graph path, and graph SHA-256.',
        );
      }
      return const ReviewedProtocolGraphArtifact().inspect(
        compileResult: compile,
        source: graphSource,
        expectedSha256: expectedHash,
      );
    } on ReviewedProtocolGraphArtifactException catch (error) {
      findings.add(
        ProgrammeReviewFinding(
          code: error.code,
          severity: ProgrammeReviewFindingSeverity.error,
          message: error.message,
          sourceContext: graphPath,
        ),
      );
    } catch (error) {
      findings.add(
        ProgrammeReviewFinding(
          code: 'reviewed_protocol_graph_invalid',
          severity: ProgrammeReviewFindingSeverity.error,
          message: 'Reviewed protocol graph evidence is invalid: $error',
          sourceContext: graphPath,
        ),
      );
    }
    return null;
  }

  void _metadataFindings(
    PlanPackageManifest manifest,
    FounderProgrammeYamlDocument? founder,
    List<ProgrammeReviewFinding> findings,
  ) {
    if (manifest.programme.durationWeeks == null) {
      findings.add(
        const ProgrammeReviewFinding(
          code: 'missing_duration_weeks',
          severity: ProgrammeReviewFindingSeverity.warning,
          message: 'duration_weeks is not authored on the Plan Package.',
        ),
      );
    } else if (manifest.programme.durationWeeks != manifest.weeks.length) {
      findings.add(
        ProgrammeReviewFinding(
          code: 'duration_disagrees_with_schedule',
          severity: ProgrammeReviewFindingSeverity.warning,
          message:
              'Authored duration_weeks is ${manifest.programme.durationWeeks} '
              'but the package schedules ${manifest.weeks.length} week(s).',
        ),
      );
    }
    if (manifest.weeks.length == 1) {
      findings.add(
        const ProgrammeReviewFinding(
          code: 'single_week_programme',
          severity: ProgrammeReviewFindingSeverity.info,
          message: 'This package schedules only one week.',
        ),
      );
    }
    if (founder != null &&
        founder.programme.sessionsPerWeek != null &&
        manifest.programme.sessionsPerWeek != null &&
        founder.programme.sessionsPerWeek !=
            manifest.programme.sessionsPerWeek) {
      findings.add(
        ProgrammeReviewFinding(
          code: 'contradictory_sessions_per_week',
          severity: ProgrammeReviewFindingSeverity.warning,
          message:
              'Founder YAML sessions_per_week is '
              '${founder.programme.sessionsPerWeek}; Plan Package is '
              '${manifest.programme.sessionsPerWeek}. Package remains schedule authority.',
        ),
      );
    }
    findings.add(
      const ProgrammeReviewFinding(
        code: 'package_missing_intended_level',
        severity: ProgrammeReviewFindingSeverity.warning,
        message: 'Intended level is not a Plan Package v1 field. Not invented.',
      ),
    );
    findings.add(
      const ProgrammeReviewFinding(
        code: 'package_missing_equipment',
        severity: ProgrammeReviewFindingSeverity.warning,
        message:
            'Equipment requirements are not a Plan Package v1 field. Not invented.',
      ),
    );
    if (manifest.assessments.isEmpty) {
      findings.add(
        const ProgrammeReviewFinding(
          code: 'empty_assessments',
          severity: ProgrammeReviewFindingSeverity.info,
          message:
              'Package assessments are empty. Metrics profile is not implemented.',
        ),
      );
    }
  }

  List<ProgrammeReviewWeek> _weeks({
    required PlanPackageManifest manifest,
    required FounderProgrammeYamlDocument? founder,
    required Map<String, ExecutableProtocolRecord> protocols,
    required ReviewedProtocolGraphResult? reviewedGraph,
    required String? reviewedGraphPath,
    required List<ProgrammeReviewFinding> findings,
  }) {
    final sessionsByKey = {
      for (final session in manifest.sessions) session.sessionKey: session,
    };
    return [
      for (final week in manifest.weeks)
        ProgrammeReviewWeek(
          weekNumber: week.weekNumber,
          title: week.title,
          phaseKey: week.phaseKey,
          intent: week.intent?.name,
          coachNote: week.coachNote,
          days: [
            for (final day in week.days)
              ProgrammeReviewDay(
                dayKey: day.dayKey,
                dayOrder: day.dayOrder,
                dayType: day.dayType.name,
                title: day.title,
                intent: day.intent?.name,
                coachNote: day.coachNote,
                sessions: [
                  for (final slot in day.slots)
                    _session(
                      slot: slot,
                      ref: sessionsByKey[slot.sessionKey],
                      weekNumber: week.weekNumber,
                      dayOrder: day.dayOrder,
                      founder: founder,
                      protocols: protocols,
                      reviewedGraph: reviewedGraph,
                      reviewedGraphPath: reviewedGraphPath,
                      findings: findings,
                    ),
                ],
              ),
          ],
        ),
    ];
  }

  ProgrammeReviewSession _session({
    required PlanPackageSessionSlot slot,
    required PlanPackageSessionRevisionRef? ref,
    required int weekNumber,
    required int dayOrder,
    required FounderProgrammeYamlDocument? founder,
    required Map<String, ExecutableProtocolRecord> protocols,
    required ReviewedProtocolGraphResult? reviewedGraph,
    required String? reviewedGraphPath,
    required List<ProgrammeReviewFinding> findings,
  }) {
    final sessionFindings = <ProgrammeReviewFinding>[];
    if (ref == null) {
      sessionFindings.add(
        ProgrammeReviewFinding(
          code: 'missing_session_ref',
          severity: ProgrammeReviewFindingSeverity.error,
          message: 'Slot ${slot.slotKey} references unknown session_key.',
          sourceContext: slot.sessionKey,
        ),
      );
      findings.addAll(sessionFindings);
      return ProgrammeReviewSession(
        sessionKey: slot.sessionKey,
        protocolId: '',
        sessionLineageId: '',
        revisionNumber: 0,
        title: slot.displayTitle ?? slot.sessionKey,
        bodiesResolved: false,
        displayTitle: slot.displayTitle,
        coachNote: slot.coachNote,
        prescriptionSummary: slot.progression.prescriptionSummary,
        slotKey: slot.slotKey,
        sessionOrder: slot.sessionOrder,
        timeOfDay: slot.timeOfDay.dbValue,
        isOptional: slot.isOptional,
        completionExpectation: slot.completionExpectation.dbValue,
        findings: sessionFindings,
      );
    }

    final running = slot.authoredRunningV1;
    ReviewedRunningProjection? runningProjection;
    final bindings = running?.executableStepBindings;
    if (bindings != null && bindings.isNotEmpty) {
      runningProjection = reviewedGraph?.runningProjection(
        protocolId: ref.protocolId,
        workoutId: running!.workoutId,
        sessionBlockId: bindings.first.sessionBlockId,
      );
    }

    var blocks = <ProgrammeReviewBlock>[];
    var resolved = false;
    if (founder != null) {
      blocks = founderMapper.blocksFor(
        document: founder,
        weekNumber: weekNumber,
        dayOrder: dayOrder,
        sessionTitle: ref.title,
      );
      resolved = blocks.isNotEmpty;
    }
    if (!resolved) {
      final protocol = protocols[ref.protocolId];
      if (protocol != null) {
        blocks = protocol.blocks;
        resolved = true;
      }
    }
    if (!resolved && runningProjection != null) {
      blocks = [_reviewedRunningBlock(runningProjection.block)];
      resolved = true;
    }
    if (!resolved) {
      sessionFindings.add(
        ProgrammeReviewFinding(
          code: 'protocol_body_missing',
          severity: ProgrammeReviewFindingSeverity.warning,
          message:
              'Protocol ${ref.protocolId} has no local founder YAML or SQL '
              'INSERT body. Package slot is shown; prescription is not invented.',
          sourceContext: ref.protocolId,
        ),
      );
    }
    for (final block in blocks) {
      if (block.unsupportedReason != null) {
        sessionFindings.add(
          ProgrammeReviewFinding(
            code: 'unsupported_prescription',
            severity: ProgrammeReviewFindingSeverity.warning,
            message: block.unsupportedReason!,
            sourceContext: block.sourceIdentity,
          ),
        );
      }
      for (final movement in block.movements) {
        if (movement.unsupportedReason != null) {
          sessionFindings.add(
            ProgrammeReviewFinding(
              code: 'unsupported_prescription',
              severity: ProgrammeReviewFindingSeverity.warning,
              message: movement.unsupportedReason!,
              sourceContext: '${block.sourceIdentity}:${movement.name}',
            ),
          );
        }
      }
    }
    findings.addAll(sessionFindings);
    final structuredRunning = running == null
        ? null
        : _structuredRunning(
            running: running,
            projection: runningProjection,
            reviewedGraph: reviewedGraph,
            reviewedGraphPath: reviewedGraphPath,
            findings: sessionFindings,
          );
    findings.addAll(sessionFindings.where((item) => !findings.contains(item)));
    return ProgrammeReviewSession(
      sessionKey: ref.sessionKey,
      protocolId: ref.protocolId,
      sessionLineageId: ref.sessionLineageId,
      revisionNumber: ref.revisionNumber,
      title: ref.title,
      bodiesResolved: resolved,
      displayTitle: slot.displayTitle,
      coachNote: slot.coachNote,
      prescriptionSummary: slot.progression.prescriptionSummary,
      slotKey: slot.slotKey,
      sessionOrder: slot.sessionOrder,
      timeOfDay: slot.timeOfDay.dbValue,
      isOptional: slot.isOptional,
      completionExpectation: slot.completionExpectation.dbValue,
      blocks: blocks,
      structuredRunning: structuredRunning,
      findings: sessionFindings,
    );
  }

  ProgrammeReviewBlock _reviewedRunningBlock(Map<String, Object?> block) {
    return ProgrammeReviewBlock(
      position: int.tryParse(block['position']?.toString() ?? '') ?? 1,
      title: block['title']?.toString() ?? 'Structured run',
      blockType: block['block_type']?.toString() ?? 'conditioning',
      sourceIdentity: 'reviewed_protocol_graph',
      content: block['content']?.toString(),
      workoutFormat: block['workout_format']?.toString(),
      timerConfiguration: block['timer_config'] == null
          ? null
          : jsonEncode(block['timer_config']),
      coachNotes: block['coach_notes']?.toString(),
    );
  }

  ProgrammeReviewStructuredRunning _structuredRunning({
    required PlanPackageAuthoredRunningV1 running,
    required ReviewedRunningProjection? projection,
    required ReviewedProtocolGraphResult? reviewedGraph,
    required String? reviewedGraphPath,
    required List<ProgrammeReviewFinding> findings,
  }) {
    final bindings = [
      for (final binding in running.executableStepBindings ?? const [])
        ProgrammeReviewRunningBinding(
          stepId: binding.stepId,
          sessionBlockId: binding.sessionBlockId,
        ),
    ];
    final policies = [
      for (final attachment in running.advisoryAttachments)
        ProgrammeReviewRunningPolicy(
          attachmentId: attachment.attachmentId,
          stepIds: List.unmodifiable(attachment.stepIds),
          policyId: attachment.policy.policyId,
          policyVersion: attachment.policy.policyVersion,
          methodId: attachment.policy.methodId,
          methodVersion: attachment.policy.methodVersion,
          cohortCompletedTestsEligible: attachment
              .policy
              .benchmarkEligibility
              .cohortCompletedTestsEligible,
          manualCompletedTestsEligible: attachment
              .policy
              .benchmarkEligibility
              .manualCompletedTestsEligible,
          externalCompletedTestsEligible: attachment
              .policy
              .benchmarkEligibility
              .externalCompletedTestsEligible,
          freshnessLocalCivilDays: attachment.policy.freshnessLocalCivilDays,
          minimumSpeedBasisPoints: attachment.policy.minimumSpeedBasisPoints,
          maximumSpeedBasisPoints: attachment.policy.maximumSpeedBasisPoints,
          roundingIncrementMillisecondsPerKilometre: attachment
              .policy
              .displayRounding
              .incrementMillisecondsPerKilometre,
          roundingDirection: attachment.policy.displayRounding.direction.name,
        ),
    ];
    final mappingHash = running.executableStepBindings == null
        ? null
        : RunningExecutionMappingHash.compute(
            workoutId: running.workoutId,
            bindings: running.executableStepBindings!.map(
              (binding) => (
                stepId: binding.stepId,
                sessionBlockId: binding.sessionBlockId,
              ),
            ),
          );
    if (running.executableStepBindings == null) {
      return ProgrammeReviewStructuredRunning(
        status: ProgrammeReviewRunningStatus.authoredUnattached,
        statusDetail:
            'Authored running is present, but no exact executable mapping is attached.',
        workoutId: running.workoutId,
        groups: const [],
        bindings: const [],
        policies: policies,
      );
    }
    if (projection == null || reviewedGraph == null) {
      findings.add(
        const ProgrammeReviewFinding(
          code: 'running_review_binding_unverified',
          severity: ProgrammeReviewFindingSeverity.error,
          message:
              'The exact running mapping could not be reproduced from a hash-pinned reviewed graph.',
        ),
      );
      return ProgrammeReviewStructuredRunning(
        status: ProgrammeReviewRunningStatus.invalidBinding,
        statusDetail:
            'Invalid binding — the reviewed executable structure is missing or disagrees.',
        workoutId: running.workoutId,
        sessionBlockId: bindings.isEmpty ? null : bindings.first.sessionBlockId,
        executionMappingSha256: mappingHash,
        protocolGraphPath: reviewedGraphPath,
        groups: const [],
        bindings: bindings,
        policies: policies,
      );
    }

    final attachmentIdsByStep = <String, List<String>>{};
    for (final policy in policies) {
      for (final stepId in policy.stepIds) {
        attachmentIdsByStep
            .putIfAbsent(stepId, () => [])
            .add(policy.attachmentId);
      }
    }
    var scopeInvalid = false;
    final groups = <ProgrammeReviewRunningGroup>[];
    for (final node in projection.workout.steps) {
      switch (node) {
        case RunningAtomicStep():
          final step = _reviewRunningStep(
            node,
            attachmentIdsByStep,
            projection.block['content']?.toString(),
          );
          scopeInvalid = _recordScopeFindings(step, findings) || scopeInvalid;
          groups.add(
            ProgrammeReviewRunningGroup(
              groupId: null,
              repeatCount: 1,
              steps: [step],
            ),
          );
        case RunningRepeatGroup():
          final steps = [
            for (final child in node.steps)
              _reviewRunningStep(
                child,
                attachmentIdsByStep,
                projection.block['content']?.toString(),
              ),
          ];
          for (final step in steps) {
            scopeInvalid = _recordScopeFindings(step, findings) || scopeInvalid;
          }
          groups.add(
            ProgrammeReviewRunningGroup(
              groupId: node.groupId,
              repeatCount: node.count,
              steps: steps,
            ),
          );
      }
    }
    final unsupported = groups
        .expand((group) => group.steps)
        .any((step) => step.durationKind != RunningDurationKind.time.name);
    return ProgrammeReviewStructuredRunning(
      status: scopeInvalid
          ? ProgrammeReviewRunningStatus.invalidBinding
          : unsupported
          ? ProgrammeReviewRunningStatus.unsupported
          : ProgrammeReviewRunningStatus.verified,
      statusDetail: scopeInvalid
          ? 'Invalid target scope — review the blocking findings.'
          : unsupported
          ? 'Authored structure is valid but unsupported by the current runner.'
          : 'Verified for the current time-based structured runner. This is not programme approval.',
      workoutId: running.workoutId,
      sessionBlockId: bindings.first.sessionBlockId,
      executionMappingSha256: mappingHash,
      protocolGraphSha256: reviewedGraph.sha256,
      protocolGraphPath: reviewedGraphPath,
      groups: groups,
      bindings: bindings,
      policies: policies,
    );
  }

  ProgrammeReviewRunningStep _reviewRunningStep(
    RunningAtomicStep step,
    Map<String, List<String>> attachmentIdsByStep,
    String? blockGuidance,
  ) {
    final value = switch (step.duration.kind) {
      RunningDurationKind.time => step.duration.milliseconds,
      RunningDurationKind.distance => step.duration.millimetres,
      RunningDurationKind.manualLap => null,
    };
    return ProgrammeReviewRunningStep(
      stepId: step.stepId,
      role: step.role.name,
      durationKind: step.duration.kind.name,
      durationValue: value,
      guidance: step.notes ?? blockGuidance,
      advisoryAttachmentIds: List.unmodifiable(
        attachmentIdsByStep[step.stepId] ?? const [],
      ),
    );
  }

  bool _recordScopeFindings(
    ProgrammeReviewRunningStep step,
    List<ProgrammeReviewFinding> findings,
  ) {
    var invalid = false;
    if (step.advisoryAttachmentIds.length > 1) {
      invalid = true;
      findings.add(
        ProgrammeReviewFinding(
          code: 'overlapping_advisory_step_scope',
          severity: ProgrammeReviewFindingSeverity.error,
          message:
              'One running step is scoped by multiple advisory attachments. Canonical authored-running validation rejects this package.',
          sourceContext: step.stepId,
        ),
      );
    }
    if (step.hasAdvisoryTarget && step.role != RunningStepRole.work.name) {
      invalid = true;
      findings.add(
        ProgrammeReviewFinding(
          code: 'numeric_target_on_non_work_step',
          severity: ProgrammeReviewFindingSeverity.error,
          message:
              'Advisory pace targets may apply only to authored work steps.',
          sourceContext: step.stepId,
        ),
      );
    }
    return invalid;
  }

  List<String> _sourcePaths(ProgrammeReviewSourceSpec spec) {
    return [
      spec.planPackagePath,
      if (spec.founderYamlPath != null) spec.founderYamlPath!,
      if (spec.publicationJsonPath != null) spec.publicationJsonPath!,
      if (spec.reviewedProtocolGraphPath != null)
        spec.reviewedProtocolGraphPath!,
      ...spec.executableProtocolSqlPaths,
      ...spec.correctionSqlPaths,
    ]..sort();
  }

  List<ProgrammeReviewCheck> _readiness(ProgrammeReviewProgramme programme) {
    final compileOk =
        programme.compile.state == ProgrammeReviewCompileState.valid;
    final hash = programme.compile.contentHashSha256;
    final bodies = programme.weeks
        .expand((week) => week.days)
        .expand((day) => day.sessions)
        .toList(growable: false);
    final missingBodies = bodies.where((session) => !session.bodiesResolved);
    final unsupported = programme.findings.where(
      (item) => item.code == 'unsupported_prescription',
    );
    final running = bodies
        .map((session) => session.structuredRunning)
        .whereType<ProgrammeReviewStructuredRunning>()
        .toList(growable: false);
    final invalidRunning = running.where(
      (item) =>
          item.status == ProgrammeReviewRunningStatus.invalidBinding ||
          item.status == ProgrammeReviewRunningStatus.unsupported,
    );
    final metadataComplete =
        programme.intendedLevel != null && programme.equipment != null;
    return [
      ProgrammeReviewCheck(
        id: 'authoritative_source',
        label: 'Authoritative source found',
        status: ProgrammeReviewCheckStatus.passed,
        detail: programme.sourcePaths.join(', '),
      ),
      ProgrammeReviewCheck(
        id: 'compiler_validation',
        label: 'Compiler / validation pass',
        status: compileOk
            ? ProgrammeReviewCheckStatus.passed
            : ProgrammeReviewCheckStatus.failed,
        detail: compileOk
            ? 'Compiler succeeded. This is not launch approval.'
            : 'Compiler failed. Not launch approved.',
      ),
      ProgrammeReviewCheck(
        id: 'canonical_hash',
        label: 'Stable canonical hash',
        status: hash == null
            ? ProgrammeReviewCheckStatus.failed
            : ProgrammeReviewCheckStatus.passed,
        detail: hash ?? 'No hash because compile failed.',
      ),
      ProgrammeReviewCheck(
        id: 'metadata_completeness',
        label: 'Metadata completeness',
        status: metadataComplete
            ? ProgrammeReviewCheckStatus.passed
            : ProgrammeReviewCheckStatus.failed,
        detail: metadataComplete
            ? 'Package metadata is complete for Studio review.'
            : 'Intended level and/or equipment are absent from Plan Package v1.',
      ),
      ProgrammeReviewCheck(
        id: 'protocol_bodies',
        label: 'Protocol bodies resolvable',
        status: missingBodies.isEmpty
            ? ProgrammeReviewCheckStatus.passed
            : ProgrammeReviewCheckStatus.failed,
        detail: missingBodies.isEmpty
            ? 'Every scheduled session has a local protocol body.'
            : '${missingBodies.length} session(s) lack a local protocol body.',
      ),
      ProgrammeReviewCheck(
        id: 'prescription_renderable',
        label: 'All prescription types renderable',
        status: unsupported.isEmpty
            ? ProgrammeReviewCheckStatus.passed
            : ProgrammeReviewCheckStatus.failed,
        detail: unsupported.isEmpty
            ? 'Known structures rendered. Nothing was silently dropped.'
            : 'Unsupported structures were rendered with warnings.',
      ),
      ProgrammeReviewCheck(
        id: 'running_structure',
        label: 'Running structure readiness',
        status: running.isEmpty
            ? ProgrammeReviewCheckStatus.notAssessed
            : invalidRunning.isNotEmpty
            ? ProgrammeReviewCheckStatus.failed
            : ProgrammeReviewCheckStatus.passed,
        detail: running.isEmpty
            ? 'No authored_running_v1 attachment is present; structured running is not assessed for this programme.'
            : invalidRunning.isNotEmpty
            ? '${invalidRunning.length} structured running slot(s) have invalid or unsupported execution evidence.'
            : '${running.length} structured running slot(s) retain canonical authored structure and reviewed executable evidence. This is not programme approval.',
      ),
      ProgrammeReviewCheck(
        id: 'pace_calculation',
        label: 'Pace-calculation readiness',
        status: running.isEmpty
            ? ProgrammeReviewCheckStatus.notAssessed
            : invalidRunning.isNotEmpty
            ? ProgrammeReviewCheckStatus.failed
            : ProgrammeReviewCheckStatus.passed,
        detail: running.isEmpty
            ? 'No authored advisory running policy is present.'
            : invalidRunning.isNotEmpty
            ? 'Hypothetical calculation is unavailable until canonical structure and target scope validate.'
            : 'Existing B2 arithmetic can preview an authored policy from explicit hypothetical input only. No athlete snapshot or programme approval is established.',
      ),
      ProgrammeReviewCheck(
        id: 'metrics_profile',
        label: 'Metrics-profile readiness',
        status: ProgrammeReviewCheckStatus.notImplemented,
        detail: programme.assessments.isEmpty
            ? 'Package assessments are empty. Metrics profile is not implemented.'
            : 'Package assessment contracts exist. Metrics profile is not implemented.',
      ),
      const ProgrammeReviewCheck(
        id: 'device_garmin',
        label: 'Device / Garmin readiness',
        status: ProgrammeReviewCheckStatus.notImplemented,
        detail: 'Device export/import is not implemented. No export offered.',
      ),
      const ProgrammeReviewCheck(
        id: 'athlete_preview',
        label: 'Athlete-facing preview',
        status: ProgrammeReviewCheckStatus.passed,
        detail:
            'Internal metadata preview only. No enrol, materialise, or hosted call.',
      ),
      const ProgrammeReviewCheck(
        id: 'coaching_approval',
        label: 'Coaching approval',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail:
            'Human coaching review remains required. Compiler success is not approval.',
      ),
      const ProgrammeReviewCheck(
        id: 'execution_device_test',
        label: 'Execution / device test',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail: 'Athlete-device execution remains required.',
      ),
      const ProgrammeReviewCheck(
        id: 'completion_pin_integrity',
        label: 'Completion / pin-integrity test',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail: 'Pin-integrity execution is not assessed by Studio Stage 1.',
      ),
      const ProgrammeReviewCheck(
        id: 'hosted_private_publication',
        label: 'Private hosted publication',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail:
            'Local private artifact is not hosted publication. Lee assignment '
            'is unchanged.',
      ),
      const ProgrammeReviewCheck(
        id: 'lee_assignment',
        label: 'Lee assignment',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail:
            'Current assignment must not be changed by this authoring task.',
      ),
      const ProgrammeReviewCheck(
        id: 'complete_phone_execution',
        label: 'Complete phone execution',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail: 'Phone execution has not been assessed.',
      ),
      ..._baliReadiness(programme, bodies),
    ];
  }

  List<ProgrammeReviewCheck> _baliReadiness(
    ProgrammeReviewProgramme programme,
    List<ProgrammeReviewSession> bodies,
  ) {
    if (programme.lineageCode != 'BALI-HYBRID-BASE') {
      return const [];
    }
    final byWeek = <int, int>{};
    for (final week in programme.weeks) {
      byWeek[week.weekNumber] = week.days.fold<int>(
        0,
        (count, day) => count + day.sessions.length,
      );
    }
    final expected = {1: 9, 2: 9, 3: 9, 4: 8, 5: 9, 6: 9, 7: 9, 8: 9};
    final countsOk =
        bodies.length == 71 &&
        expected.entries.every((entry) => byWeek[entry.key] == entry.value);
    final sameDay = programme.weeks
        .expand((week) => week.days)
        .where((day) => day.sessions.length > 1);
    final amPmOk = sameDay.every((day) {
      if (day.sessions.length != 2) {
        return false;
      }
      return day.sessions.first.timeOfDay == 'morning' &&
          day.sessions.last.timeOfDay == 'afternoon' &&
          day.sessions.first.sessionOrder == 1 &&
          day.sessions.last.sessionOrder == 2;
    });
    final week8 = programme.weeks.where((week) => week.weekNumber == 8);
    final spilloverOk =
        programme.durationWeeks == 8 &&
        week8.isNotEmpty &&
        week8.first.days.any((day) => day.dayOrder == 8) &&
        week8.first.days.any((day) => day.dayOrder == 9);
    final privateOk =
        programme.libraryScope == 'coachPrivate' ||
        programme.libraryScope == 'coach_private';
    return [
      ProgrammeReviewCheck(
        id: 'session_count_71',
        label: 'All 71 sessions represented',
        status: countsOk
            ? ProgrammeReviewCheckStatus.passed
            : ProgrammeReviewCheckStatus.failed,
        detail: countsOk
            ? '71 sessions; weekly counts 9/9/9/8/9/9/9/9.'
            : 'Session counts do not match the authored source.',
      ),
      ProgrammeReviewCheck(
        id: 'same_day_ampm',
        label: 'Same-day AM/PM retained',
        status: amPmOk
            ? ProgrammeReviewCheckStatus.passed
            : ProgrammeReviewCheckStatus.failed,
        detail: amPmOk
            ? 'Sunday and Monday AM precede PM on the same authored day.'
            : 'Same-day AM/PM order is incomplete.',
      ),
      ProgrammeReviewCheck(
        id: 'spillover_retained',
        label: 'Week 8 spillover retained',
        status: spilloverOk
            ? ProgrammeReviewCheckStatus.passed
            : ProgrammeReviewCheckStatus.failed,
        detail: spilloverOk
            ? 'Eight-week label retained. W8 D8 and D9 remain in week 8.'
            : 'Spillover days are missing or the duration label changed.',
      ),
      ProgrammeReviewCheck(
        id: 'private_classification',
        label: 'Private classification',
        status: privateOk
            ? ProgrammeReviewCheckStatus.passed
            : ProgrammeReviewCheckStatus.failed,
        detail: privateOk
            ? 'coach_private. Absent from the public catalogue projection.'
            : 'Library scope is not coach_private.',
      ),
      ProgrammeReviewCheck(
        id: 'source_fidelity',
        label: 'Source-fidelity test',
        status: countsOk && amPmOk && spilloverOk && privateOk
            ? ProgrammeReviewCheckStatus.passed
            : ProgrammeReviewCheckStatus.failed,
        detail:
            'Deterministic source manifest and compile projection must match '
            'the attached Bali source. Compiler success is not coaching approval.',
      ),
    ];
  }

  List<ProgrammeReviewCheck> _readinessForFailure(
    ProgrammeReviewCompileReport compile,
  ) {
    return [
      const ProgrammeReviewCheck(
        id: 'authoritative_source',
        label: 'Authoritative source found',
        status: ProgrammeReviewCheckStatus.failed,
        detail: 'Package compile failed.',
      ),
      ProgrammeReviewCheck(
        id: 'compiler_validation',
        label: 'Compiler / validation pass',
        status: ProgrammeReviewCheckStatus.failed,
        detail: compile.issues.map((item) => item.message).join(' '),
      ),
      const ProgrammeReviewCheck(
        id: 'canonical_hash',
        label: 'Stable canonical hash',
        status: ProgrammeReviewCheckStatus.failed,
        detail: 'No hash.',
      ),
      const ProgrammeReviewCheck(
        id: 'metadata_completeness',
        label: 'Metadata completeness',
        status: ProgrammeReviewCheckStatus.failed,
        detail: 'Not evaluated.',
      ),
      const ProgrammeReviewCheck(
        id: 'protocol_bodies',
        label: 'Protocol bodies resolvable',
        status: ProgrammeReviewCheckStatus.failed,
        detail: 'Not evaluated.',
      ),
      const ProgrammeReviewCheck(
        id: 'prescription_renderable',
        label: 'All prescription types renderable',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail: 'Not evaluated.',
      ),
      const ProgrammeReviewCheck(
        id: 'running_structure',
        label: 'Running structure readiness',
        status: ProgrammeReviewCheckStatus.notImplemented,
        detail: 'Not implemented.',
      ),
      const ProgrammeReviewCheck(
        id: 'pace_calculation',
        label: 'Pace-calculation readiness',
        status: ProgrammeReviewCheckStatus.notImplemented,
        detail: 'Not implemented.',
      ),
      const ProgrammeReviewCheck(
        id: 'metrics_profile',
        label: 'Metrics-profile readiness',
        status: ProgrammeReviewCheckStatus.notImplemented,
        detail: 'Not implemented.',
      ),
      const ProgrammeReviewCheck(
        id: 'device_garmin',
        label: 'Device / Garmin readiness',
        status: ProgrammeReviewCheckStatus.notImplemented,
        detail: 'Not implemented.',
      ),
      const ProgrammeReviewCheck(
        id: 'athlete_preview',
        label: 'Athlete-facing preview',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail: 'Not evaluated.',
      ),
      const ProgrammeReviewCheck(
        id: 'coaching_approval',
        label: 'Coaching approval',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail: 'Required.',
      ),
      const ProgrammeReviewCheck(
        id: 'execution_device_test',
        label: 'Execution / device test',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail: 'Required.',
      ),
      const ProgrammeReviewCheck(
        id: 'completion_pin_integrity',
        label: 'Completion / pin-integrity test',
        status: ProgrammeReviewCheckStatus.notAssessed,
        detail: 'Not assessed.',
      ),
    ];
  }
}
