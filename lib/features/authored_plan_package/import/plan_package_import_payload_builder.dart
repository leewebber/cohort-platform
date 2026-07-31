import '../plan_package_compiler.dart';
import '../plan_package_manifest.dart';
import '../plan_package_schema.dart';

/// Builds the JSONB import payload from a validated compile result.
///
/// Ownership, lifecycle, publication and catalogue-approval fields are never
/// included — the database enforces Cohort Global draft ownership.
class PlanPackageImportPayloadBuilder {
  const PlanPackageImportPayloadBuilder();

  /// Throws [StateError] if [compileResult] is not valid.
  Map<String, Object?> build({
    required PlanPackageCompileResult compileResult,
    required String importedBy,
  }) {
    if (!compileResult.isValid || compileResult.manifest == null) {
      throw StateError('Import payload requires a successful compile result.');
    }
    final actor = importedBy.trim();
    if (actor.isEmpty) {
      throw ArgumentError.value(importedBy, 'importedBy', 'must be non-empty');
    }

    final manifest = compileResult.manifest!;
    final hash = compileResult.contentHashSha256!;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
      throw StateError('Compile hash is not lowercase SHA-256 hex.');
    }

    return {
      'package_schema_version': manifest.packageSchemaVersion,
      'package_content_hash': hash,
      'imported_by': actor,
      'programme': _programme(manifest.programme),
      'sessions': [for (final s in manifest.sessions) _session(s)],
      'phases': [for (final p in manifest.phases) _phase(p)],
      'weeks': [for (final w in manifest.weeks) _week(w)],
      'adaptation_permissions': [
        for (final a in manifest.adaptationPermissions) _adaptation(a),
      ],
      'protected_invariants': [
        for (final i in manifest.protectedInvariants) _invariant(i),
      ],
      'assessments': [for (final a in manifest.assessments) _assessment(a)],
      'performance_evidence_requirements': [
        for (final e in manifest.performanceEvidenceRequirements) _evidence(e),
      ],
      'comparison_identities': [
        for (final c in manifest.comparisonIdentities) _comparison(c),
      ],
    };
  }

  Map<String, Object?> _programme(PlanPackageProgrammeIdentity p) {
    return {
      'lineage_code': p.lineageCode,
      'version_number': p.versionNumber,
      'name': p.name,
      if (p.description != null) 'description': p.description,
      'coaching_intent': p.coachingIntent,
      if (p.durationWeeks != null) 'duration_weeks': p.durationWeeks,
      if (p.sessionsPerWeek != null) 'sessions_per_week': p.sessionsPerWeek,
      if (p.primaryGoal != null) 'primary_goal': p.primaryGoal,
    };
  }

  Map<String, Object?> _session(PlanPackageSessionRevisionRef s) {
    return {
      'session_key': s.sessionKey,
      'protocol_id': s.protocolId,
      'session_lineage_id': s.sessionLineageId,
      'revision_number': s.revisionNumber,
      'title': s.title,
    };
  }

  Map<String, Object?> _phase(PlanPackagePhase p) {
    return {
      'phase_key': p.phaseKey,
      'phase_order': p.phaseOrder,
      'title': p.title,
      if (p.intent != null) 'intent': p.intent!.name,
      if (p.coachNote != null) 'coach_note': p.coachNote,
    };
  }

  Map<String, Object?> _week(PlanPackageWeek w) {
    return {
      'week_number': w.weekNumber,
      if (w.phaseKey != null) 'phase_key': w.phaseKey,
      if (w.title != null) 'title': w.title,
      if (w.intent != null) 'intent': w.intent!.name,
      if (w.coachNote != null) 'coach_note': w.coachNote,
      'days': [for (final d in w.days) _day(d)],
    };
  }

  Map<String, Object?> _day(PlanPackageDay d) {
    return {
      'day_key': d.dayKey,
      'day_order': d.dayOrder,
      'day_type': d.dayType.name,
      if (d.title != null) 'title': d.title,
      if (d.intent != null) 'intent': d.intent!.name,
      if (d.coachNote != null) 'coach_note': d.coachNote,
      'slots': [for (final s in d.slots) _slot(s)],
    };
  }

  Map<String, Object?> _slot(PlanPackageSessionSlot s) {
    return {
      'slot_key': s.slotKey,
      'session_order': s.sessionOrder,
      'session_key': s.sessionKey,
      'time_of_day': s.timeOfDay.name,
      'is_optional': s.isOptional,
      'completion_expectation': s.completionExpectation.name,
      if (s.displayTitle != null) 'display_title': s.displayTitle,
      if (s.coachNote != null) 'coach_note': s.coachNote,
      'progression': {
        'prescription_summary': s.progression.prescriptionSummary,
        if (s.progression.volumeNote != null)
          'volume_note': s.progression.volumeNote,
        if (s.progression.intensityNote != null)
          'intensity_note': s.progression.intensityNote,
        if (s.progression.coachNote != null)
          'coach_note': s.progression.coachNote,
      },
    };
  }

  Map<String, Object?> _adaptation(PlanPackageAdaptationPermission a) {
    return {
      'id': a.id,
      'change_kind': PlanPackageSchema.adaptationKindYamlValue(a.changeKind),
      'target_ref': a.targetRef,
      'athlete_agreement_required': a.athleteAgreementRequired,
      if (a.scopeNote != null) 'scope_note': a.scopeNote,
    };
  }

  Map<String, Object?> _invariant(PlanPackageProtectedInvariant i) {
    return {
      'id': i.id,
      'kind': i.kind.yamlValue,
      'target_ref': i.targetRef,
      'description': i.description,
    };
  }

  Map<String, Object?> _assessment(PlanPackageAssessment a) {
    return {
      'id': a.id,
      'slot_ref': a.slotRef,
      'evidence_requirement': a.evidenceRequirement,
      'comparison_identity_id': a.comparisonIdentityId,
      if (a.label != null) 'label': a.label,
    };
  }

  Map<String, Object?> _evidence(PlanPackageEvidenceRequirement e) {
    return {
      'id': e.id,
      'comparison_identity_id': e.comparisonIdentityId,
      'metric': e.metric,
      'required': e.required,
    };
  }

  Map<String, Object?> _comparison(PlanPackageComparisonIdentity c) {
    return {
      'id': c.id,
      'session_lineage_id': c.sessionLineageId,
      'label': c.label,
    };
  }
}
