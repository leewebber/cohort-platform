import 'dart:convert';
import 'dart:typed_data';

import '../../models/programme_vocabulary.dart';
import 'plan_package_manifest.dart';
import 'plan_package_schema.dart';

/// Deterministic canonical representation of a validated Plan Package.
///
/// # Canonicalisation contract (package schema v1)
///
/// 1. Input is a validated [PlanPackageManifest] only — never raw YAML.
/// 2. Optional / default values are normalised:
///    - omitted optional strings are absent (not `null` in output)
///    - default `time_of_day` = `any` is always written explicitly
///    - default `is_optional` = `false` is always written explicitly
///    - default `completion_expectation` = `required` is always written
/// 3. Semantically ordered collections keep authored order after sorting by
///    their order keys (`phase_order`, `week_number`, `day_order`,
///    `session_order`).
/// 4. Unordered maps / identity catalogues are sorted by their stable id key.
/// 5. Encoding is UTF-8 JSON with sorted object keys, no insignificant
///    whitespace (`json.encode` default for maps built in key order).
/// 6. Excluded from canonical output:
///    - YAML comments / whitespace / key order / line endings
///    - local file paths, import timestamps, builder localIds
///    - athlete execution / previous-performance evidence
/// 7. Equivalent programme meaning ⇒ identical bytes ⇒ identical SHA-256.
class PlanPackageCanonicaliser {
  const PlanPackageCanonicaliser();

  /// Returns canonical UTF-8 bytes for [manifest].
  Uint8List canonicalBytes(PlanPackageManifest manifest) {
    final tree = _normalise(manifest);
    final json = jsonEncode(tree);
    return Uint8List.fromList(utf8.encode(json));
  }

  /// UTF-8 string form of the canonical representation (debugging / tests).
  String canonicalJson(PlanPackageManifest manifest) {
    return utf8.decode(canonicalBytes(manifest));
  }

  Map<String, Object?> _normalise(PlanPackageManifest manifest) {
    return _sortedMap({
      'package_schema_version': manifest.packageSchemaVersion,
      'programme': _programme(manifest.programme),
      'sessions': _sortedBy(manifest.sessions, (s) => s.sessionKey, _session),
      'phases': _orderedBy(manifest.phases, (p) => p.phaseOrder, _phase),
      'weeks': _orderedBy(manifest.weeks, (w) => w.weekNumber, _week),
      'adaptation_permissions': _sortedBy(
        manifest.adaptationPermissions,
        (a) => a.id,
        _adaptation,
      ),
      'protected_invariants': _sortedBy(
        manifest.protectedInvariants,
        (i) => i.id,
        _invariant,
      ),
      'assessments': _sortedBy(manifest.assessments, (a) => a.id, _assessment),
      'performance_evidence_requirements': _sortedBy(
        manifest.performanceEvidenceRequirements,
        (e) => e.id,
        _evidence,
      ),
      'comparison_identities': _sortedBy(
        manifest.comparisonIdentities,
        (c) => c.id,
        _comparison,
      ),
    });
  }

  Map<String, Object?> _programme(PlanPackageProgrammeIdentity p) {
    return _sortedMap({
      'lineage_code': p.lineageCode,
      'version_number': p.versionNumber,
      'name': p.name,
      if (p.description != null) 'description': p.description,
      'library_scope': p.libraryScope.dbValue,
      'owner_type': p.ownerType.dbValue,
      'coaching_intent': p.coachingIntent,
      if (p.durationWeeks != null) 'duration_weeks': p.durationWeeks,
      if (p.sessionsPerWeek != null) 'sessions_per_week': p.sessionsPerWeek,
      if (p.primaryGoal != null) 'primary_goal': p.primaryGoal,
    });
  }

  Map<String, Object?> _session(PlanPackageSessionRevisionRef s) {
    return _sortedMap({
      'session_key': s.sessionKey,
      'protocol_id': s.protocolId,
      'session_lineage_id': s.sessionLineageId,
      'revision_number': s.revisionNumber,
      'title': s.title,
    });
  }

  Map<String, Object?> _phase(PlanPackagePhase p) {
    return _sortedMap({
      'phase_key': p.phaseKey,
      'phase_order': p.phaseOrder,
      'title': p.title,
      if (p.intent != null) 'intent': p.intent!.dbValue,
      if (p.coachNote != null) 'coach_note': p.coachNote,
    });
  }

