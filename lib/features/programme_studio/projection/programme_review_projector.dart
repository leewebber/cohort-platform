import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_exception.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_import_models.dart';
import 'package:founder_importer/features/founder_programme_import/founder_programme_yaml_parser.dart';

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

    _metadataFindings(manifest, founder, findings);

    final weeks = _weeks(
      manifest: manifest,
      founder: founder,
      protocols: protocols,
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
      final hashMatches =
          hash != null && compileHash != null && hash == compileHash;
      return ProgrammeReviewPublicationEvidence(
        establishedLocally: versionId != null && hash != null,
        programmeVersionId: versionId,
        sourcePackageHash: hash,
        artifactPath: bundle.spec.publicationJsonPath,
        detail: hashMatches
            ? 'M9 publication artifact hash matches the compiled package. '
                  'Hosted catalogue default cannot be established locally.'
            : 'M9 publication artifact present. Hash ${hashMatches ? 'matches' : 'does not match'} '
                  'compiled package. Hosted default cannot be established locally.',
      );
    } catch (error) {
      return ProgrammeReviewPublicationEvidence(
        establishedLocally: false,
        artifactPath: bundle.spec.publicationJsonPath,
        detail: 'Publication artifact could not be read: $error',
      );
    }
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
        findings: sessionFindings,
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
      blocks: blocks,
      findings: sessionFindings,
    );
  }

  List<String> _sourcePaths(ProgrammeReviewSourceSpec spec) {
    return [
      spec.planPackagePath,
      if (spec.founderYamlPath != null) spec.founderYamlPath!,
      if (spec.publicationJsonPath != null) spec.publicationJsonPath!,
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
      const ProgrammeReviewCheck(
        id: 'running_structure',
        label: 'Running structure readiness',
        status: ProgrammeReviewCheckStatus.notImplemented,
        detail:
            'Structured running workout model is not implemented. Current '
            'timer/block encoding is shown as authored.',
      ),
      const ProgrammeReviewCheck(
        id: 'pace_calculation',
        label: 'Pace-calculation readiness',
        status: ProgrammeReviewCheckStatus.notImplemented,
        detail: 'Pace/zone formulas are not implemented. Not inferred.',
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
