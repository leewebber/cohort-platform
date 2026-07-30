import 'package:yaml/yaml.dart';

import '../../models/programme_vocabulary.dart';
import '../adaptation/services/adaptation_policy_gate.dart';
import 'plan_package_manifest.dart';
import 'plan_package_schema.dart';
import 'plan_package_validation_issue.dart';

/// Strict YAML → untyped map decode boundary for Plan Packages.
///
/// Rejects malformed YAML, unknown fields, invalid types, and forbidden
/// execution-evidence keys. Does not perform semantic programme validation —
/// that is [PlanPackageValidator].
class PlanPackageYamlParser {
  const PlanPackageYamlParser();

  /// Parse YAML into a typed manifest skeleton, collecting structural issues.
  ///
  /// Returns a partial parse only when [issues] is empty; callers must not
  /// compile when issues are present.
  PlanPackageParseOutcome parse(String yamlSource) {
    final issues = <PlanPackageValidationIssue>[];

    final Object? root;
    try {
      root = loadYaml(yamlSource);
    } catch (error) {
      return PlanPackageParseOutcome.failed([
        PlanPackageValidationIssue(
          path: r'$',
          code: 'malformed_yaml',
          message: 'YAML parse failed: $error',
        ),
      ]);
    }

    if (root == null) {
      return PlanPackageParseOutcome.failed([
        const PlanPackageValidationIssue(
          path: r'$',
          code: 'empty_document',
          message: 'YAML document is empty.',
        ),
      ]);
    }

    if (root is! YamlMap) {
      return PlanPackageParseOutcome.failed([
        const PlanPackageValidationIssue(
          path: r'$',
          code: 'root_not_map',
          message: 'Root document must be a YAML mapping.',
        ),
      ]);
    }

    final map = _stringKeyMap(root, r'$', issues);
    if (map == null) {
      return PlanPackageParseOutcome.failed(issues);
    }

    _rejectForbiddenKeys(map, r'$', issues);
    _rejectUnknownKeys(map, r'$', _rootKeys, issues);

    final schemaVersion = _requireInt(
      map,
      'package_schema_version',
      r'$',
      issues,
    );
    if (schemaVersion != null &&
        schemaVersion != PlanPackageSchema.supportedPackageSchemaVersion) {
      issues.add(
        PlanPackageValidationIssue(
          path: 'package_schema_version',
          code: 'unsupported_schema_version',
          message:
              'Unsupported package_schema_version $schemaVersion; '
              'supported: ${PlanPackageSchema.supportedPackageSchemaVersion}.',
        ),
      );
    }

    final programmeMap = _requireMap(map, 'programme', 'programme', issues);
    final sessionsList = _requireList(map, 'sessions', 'sessions', issues);
    final weeksList = _requireList(map, 'weeks', 'weeks', issues);
    final phasesList = _optionalList(map, 'phases', 'phases', issues);
    final adaptationsList = _requireList(
      map,
      'adaptation_permissions',
      'adaptation_permissions',
      issues,
    );
    final invariantsList = _requireList(
      map,
      'protected_invariants',
      'protected_invariants',
      issues,
    );
    final assessmentsList = _requireList(
      map,
      'assessments',
      'assessments',
      issues,
    );
    final evidenceList = _requireList(
      map,
      'performance_evidence_requirements',
      'performance_evidence_requirements',
      issues,
    );
    final comparisonsList = _requireList(
      map,
      'comparison_identities',
      'comparison_identities',
      issues,
    );

    // Reject unknown optional provenance that would pollute meaning if present
    // under non-canonical keys — already covered by root allowlist.

    if (issues.isNotEmpty) {
      return PlanPackageParseOutcome.failed(issues);
    }

    final programme = _parseProgramme(programmeMap!, issues);
    final sessions = <PlanPackageSessionRevisionRef>[];
    for (var i = 0; i < sessionsList!.length; i++) {
      final item = sessionsList[i];
      final path = 'sessions[$i]';
      final itemMap = _asMap(item, path, issues);
      if (itemMap == null) continue;
      final parsed = _parseSession(itemMap, path, issues);
      if (parsed != null) sessions.add(parsed);
    }

    final phases = <PlanPackagePhase>[];
    final phaseItems = phasesList ?? const [];
    for (var i = 0; i < phaseItems.length; i++) {
      final path = 'phases[$i]';
      final itemMap = _asMap(phaseItems[i], path, issues);
      if (itemMap == null) continue;
      final parsed = _parsePhase(itemMap, path, issues);
      if (parsed != null) phases.add(parsed);
    }

    final weeks = <PlanPackageWeek>[];
    for (var i = 0; i < weeksList!.length; i++) {
      final path = 'weeks[$i]';
      final itemMap = _asMap(weeksList[i], path, issues);
      if (itemMap == null) continue;
      final parsed = _parseWeek(itemMap, path, issues);
      if (parsed != null) weeks.add(parsed);
    }

    final adaptations = <PlanPackageAdaptationPermission>[];
    for (var i = 0; i < adaptationsList!.length; i++) {
      final path = 'adaptation_permissions[$i]';
      final itemMap = _asMap(adaptationsList[i], path, issues);
      if (itemMap == null) continue;
      final parsed = _parseAdaptation(itemMap, path, issues);
      if (parsed != null) adaptations.add(parsed);
    }

    final invariants = <PlanPackageProtectedInvariant>[];
    for (var i = 0; i < invariantsList!.length; i++) {
      final path = 'protected_invariants[$i]';
      final itemMap = _asMap(invariantsList[i], path, issues);
      if (itemMap == null) continue;
      final parsed = _parseInvariant(itemMap, path, issues);
      if (parsed != null) invariants.add(parsed);
    }

    final assessments = <PlanPackageAssessment>[];
    for (var i = 0; i < assessmentsList!.length; i++) {
      final path = 'assessments[$i]';
      final itemMap = _asMap(assessmentsList[i], path, issues);
      if (itemMap == null) continue;
      final parsed = _parseAssessment(itemMap, path, issues);
      if (parsed != null) assessments.add(parsed);
    }

    final evidence = <PlanPackageEvidenceRequirement>[];
    for (var i = 0; i < evidenceList!.length; i++) {
      final path = 'performance_evidence_requirements[$i]';
      final itemMap = _asMap(evidenceList[i], path, issues);
      if (itemMap == null) continue;
      final parsed = _parseEvidence(itemMap, path, issues);
      if (parsed != null) evidence.add(parsed);
    }

    final comparisons = <PlanPackageComparisonIdentity>[];
    for (var i = 0; i < comparisonsList!.length; i++) {
      final path = 'comparison_identities[$i]';
      final itemMap = _asMap(comparisonsList[i], path, issues);
      if (itemMap == null) continue;
      final parsed = _parseComparison(itemMap, path, issues);
      if (parsed != null) comparisons.add(parsed);
    }

    if (issues.isNotEmpty || programme == null) {
      return PlanPackageParseOutcome.failed(issues);
    }

    return PlanPackageParseOutcome.ok(
      PlanPackageManifest(
        packageSchemaVersion: schemaVersion!,
        programme: programme,
        sessions: List.unmodifiable(sessions),
        phases: List.unmodifiable(phases),
        weeks: List.unmodifiable(weeks),
        adaptationPermissions: List.unmodifiable(adaptations),
        protectedInvariants: List.unmodifiable(invariants),
        assessments: List.unmodifiable(assessments),
        performanceEvidenceRequirements: List.unmodifiable(evidence),
        comparisonIdentities: List.unmodifiable(comparisons),
      ),
    );
  }