  Map<String, Object?> _week(PlanPackageWeek w) {
    return _sortedMap({
      'week_number': w.weekNumber,
      if (w.phaseKey != null) 'phase_key': w.phaseKey,
      if (w.title != null) 'title': w.title,
      if (w.intent != null) 'intent': w.intent!.dbValue,
      if (w.coachNote != null) 'coach_note': w.coachNote,
      'days': _orderedBy(w.days, (d) => d.dayOrder, _day),
    });
  }

  Map<String, Object?> _day(PlanPackageDay d) {
    return _sortedMap({
      'day_key': d.dayKey,
      'day_order': d.dayOrder,
      'day_type': d.dayType.dbValue,
      if (d.title != null) 'title': d.title,
      if (d.intent != null) 'intent': d.intent!.dbValue,
      if (d.coachNote != null) 'coach_note': d.coachNote,
      'slots': _orderedBy(d.slots, (s) => s.sessionOrder, _slot),
    });
  }

  Map<String, Object?> _slot(PlanPackageSessionSlot s) {
    return _sortedMap({
      'slot_key': s.slotKey,
      'session_order': s.sessionOrder,
      'session_key': s.sessionKey,
      'time_of_day': s.timeOfDay.dbValue,
      'is_optional': s.isOptional,
      'completion_expectation': s.completionExpectation.dbValue,
      if (s.displayTitle != null) 'display_title': s.displayTitle,
      if (s.coachNote != null) 'coach_note': s.coachNote,
      'progression': _progression(s.progression),
    });
  }

  Map<String, Object?> _progression(PlanPackageAuthoredProgression p) {
    return _sortedMap({
      'prescription_summary': p.prescriptionSummary,
      if (p.volumeNote != null) 'volume_note': p.volumeNote,
      if (p.intensityNote != null) 'intensity_note': p.intensityNote,
      if (p.coachNote != null) 'coach_note': p.coachNote,
    });
  }

  Map<String, Object?> _adaptation(PlanPackageAdaptationPermission a) {
    return _sortedMap({
      'id': a.id,
      'change_kind': PlanPackageSchema.adaptationKindYamlValue(a.changeKind),
      'target_ref': a.targetRef,
      'athlete_agreement_required': a.athleteAgreementRequired,
      if (a.scopeNote != null) 'scope_note': a.scopeNote,
    });
  }

  Map<String, Object?> _invariant(PlanPackageProtectedInvariant i) {
    return _sortedMap({
      'id': i.id,
      'kind': i.kind.yamlValue,
      'target_ref': i.targetRef,
      'description': i.description,
    });
  }

  Map<String, Object?> _assessment(PlanPackageAssessment a) {
    return _sortedMap({
      'id': a.id,
      'slot_ref': a.slotRef,
      'evidence_requirement': a.evidenceRequirement,
      'comparison_identity_id': a.comparisonIdentityId,
      if (a.label != null) 'label': a.label,
    });
  }

  Map<String, Object?> _evidence(PlanPackageEvidenceRequirement e) {
    return _sortedMap({
      'id': e.id,
      'comparison_identity_id': e.comparisonIdentityId,
      'metric': e.metric,
      'required': e.required,
    });
  }

  Map<String, Object?> _comparison(PlanPackageComparisonIdentity c) {
    return _sortedMap({
      'id': c.id,
      'session_lineage_id': c.sessionLineageId,
      'label': c.label,
    });
  }

  Map<String, Object?> _sortedMap(Map<String, Object?> input) {
    final keys = input.keys.toList()..sort();
    return {for (final key in keys) key: input[key]};
  }

  List<Map<String, Object?>> _sortedBy<T>(
    List<T> items,
    String Function(T) keyOf,
    Map<String, Object?> Function(T) encode,
  ) {
    final copy = [...items]..sort((a, b) => keyOf(a).compareTo(keyOf(b)));
    return [for (final item in copy) encode(item)];
  }

  List<Map<String, Object?>> _orderedBy<T>(
    List<T> items,
    int Function(T) orderOf,
    Map<String, Object?> Function(T) encode,
  ) {
    final copy = [...items]..sort((a, b) => orderOf(a).compareTo(orderOf(b)));
    return [for (final item in copy) encode(item)];
  }
}