  PlanPackageProgrammeIdentity? _parseProgramme(
    Map<String, Object?> map,
    List<PlanPackageValidationIssue> issues,
  ) {
    const path = 'programme';
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _programmeKeys, issues);

    final lineageCode = _requireIdentity(
      map,
      'lineage_code',
      path,
      issues,
      pattern: PlanPackageSchema.lineageCodePattern,
    );
    final versionNumber = _requirePositiveInt(
      map,
      'version_number',
      path,
      issues,
    );
    final name = _requireNonEmptyString(map, 'name', path, issues);
    final coachingIntent = _requireNonEmptyString(
      map,
      'coaching_intent',
      path,
      issues,
    );
    final libraryScope = _requireLibraryScope(map, path, issues);
    final ownerType = _requireOwnerType(map, path, issues);
    final description = _optionalString(map, 'description', path, issues);
    final durationWeeks = _optionalPositiveInt(
      map,
      'duration_weeks',
      path,
      issues,
    );
    final sessionsPerWeek = _optionalPositiveInt(
      map,
      'sessions_per_week',
      path,
      issues,
    );
    final primaryGoal = _optionalString(map, 'primary_goal', path, issues);

    if (issues.any((i) => i.path.startsWith(path)) &&
        (lineageCode == null ||
            versionNumber == null ||
            name == null ||
            coachingIntent == null ||
            libraryScope == null ||
            ownerType == null)) {
      return null;
    }
    if (lineageCode == null ||
        versionNumber == null ||
        name == null ||
        coachingIntent == null ||
        libraryScope == null ||
        ownerType == null) {
      return null;
    }

    return PlanPackageProgrammeIdentity(
      lineageCode: lineageCode,
      versionNumber: versionNumber,
      name: name,
      description: description,
      libraryScope: libraryScope,
      ownerType: ownerType,
      coachingIntent: coachingIntent,
      durationWeeks: durationWeeks,
      sessionsPerWeek: sessionsPerWeek,
      primaryGoal: primaryGoal,
    );
  }

  PlanPackageSessionRevisionRef? _parseSession(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _sessionKeys, issues);

    final sessionKey = _requireIdentity(map, 'session_key', path, issues);
    final protocolId = _requireIdentity(map, 'protocol_id', path, issues);
    final sessionLineageId = _requireIdentity(
      map,
      'session_lineage_id',
      path,
      issues,
    );
    final revisionNumber = _requirePositiveInt(
      map,
      'revision_number',
      path,
      issues,
    );
    final title = _requireNonEmptyString(map, 'title', path, issues);

    if (sessionKey == null ||
        protocolId == null ||
        sessionLineageId == null ||
        revisionNumber == null ||
        title == null) {
      return null;
    }

    return PlanPackageSessionRevisionRef(
      sessionKey: sessionKey,
      protocolId: protocolId,
      sessionLineageId: sessionLineageId,
      revisionNumber: revisionNumber,
      title: title,
    );
  }

  PlanPackagePhase? _parsePhase(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _phaseKeys, issues);

    final phaseKey = _requireIdentity(map, 'phase_key', path, issues);
    final phaseOrder = _requirePositiveInt(map, 'phase_order', path, issues);
    final title = _requireNonEmptyString(map, 'title', path, issues);
    final intent = _optionalIntent(map, path, issues);
    final coachNote = _optionalString(map, 'coach_note', path, issues);

    if (phaseKey == null || phaseOrder == null || title == null) return null;

    return PlanPackagePhase(
      phaseKey: phaseKey,
      phaseOrder: phaseOrder,
      title: title,
      intent: intent,
      coachNote: coachNote,
    );
  }

  PlanPackageWeek? _parseWeek(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _weekKeys, issues);

    final weekNumber = _requirePositiveInt(map, 'week_number', path, issues);
    final phaseKey = _optionalIdentity(map, 'phase_key', path, issues);
    final title = _optionalString(map, 'title', path, issues);
    final intent = _optionalIntent(map, path, issues);
    final coachNote = _optionalString(map, 'coach_note', path, issues);
    final daysRaw = _requireList(map, 'days', '$path.days', issues);

    final days = <PlanPackageDay>[];
    if (daysRaw != null) {
      for (var i = 0; i < daysRaw.length; i++) {
        final dayPath = '$path.days[$i]';
        final dayMap = _asMap(daysRaw[i], dayPath, issues);
        if (dayMap == null) continue;
        final day = _parseDay(dayMap, dayPath, issues);
        if (day != null) days.add(day);
      }
    }

    if (weekNumber == null) return null;

    return PlanPackageWeek(
      weekNumber: weekNumber,
      phaseKey: phaseKey,
      title: title,
      intent: intent,
      coachNote: coachNote,
      days: List.unmodifiable(days),
    );
  }

  PlanPackageDay? _parseDay(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _dayKeys, issues);

    final dayKeyRaw = _requireNonEmptyString(map, 'day_key', path, issues);
    String? dayKey;
    if (dayKeyRaw != null) {
      if (!PlanPackageSchema.dayKeyPattern.hasMatch(dayKeyRaw)) {
        issues.add(
          PlanPackageValidationIssue(
            path: '$path.day_key',
            code: 'invalid_day_key',
            message:
                'day_key must match ^day_[1-9][0-9]*\$ (got "$dayKeyRaw").',
          ),
        );
      } else {
        dayKey = dayKeyRaw;
      }
    }

    final dayOrder = _requirePositiveInt(map, 'day_order', path, issues);
    final dayType = _requireDayType(map, path, issues);
    final title = _optionalString(map, 'title', path, issues);
    final intent = _optionalIntent(map, path, issues);
    final coachNote = _optionalString(map, 'coach_note', path, issues);
    final slotsRaw = _optionalList(map, 'slots', '$path.slots', issues) ?? [];

    final slots = <PlanPackageSessionSlot>[];
    for (var i = 0; i < slotsRaw.length; i++) {
      final slotPath = '$path.slots[$i]';
      final slotMap = _asMap(slotsRaw[i], slotPath, issues);
      if (slotMap == null) continue;
      final slot = _parseSlot(slotMap, slotPath, issues);
      if (slot != null) slots.add(slot);
    }

    if (dayKey == null || dayOrder == null || dayType == null) return null;

    return PlanPackageDay(
      dayKey: dayKey,
      dayOrder: dayOrder,
      dayType: dayType,
      title: title,
      intent: intent,
      coachNote: coachNote,
      slots: List.unmodifiable(slots),
    );
  }

  PlanPackageSessionSlot? _parseSlot(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _slotKeys, issues);

    final slotKey = _requireIdentity(map, 'slot_key', path, issues);
    final sessionOrder = _requirePositiveInt(
      map,
      'session_order',
      path,
      issues,
    );
    final sessionKey = _requireIdentity(map, 'session_key', path, issues);
    final timeOfDay = _optionalTimeOfDay(map, path, issues);
    final isOptional = _optionalBool(map, 'is_optional', path, issues) ?? false;
    final expectation = _optionalCompletionExpectation(map, path, issues);
    final displayTitle = _optionalString(map, 'display_title', path, issues);
    final coachNote = _optionalString(map, 'coach_note', path, issues);

    final progressionMap = _requireMap(
      map,
      'progression',
      '$path.progression',
      issues,
    );
    PlanPackageAuthoredProgression? progression;
    if (progressionMap != null) {
      progression = _parseProgression(
        progressionMap,
        '$path.progression',
        issues,
      );
    }

    if (slotKey == null ||
        sessionOrder == null ||
        sessionKey == null ||
        progression == null) {
      return null;
    }

    return PlanPackageSessionSlot(
      slotKey: slotKey,
      sessionOrder: sessionOrder,
      sessionKey: sessionKey,
      progression: progression,
      timeOfDay: timeOfDay ?? ProgrammeSessionTimeOfDay.any,
      isOptional: isOptional,
      completionExpectation:
          expectation ?? ProgrammeSessionCompletionExpectation.required,
      displayTitle: displayTitle,
      coachNote: coachNote,
    );
  }

  PlanPackageAuthoredProgression? _parseProgression(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _progressionKeys, issues);

    final summary = _requireNonEmptyString(
      map,
      'prescription_summary',
      path,
      issues,
    );
    final volumeNote = _optionalString(map, 'volume_note', path, issues);
    final intensityNote = _optionalString(map, 'intensity_note', path, issues);
    final coachNote = _optionalString(map, 'coach_note', path, issues);

    if (summary == null) return null;

    return PlanPackageAuthoredProgression(
      prescriptionSummary: summary,
      volumeNote: volumeNote,
      intensityNote: intensityNote,
      coachNote: coachNote,
    );
  }

  PlanPackageAdaptationPermission? _parseAdaptation(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _adaptationKeys, issues);

    final id = _requireIdentity(map, 'id', path, issues);
    final changeKind = _requireAdaptationKind(map, path, issues);
    final targetRef = _requireIdentity(map, 'target_ref', path, issues);
    final agreement = _requireBool(
      map,
      'athlete_agreement_required',
      path,
      issues,
    );
    final scopeNote = _optionalString(map, 'scope_note', path, issues);

    if (id == null ||
        changeKind == null ||
        targetRef == null ||
        agreement == null) {
      return null;
    }

    return PlanPackageAdaptationPermission(
      id: id,
      changeKind: changeKind,
      targetRef: targetRef,
      athleteAgreementRequired: agreement,
      scopeNote: scopeNote,
    );
  }

  PlanPackageProtectedInvariant? _parseInvariant(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _invariantKeys, issues);

    final id = _requireIdentity(map, 'id', path, issues);
    final kindRaw = _requireNonEmptyString(map, 'kind', path, issues);
    final kind = PlanPackageInvariantKindYaml.fromYaml(kindRaw);
    if (kindRaw != null && kind == null) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.kind',
          code: 'invalid_enum',
          message: 'Invalid protected invariant kind "$kindRaw".',
        ),
      );
    }
    final targetRef = _requireIdentity(map, 'target_ref', path, issues);
    final description = _requireNonEmptyString(
      map,
      'description',
      path,
      issues,
    );

    if (id == null ||
        kind == null ||
        targetRef == null ||
        description == null) {
      return null;
    }

    return PlanPackageProtectedInvariant(
      id: id,
      kind: kind,
      targetRef: targetRef,
      description: description,
    );
  }

  PlanPackageAssessment? _parseAssessment(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _assessmentKeys, issues);

    final id = _requireIdentity(map, 'id', path, issues);
    final slotRef = _requireIdentity(map, 'slot_ref', path, issues);
    final evidenceRequirement = _requireNonEmptyString(
      map,
      'evidence_requirement',
      path,
      issues,
    );
    final comparisonIdentityId = _requireIdentity(
      map,
      'comparison_identity_id',
      path,
      issues,
    );
    final label = _optionalString(map, 'label', path, issues);

    if (id == null ||
        slotRef == null ||
        evidenceRequirement == null ||
        comparisonIdentityId == null) {
      return null;
    }

    return PlanPackageAssessment(
      id: id,
      slotRef: slotRef,
      evidenceRequirement: evidenceRequirement,
      comparisonIdentityId: comparisonIdentityId,
      label: label,
    );
  }

  PlanPackageEvidenceRequirement? _parseEvidence(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _evidenceKeys, issues);

    final id = _requireIdentity(map, 'id', path, issues);
    final comparisonIdentityId = _requireIdentity(
      map,
      'comparison_identity_id',
      path,
      issues,
    );
    final metric = _requireNonEmptyString(map, 'metric', path, issues);
    final required = _requireBool(map, 'required', path, issues);

    if (id == null ||
        comparisonIdentityId == null ||
        metric == null ||
        required == null) {
      return null;
    }

    return PlanPackageEvidenceRequirement(
      id: id,
      comparisonIdentityId: comparisonIdentityId,
      metric: metric,
      required: required,
    );
  }

  PlanPackageComparisonIdentity? _parseComparison(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    _rejectForbiddenKeys(map, path, issues);
    _rejectUnknownKeys(map, path, _comparisonKeys, issues);

    final id = _requireIdentity(map, 'id', path, issues);
    final sessionLineageId = _requireIdentity(
      map,
      'session_lineage_id',
      path,
      issues,
    );
    final label = _requireNonEmptyString(map, 'label', path, issues);

    if (id == null || sessionLineageId == null || label == null) return null;

    return PlanPackageComparisonIdentity(
      id: id,
      sessionLineageId: sessionLineageId,
      label: label,
    );
  }

  // --- helpers ---

  static const _rootKeys = {
    'package_schema_version',
    'programme',
    'sessions',
    'phases',
    'weeks',
    'adaptation_permissions',
    'protected_invariants',
    'assessments',
    'performance_evidence_requirements',
    'comparison_identities',
  };

  static const _programmeKeys = {
    'lineage_code',
    'version_number',
    'name',
    'description',
    'library_scope',
    'owner_type',
    'coaching_intent',
    'duration_weeks',
    'sessions_per_week',
    'primary_goal',
  };

  static const _sessionKeys = {
    'session_key',
    'protocol_id',
    'session_lineage_id',
    'revision_number',
    'title',
  };

  static const _phaseKeys = {
    'phase_key',
    'phase_order',
    'title',
    'intent',
    'coach_note',
  };

  static const _weekKeys = {
    'week_number',
    'phase_key',
    'title',
    'intent',
    'coach_note',
    'days',
  };

  static const _dayKeys = {
    'day_key',
    'day_order',
    'day_type',
    'title',
    'intent',
    'coach_note',
    'slots',
  };

  static const _slotKeys = {
    'slot_key',
    'session_order',
    'session_key',
    'progression',
    'time_of_day',
    'is_optional',
    'completion_expectation',
    'display_title',
    'coach_note',
  };

  static const _progressionKeys = {
    'prescription_summary',
    'volume_note',
    'intensity_note',
    'coach_note',
  };

  static const _adaptationKeys = {
    'id',
    'change_kind',
    'target_ref',
    'athlete_agreement_required',
    'scope_note',
  };

  static const _invariantKeys = {'id', 'kind', 'target_ref', 'description'};

  static const _assessmentKeys = {
    'id',
    'slot_ref',
    'evidence_requirement',
    'comparison_identity_id',
    'label',
  };

  static const _evidenceKeys = {
    'id',
    'comparison_identity_id',
    'metric',
    'required',
  };

  static const _comparisonKeys = {'id', 'session_lineage_id', 'label'};

  void _rejectForbiddenKeys(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    for (final key in map.keys) {
      if (PlanPackageSchema.forbiddenAuthoredTruthKeys.contains(key)) {
        issues.add(
          PlanPackageValidationIssue(
            path: path == r'$' ? key : '$path.$key',
            code: 'execution_evidence_forbidden',
            message:
                'Field "$key" is athlete execution / previous-performance '
                'evidence and must not appear in authored programme truth.',
          ),
        );
      }
    }
  }

  void _rejectUnknownKeys(
    Map<String, Object?> map,
    String path,
    Set<String> allowed,
    List<PlanPackageValidationIssue> issues,
  ) {
    for (final key in map.keys) {
      if (PlanPackageSchema.forbiddenAuthoredTruthKeys.contains(key)) {
        continue;
      }
      if (!allowed.contains(key)) {
        issues.add(
          PlanPackageValidationIssue(
            path: path == r'$' ? key : '$path.$key',
            code: 'unknown_field',
            message:
                'Unknown field "$key". Misspelled or unsupported coaching '
                'instructions are rejected.',
          ),
        );
      }
    }
  }

  Map<String, Object?>? _stringKeyMap(
    YamlMap yamlMap,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final result = <String, Object?>{};
    for (final entry in yamlMap.nodes.entries) {
      final keyNode = entry.key;
      if (keyNode is! YamlScalar || keyNode.value is! String) {
        issues.add(
          PlanPackageValidationIssue(
            path: path,
            code: 'non_string_key',
            message: 'Mapping keys must be strings.',
          ),
        );
        continue;
      }
      result[keyNode.value as String] = _yamlValue(entry.value);
    }
    return result;
  }

  Object? _yamlValue(YamlNode node) {
    if (node is YamlScalar) return node.value;
    if (node is YamlMap) {
      final map = <String, Object?>{};
      for (final entry in node.nodes.entries) {
        final key = entry.key;
        if (key is YamlScalar && key.value is String) {
          map[key.value as String] = _yamlValue(entry.value);
        }
      }
      return map;
    }
    if (node is YamlList) {
      return node.nodes.map(_yamlValue).toList(growable: false);
    }
    return null;
  }

  Map<String, Object?>? _asMap(
    Object? value,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v as Object?));
    }
    issues.add(
      PlanPackageValidationIssue(
        path: path,
        code: 'type_error',
        message: 'Expected a mapping.',
      ),
    );
    return null;
  }

  Map<String, Object?>? _requireMap(
    Map<String, Object?> parent,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (!parent.containsKey(key) || parent[key] == null) {
      issues.add(
        PlanPackageValidationIssue(
          path: path,
          code: 'missing_field',
          message: 'Missing required field "$key".',
        ),
      );
      return null;
    }
    return _asMap(parent[key], path, issues);
  }

  List<Object?>? _requireList(
    Map<String, Object?> parent,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (!parent.containsKey(key) || parent[key] == null) {
      issues.add(
        PlanPackageValidationIssue(
          path: path,
          code: 'missing_field',
          message: 'Missing required field "$key".',
        ),
      );
      return null;
    }
    final value = parent[key];
    if (value is! List) {
      issues.add(
        PlanPackageValidationIssue(
          path: path,
          code: 'type_error',
          message: 'Field "$key" must be a list.',
        ),
      );
      return null;
    }
    return value.cast<Object?>();
  }

  List<Object?>? _optionalList(
    Map<String, Object?> parent,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (!parent.containsKey(key) || parent[key] == null) return null;
    final value = parent[key];
    if (value is! List) {
      issues.add(
        PlanPackageValidationIssue(
          path: path,
          code: 'type_error',
          message: 'Field "$key" must be a list when present.',
        ),
      );
      return null;
    }
    return value.cast<Object?>();
  }

  int? _requireInt(
    Map<String, Object?> map,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (!map.containsKey(key) || map[key] == null) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key'.replaceFirst(r'$.', ''),
          code: 'missing_field',
          message: 'Missing required field "$key".',
        ),
      );
      return null;
    }
    final value = map[key];
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    issues.add(
      PlanPackageValidationIssue(
        path: path == r'$' ? key : '$path.$key',
        code: 'type_error',
        message: 'Field "$key" must be an integer.',
      ),
    );
    return null;
  }

  int? _requirePositiveInt(
    Map<String, Object?> map,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final value = _requireInt(map, key, path, issues);
    if (value != null && value < 1) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'invalid_value',
          message: 'Field "$key" must be >= 1.',
        ),
      );
      return null;
    }
    return value;
  }

  int? _optionalPositiveInt(
    Map<String, Object?> map,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (!map.containsKey(key) || map[key] == null) return null;
    final value = map[key];
    if (value is! int && !(value is num && value == value.roundToDouble())) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'type_error',
          message: 'Field "$key" must be an integer.',
        ),
      );
      return null;
    }
    final intValue = value is int ? value : (value as num).toInt();
    if (intValue < 1) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'invalid_value',
          message: 'Field "$key" must be >= 1.',
        ),
      );
      return null;
    }
    return intValue;
  }

  String? _requireNonEmptyString(
    Map<String, Object?> map,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (!map.containsKey(key) || map[key] == null) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'missing_field',
          message: 'Missing required field "$key".',
        ),
      );
      return null;
    }
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'type_error',
          message: 'Field "$key" must be a non-empty string.',
        ),
      );
      return null;
    }
    return value.trim();
  }

  String? _optionalString(
    Map<String, Object?> map,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (!map.containsKey(key) || map[key] == null) return null;
    final value = map[key];
    if (value is! String) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'type_error',
          message: 'Field "$key" must be a string when present.',
        ),
      );
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _requireIdentity(
    Map<String, Object?> map,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues, {
    RegExp? pattern,
  }) {
    final value = _requireNonEmptyString(map, key, path, issues);
    if (value == null) return null;
    final re = pattern ?? PlanPackageSchema.identityPattern;
    if (!re.hasMatch(value)) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'invalid_identifier',
          message: 'Field "$key" is not a valid identity ("$value").',
        ),
      );
      return null;
    }
    return value;
  }

  String? _optionalIdentity(
    Map<String, Object?> map,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final value = _optionalString(map, key, path, issues);
    if (value == null) return null;
    if (!PlanPackageSchema.identityPattern.hasMatch(value)) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'invalid_identifier',
          message: 'Field "$key" is not a valid identity ("$value").',
        ),
      );
      return null;
    }
    return value;
  }

  bool? _requireBool(
    Map<String, Object?> map,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (!map.containsKey(key) || map[key] == null) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'missing_field',
          message: 'Missing required field "$key".',
        ),
      );
      return null;
    }
    final value = map[key];
    if (value is! bool) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'type_error',
          message: 'Field "$key" must be a boolean.',
        ),
      );
      return null;
    }
    return value;
  }

  bool? _optionalBool(
    Map<String, Object?> map,
    String key,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    if (!map.containsKey(key) || map[key] == null) return null;
    final value = map[key];
    if (value is! bool) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.$key',
          code: 'type_error',
          message: 'Field "$key" must be a boolean when present.',
        ),
      );
      return null;
    }
    return value;
  }

  ProgrammeLibraryScope? _requireLibraryScope(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final raw = _requireNonEmptyString(map, 'library_scope', path, issues);
    if (raw == null) return null;
    final scope = ProgrammeLibraryScopeDb.fromDb(raw);
    // fromDb defaults to coachPrivate — distinguish invalid explicitly.
    final valid = {
      'cohort_global',
      'coach_private',
      'organisation',
    }.contains(raw);
    if (!valid) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.library_scope',
          code: 'invalid_enum',
          message: 'Invalid library_scope "$raw".',
        ),
      );
      return null;
    }
    return scope;
  }

  ProgrammeOwnerType? _requireOwnerType(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final raw = _requireNonEmptyString(map, 'owner_type', path, issues);
    if (raw == null) return null;
    final valid = {'global', 'coach', 'organisation'}.contains(raw);
    if (!valid) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.owner_type',
          code: 'invalid_enum',
          message: 'Invalid owner_type "$raw".',
        ),
      );
      return null;
    }
    return ProgrammeOwnerTypeDb.fromDb(raw);
  }

  ProgrammeDayType? _requireDayType(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final raw = _requireNonEmptyString(map, 'day_type', path, issues);
    if (raw == null) return null;
    final type = ProgrammeDayTypeDb.fromDb(raw);
    final valid = {'training', 'rest', 'optional'}.contains(raw);
    if (!valid) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.day_type',
          code: 'invalid_enum',
          message: 'Invalid day_type "$raw".',
        ),
      );
      return null;
    }
    return type;
  }

  ProgrammeIntent? _optionalIntent(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final raw = _optionalString(map, 'intent', path, issues);
    if (raw == null) return null;
    final intent = ProgrammeIntentDb.fromDb(raw);
    if (intent == null) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.intent',
          code: 'invalid_enum',
          message: 'Invalid intent "$raw".',
        ),
      );
    }
    return intent;
  }

  ProgrammeSessionTimeOfDay? _optionalTimeOfDay(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final raw = _optionalString(map, 'time_of_day', path, issues);
    if (raw == null) return null;
    final valid = {'morning', 'afternoon', 'evening', 'any'}.contains(raw);
    if (!valid) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.time_of_day',
          code: 'invalid_enum',
          message: 'Invalid time_of_day "$raw".',
        ),
      );
      return null;
    }
    return ProgrammeSessionTimeOfDayDb.fromDb(raw);
  }

  ProgrammeSessionCompletionExpectation? _optionalCompletionExpectation(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final raw = _optionalString(map, 'completion_expectation', path, issues);
    if (raw == null) return null;
    final valid = {'required', 'optional', 'recommended'}.contains(raw);
    if (!valid) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.completion_expectation',
          code: 'invalid_enum',
          message: 'Invalid completion_expectation "$raw".',
        ),
      );
      return null;
    }
    return ProgrammeSessionCompletionExpectationDb.fromDb(raw);
  }

  AdaptationChangeKind? _requireAdaptationKind(
    Map<String, Object?> map,
    String path,
    List<PlanPackageValidationIssue> issues,
  ) {
    final raw = _requireNonEmptyString(map, 'change_kind', path, issues);
    if (raw == null) return null;
    final kind = PlanPackageSchema.adaptationKindFromYaml(raw);
    if (kind == null) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.change_kind',
          code: 'invalid_enum',
          message: 'Invalid adaptation change_kind "$raw".',
        ),
      );
      return null;
    }
    if (!PlanPackageSchema.permittedAdaptationKinds.contains(kind)) {
      issues.add(
        PlanPackageValidationIssue(
          path: '$path.change_kind',
          code: 'prohibited_adaptation',
          message:
              'Adaptation change_kind "$raw" is not an authored permitted '
              'adaptation (AdaptationPolicyGate).',
        ),
      );
      return null;
    }
    return kind;
  }
}

class PlanPackageParseOutcome {
  const PlanPackageParseOutcome._({this.manifest, required this.issues});

  factory PlanPackageParseOutcome.ok(PlanPackageManifest manifest) {
    return PlanPackageParseOutcome._(manifest: manifest, issues: const []);
  }

  factory PlanPackageParseOutcome.failed(
    List<PlanPackageValidationIssue> issues,
  ) {
    return PlanPackageParseOutcome._(issues: List.unmodifiable(issues));
  }

  final PlanPackageManifest? manifest;
  final List<PlanPackageValidationIssue> issues;

  bool get isValid => manifest != null && issues.isEmpty;
}
