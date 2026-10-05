part of 'performance_tracking.dart';

class TrackingValidationIssue {
  const TrackingValidationIssue(this.path, this.code);
  final String path;
  final String code;
  @override
  String toString() => '$path: $code';
}

/// Pure validation over a caller-supplied immutable dependency closure.
/// Success establishes structural consistency, not authenticity, hosted
/// existence, evidence eligibility, historical replay or publication approval.
class TrackingValidator {
  TrackingValidator({Set<String> knownTimezoneIds = const {}})
    : knownTimezoneIds = Set.unmodifiable(knownTimezoneIds);

  final Set<String> knownTimezoneIds;

  List<TrackingValidationIssue> validate(List<TrackingArtifact> artifacts) {
    final issues = <TrackingValidationIssue>[];
    final index = <String, TrackingArtifact>{};
    final ambiguous = <String>{};
    for (final a in artifacts) {
      final path = '${a.artifactKind}/${a.id}/${a.version}';
      if (!_text(a.id) || a.version < 1) {
        issues.add(TrackingValidationIssue(path, 'invalid_identity'));
      }
      if (index.containsKey(_key(a.artifactKind, a.id, a.version))) {
        ambiguous.add(_key(a.artifactKind, a.id, a.version));
        issues.add(TrackingValidationIssue(path, 'duplicate_identity'));
      } else {
        index[_key(a.artifactKind, a.id, a.version)] = a;
      }
    }
    final context = _TrackingValidationContext(
      index,
      ambiguous,
      issues,
      knownTimezoneIds,
    );
    final sourceOwners = <String, Set<String>>{};
    final profileAuthorities = <String, Set<String>>{};
    final historyParents = <String, Set<String>>{};
    final auditParents = <String, Set<String>>{};
    void declare(Map<String, Set<String>> map, String key, String value) {
      map.putIfAbsent(key, () => <String>{}).add(value);
    }

    String measurementIdentity(TrackingMeasurementRevision a) => jsonEncode([
      a.athleteId,
      a.metric.id,
      a.metric.version,
      context.sourceIdentity(a.source),
    ]);
    for (final a in artifacts) {
      if (a is TrackingProfile) {
        declare(
          profileAuthorities,
          a.id,
          jsonEncode([a.kind.name, a.athleteId]),
        );
      }
      if (a is TrackingMeasurementRevision) {
        declare(sourceOwners, measurementIdentity(a), a.id);
        for (final entry in context.historyParents(a).entries) {
          declare(historyParents, entry.key, entry.value);
        }
        final h = a.source.history;
        if (h?.correctionId != null) {
          declare(
            auditParents,
            h!.correctionId!,
            jsonEncode([a.athleteId, h.recordId]),
          );
        }
      }
    }
    for (final a in artifacts) {
      context.path = '${a.artifactKind}/${a.id}/${a.version}';
      switch (a) {
        case TrackingMethodDefinition():
          context.method(a);
        case TrackingMetricDefinition():
          context.metric(a);
        case TrackingProfile():
          context.profile(a);
          if (profileAuthorities[a.id]!.length > 1) {
            context.issue('profile_authority_changed');
          }
        case TrackingSelectionRevision():
          context.selection(a);
        case TrackingAssessmentDefinition():
          context.assessment(a);
        case TrackingProgrammeBinding():
          context.binding(a);
        case TrackingMeasurementRevision():
          context.measurement(a);
          if (sourceOwners[measurementIdentity(a)]!.length > 1) {
            context.issue('duplicate_source_measurement');
          }
          if (context
              .historyParents(a)
              .keys
              .any((key) => historyParents[key]!.length > 1)) {
            context.issue('history_parent_reference_conflict');
          }
          final audit = a.source.history?.correctionId;
          if (audit != null && auditParents[audit]!.length > 1) {
            context.issue('history_audit_reference_conflict');
          }
      }
    }
    // Deterministic diagnostics regardless of registry enumeration order.
    issues.sort(
      (a, b) => '${a.path}|${a.code}'.compareTo('${b.path}|${b.code}'),
    );
    return List.unmodifiable(issues);
  }

  static String _key(String kind, String id, int version) =>
      jsonEncode([kind, id, version]);
  static bool _text(String? value) =>
      value != null && value.isNotEmpty && value.trim() == value;
}

class _TrackingValidationContext {
  _TrackingValidationContext(
    this.index,
    this.ambiguous,
    this.issues,
    this.zones,
  );
  final Map<String, TrackingArtifact> index;
  final Set<String> ambiguous;
  final List<TrackingValidationIssue> issues;
  final Set<String> zones;
  String path = '';

  void issue(String code) => issues.add(TrackingValidationIssue(path, code));
  bool text(String? value) => TrackingValidator._text(value);
  bool hash(String? value) =>
      value != null && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
  bool token(String value) =>
      RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value);
  bool same(TrackingReference a, TrackingReference b) =>
      a.id == b.id && a.version == b.version && a.digest == b.digest;

  TrackingArtifact? resolve(TrackingReference ref, String kind) {
    if (!text(ref.id) || ref.version < 1 || !hash(ref.digest)) {
      issue('invalid_reference');
      return null;
    }
    final key = TrackingValidator._key(kind, ref.id, ref.version);
    if (ambiguous.contains(key)) {
      issue('ambiguous_$kind');
      return null;
    }
    final artifact = index[key];
    if (artifact == null) {
      issue('unresolved_$kind');
      return null;
    }
    if (artifact.digest != ref.digest) {
      issue('reference_digest_mismatch');
      return null;
    }
    return artifact;
  }

  void metricRefs(List<TrackingReference> refs) {
    if (refs.isEmpty) {
      issue('metrics_required');
    }
    final ids = <String>{};
    for (final ref in refs) {
      if (!ids.add(ref.id)) {
        issue('duplicate_metric');
      }
      resolve(ref, 'metric');
    }
  }

  void method(TrackingMethodDefinition a) {
    final count = a.kind == TrackingMethodKind.fieldExtraction ? 1 : 2;
    if (a.inputUnits.length != count ||
        a.inputUnits.any((unit) => unit != a.outputUnit)) {
      issue('method_unit_signature_mismatch');
    }
  }

  void metric(TrackingMetricDefinition a) {
    if (!text(a.label) || !token(a.captureField)) {
      issue('invalid_metric_metadata');
    }
    final m = resolve(a.method, 'method');
    if (m is TrackingMethodDefinition && m.outputUnit != a.unit) {
      issue('metric_method_unit_mismatch');
    }
    if (a.allowedSources.toSet().length != a.allowedSources.length ||
        a.requiredContext.toSet().length != a.requiredContext.length) {
      issue('duplicate_metric_policy');
    }
    if (a.requiredContext.any((key) => !token(key))) {
      issue('invalid_context_key');
    }
    if (a.freshnessCivilDays != null && a.freshnessCivilDays! < 0) {
      issue('invalid_freshness');
    }
    if (m is TrackingMethodDefinition) {
      if (m.kind == TrackingMethodKind.fieldExtraction &&
          a.allowedSources.isEmpty) {
        issue('source_policy_required');
      }
      if (m.kind == TrackingMethodKind.difference &&
          a.allowedSources.isNotEmpty) {
        issue('derived_metric_cannot_capture_results');
      }
    }
  }

  void profile(TrackingProfile a) {
    if (!text(a.name)) {
      issue('profile_name_required');
    }
    metricRefs(a.metrics);
    if (a.kind == TrackingProfileKind.curated) {
      if (a.athleteId != null || a.previous != null) {
        issue('curated_profile_has_athlete_state');
      }
    } else {
      if (!text(a.athleteId)) {
        issue('athlete_required');
      }
      final previous = predecessor(a, a.previous, 'profile');
      if (previous is TrackingProfile &&
          (previous.kind != a.kind || previous.athleteId != a.athleteId)) {
        issue('custom_profile_lineage_mismatch');
      }
    }
  }

  TrackingArtifact? predecessor(
    TrackingArtifact a,
    TrackingReference? ref,
    String kind,
  ) {
    if (a.version == 1) {
      if (ref != null) {
        issue('first_revision_has_predecessor');
      }
      return null;
    }
    if (ref == null) {
      issue('previous_revision_required');
      return null;
    }
    if (ref.id != a.id || ref.version != a.version - 1) {
      issue('revision_lineage_mismatch');
      return null;
    }
    return resolve(ref, kind);
  }

  void selection(TrackingSelectionRevision a) {
    if (!text(a.athleteId)) {
      issue('athlete_required');
    }
    utc(a.recordedAt);
    final p = resolve(a.profile, 'profile');
    if (p is TrackingProfile &&
        p.kind == TrackingProfileKind.custom &&
        p.athleteId != a.athleteId) {
      issue('selection_profile_owner_mismatch');
    }
    if (a.programmeBinding != null) {
      final b = resolve(a.programmeBinding!, 'programme_binding');
      if (b is TrackingProgrammeBinding && !same(b.profile, a.profile)) {
        issue('selection_binding_profile_mismatch');
      }
    }
    final previous = predecessor(a, a.previous, 'selection');
    if (a.version == 1 && a.action != TrackingSelectionAction.select) {
      issue('initial_selection_action_mismatch');
    }
    if (previous is TrackingSelectionRevision) {
      if (previous.athleteId != a.athleteId) {
        issue('selection_owner_mismatch');
      }
      if (a.recordedAt.isBefore(previous.recordedAt)) {
        issue('revision_time_reversed');
      }
      final changed = !same(previous.profile, a.profile);
      final sameProfile = previous.profile.id == a.profile.id;
      if (changed && sameProfile) {
        if (a.action != TrackingSelectionAction.upgrade ||
            a.profile.version <= previous.profile.version) {
          issue('explicit_upgrade_required');
        }
      } else if (changed) {
        if (a.action != TrackingSelectionAction.select) {
          issue('explicit_selection_required');
        }
      } else if (a.action == TrackingSelectionAction.upgrade) {
        issue('upgrade_requires_new_profile_version');
      }
      if (a.action == TrackingSelectionAction.deselect && changed) {
        issue('deselect_profile_changed');
      }
      if (previous.action == TrackingSelectionAction.deselect &&
          a.action != TrackingSelectionAction.select) {
        issue('explicit_reselection_required');
      }
    }
  }

  void assessment(TrackingAssessmentDefinition a) {
    if (!hash(a.procedureDigest)) {
      issue('invalid_procedure_digest');
    }
    metricRefs(a.metrics);
  }

  void scope(TrackingProgrammeScope s) {
    if (![
          s.programmeVersionId,
          s.slotKey,
          s.protocolId,
          s.blockId,
        ].every(text) ||
        !hash(s.packageHash) ||
        s.protocolRevision < 1) {
      issue('invalid_programme_scope');
    }
    final hasRunning =
        s.workoutId != null ||
        s.stepId != null ||
        s.repeatOrdinal != null ||
        s.mappingHash != null;
    if (hasRunning &&
        (!text(s.workoutId) ||
            !text(s.stepId) ||
            !hash(s.mappingHash) ||
            s.repeatOrdinal == null ||
            s.repeatOrdinal! < 1)) {
      issue('incomplete_running_scope');
    }
  }

  void binding(TrackingProgrammeBinding a) {
    if (!text(a.programmeVersionId) || !hash(a.packageHash)) {
      issue('invalid_programme_binding');
    }
    final p = resolve(a.profile, 'profile');
    if (p is TrackingProfile && p.kind != TrackingProfileKind.curated) {
      issue('programme_binding_requires_authored_profile');
    }
    final identities = <String>{};
    for (final item in a.assessmentScopes) {
      final test = resolve(item.assessment, 'assessment');
      scope(item.scope);
      if (!text(item.window) ||
          item.scope.programmeVersionId != a.programmeVersionId ||
          item.scope.packageHash != a.packageHash) {
        issue('binding_scope_mismatch');
      }
      final key = jsonEncode(item.scope.toJson());
      if (!identities.add(key)) {
        issue('duplicate_assessment_scope');
      }
      if (test is TrackingAssessmentDefinition &&
          p is TrackingProfile &&
          test.metrics.any((m) => !p.metrics.any((ref) => same(m, ref)))) {
        issue('assessment_profile_metric_mismatch');
      }
    }
  }

  void utc(DateTime time) {
    if (!time.isUtc) {
      issue('utc_timestamp_required');
    }
  }

  void chronology(TrackingChronology c) {
    utc(c.recordedAt);
    if (c.timezone != null && !zones.contains(c.timezone)) {
      issue('unknown_timezone');
    }
    switch (c.precision) {
      case TrackingTimePrecision.timestamp:
        if (c.performedAt == null || c.performedOn != null) {
          issue('timestamp_chronology_mismatch');
        } else {
          utc(c.performedAt!);
          if (c.performedAt!.isAfter(c.recordedAt)) {
            issue('performance_after_entry');
          }
        }
      case TrackingTimePrecision.civilDate:
        final date = c.performedOn;
        final parsed = date == null
            ? null
            : DateTime.tryParse('${date}T00:00:00Z');
        if (date == null ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
            parsed == null ||
            parsed.toIso8601String().substring(0, 10) != date ||
            c.performedAt != null ||
            c.timezone == null) {
          issue('civil_date_chronology_mismatch');
        }
      case TrackingTimePrecision.unknown:
        if (c.performedAt != null ||
            c.performedOn != null ||
            c.timezone != null) {
          issue('unknown_chronology_has_event_time');
        }
    }
  }

  void evidence(TrackingEvidence e) {
    if (e.state != TrackingEvidenceState.available && !text(e.reason)) {
      issue('evidence_reason_required');
    }
    final recorded = e.recordedCount;
    final required = e.requiredCount;
    final invalidCoverage =
        (recorded == null) != (required == null) ||
        (recorded != null &&
            required != null &&
            (recorded < 0 || required < 1 || recorded > required));
    if (invalidCoverage) {
      issue('invalid_coverage');
    }
    if (e.state == TrackingEvidenceState.available &&
        e.recordedCount != e.requiredCount) {
      issue('available_evidence_incomplete');
    }
    if (e.state == TrackingEvidenceState.partial &&
        (invalidCoverage ||
            recorded == null ||
            required == null ||
            recorded >= required)) {
      issue('partial_coverage_required');
    }
  }

  void measurement(TrackingMeasurementRevision a) {
    if (!text(a.athleteId) || !text(a.provenance)) {
      issue('measurement_provenance_required');
    }
    chronology(a.chronology);
    evidence(a.evidence);
    if (a.context.entries.any((e) => !token(e.key) || !text(e.value))) {
      issue('invalid_measurement_context');
    }
    final m = resolve(a.metric, 'metric');
    if (m is TrackingMetricDefinition) {
      if (m.unit != a.unit) {
        issue('measurement_unit_mismatch');
      }
      if (!m.allowedSources.contains(a.source.kind)) {
        issue('unsupported_measurement_source');
      }
      if (a.evidence.state == TrackingEvidenceState.available) {
        if (m.requiredContext.any((key) => !a.context.containsKey(key))) {
          issue('required_context_missing');
        }
        if (m.requiresAssessment &&
            a.source.kind != TrackingSourceKind.assessmentAttempt) {
          issue('assessment_proof_required');
        }
        if (m.freshnessCivilDays != null &&
            a.chronology.precision == TrackingTimePrecision.unknown) {
          issue('freshness_chronology_required');
        }
      }
      if (a.evidence.state == TrackingEvidenceState.partial &&
          a.canonicalValue != null &&
          !m.allowPartial) {
        issue('partial_value_not_allowed');
      }
    }
    source(a.source, a.metric);
    final history = a.source.history;
    if (history != null) {
      if (a.canonicalValue != null) {
        issue('history_value_copy_forbidden');
      }
      if (m is TrackingMetricDefinition &&
          (history.fieldPath.isEmpty ||
              history.fieldPath.last != m.captureField)) {
        issue('history_metric_field_mismatch');
      }
    } else {
      if (a.evidence.state == TrackingEvidenceState.available &&
          a.canonicalValue == null) {
        issue('available_value_required');
      }
    }
    final value = a.canonicalValue;
    if (value != null &&
        (!RegExp(r'^-?(0|[1-9][0-9]*)(\.[0-9]*[1-9])?$').hasMatch(value) ||
            value.startsWith('-') ||
            (a.unit == TrackingUnit.count && value.contains('.')))) {
      issue('invalid_canonical_value');
    }
    if ([
          TrackingEvidenceState.missing,
          TrackingEvidenceState.skipped,
          TrackingEvidenceState.unavailable,
        ].contains(a.evidence.state) &&
        value != null) {
      issue('unmeasured_state_has_value');
    }
    final previous = predecessor(a, a.previous, 'measurement');
    if (a.version == 1 && a.correctionReason != null) {
      issue('first_revision_has_correction');
    }
    if (a.version > 1 && !text(a.correctionReason)) {
      issue('correction_reason_required');
    }
    if (previous is TrackingMeasurementRevision) {
      if (previous.athleteId != a.athleteId ||
          !same(previous.metric, a.metric) ||
          previous.unit != a.unit ||
          sourceIdentity(previous.source) != sourceIdentity(a.source) ||
          originIdentity(previous.source) != originIdentity(a.source)) {
        issue('measurement_correction_lineage_mismatch');
      }
      if (a.chronology.recordedAt.isBefore(previous.chronology.recordedAt)) {
        issue('revision_time_reversed');
      }
      if (history != null &&
          (a.chronology.precision != previous.chronology.precision ||
              a.chronology.performedAt != previous.chronology.performedAt ||
              a.chronology.performedOn != previous.chronology.performedOn ||
              a.chronology.timezone != previous.chronology.timezone)) {
        issue('history_event_chronology_changed');
      }
      if (history != null &&
          previous.source.history?.correctionId != null &&
          history.correctionId == null) {
        issue('history_correction_reference_removed');
      }
      if (history != null &&
          history.inputDigest != previous.source.history?.inputDigest &&
          (history.correctionId == null ||
              history.correctionId == previous.source.history?.correctionId)) {
        issue('history_correction_reference_required');
      }
    }
  }

  void source(TrackingMeasurementSource s, TrackingReference metric) {
    if (!text(s.sourceId)) {
      issue('source_identity_required');
    }
    for (final optional in [
      s.attemptId,
      s.assignmentId,
      s.occurrenceId,
      s.trainingSessionId,
    ]) {
      if (optional != null && !text(optional)) {
        issue('invalid_source_reference');
      }
    }
    switch (s.kind) {
      case TrackingSourceKind.manualEntry:
        if (s.history != null ||
            s.attemptId != null ||
            s.assessment != null ||
            s.programmeScope != null ||
            s.assignmentId != null ||
            s.occurrenceId != null ||
            s.trainingSessionId != null) {
          issue('manual_entry_cannot_claim_test_or_programme');
        }
      case TrackingSourceKind.historyResult:
        if (s.history == null) {
          issue('history_reference_required');
        }
        if (s.assessment != null || s.attemptId != null) {
          issue('history_entry_cannot_claim_assessment');
        }
      case TrackingSourceKind.assessmentAttempt:
        if (s.assessment == null || !text(s.attemptId)) {
          issue('assessment_attempt_reference_required');
        }
        if (s.assessment != null) {
          final test = resolve(s.assessment!, 'assessment');
          if (test is TrackingAssessmentDefinition &&
              !test.metrics.any((m) => same(m, metric))) {
            issue('assessment_metric_mismatch');
          }
        }
    }
    if (s.programmeScope == null) {
      if (s.assignmentId != null ||
          s.occurrenceId != null ||
          s.trainingSessionId != null) {
        issue('programme_scope_required');
      }
    } else {
      final p = s.programmeScope!;
      scope(p);
      if (!text(s.assignmentId) ||
          !text(s.occurrenceId) ||
          !text(s.trainingSessionId) ||
          s.history == null) {
        issue('programme_evidence_links_required');
      }
      if (s.history != null &&
          (s.history!.sourceBlockId != p.blockId ||
              s.history!.workoutId != p.workoutId ||
              s.history!.stepId != p.stepId ||
              s.history!.repeatOrdinal != p.repeatOrdinal)) {
        issue('history_programme_scope_mismatch');
      }
    }
    final h = s.history;
    if (h != null) {
      if (![h.recordId, h.blockResultId, h.sourceBlockId].every(text) ||
          !hash(h.inputDigest) ||
          h.fieldPath.isEmpty ||
          h.fieldPath.any((p) => !token(p))) {
        issue('invalid_history_field_reference');
      }
      for (final optional in [
        h.exerciseResultId,
        h.setResultId,
        h.correctionId,
      ]) {
        if (optional != null && !text(optional)) {
          issue('invalid_history_result_reference');
        }
      }
      if (h.setResultId != null && h.exerciseResultId == null) {
        issue('set_requires_exercise_result');
      }
      final running =
          h.workoutId != null || h.stepId != null || h.repeatOrdinal != null;
      if (running && (h.exerciseResultId != null || h.setResultId != null)) {
        issue('ambiguous_history_row_scope');
      }
      if (running &&
          (!text(h.workoutId) ||
              !text(h.stepId) ||
              h.repeatOrdinal == null ||
              h.repeatOrdinal! < 1)) {
        issue('incomplete_history_running_identity');
      }
    }
  }

  // Only consistency among supplied declarations; this does not attest to
  // live row ownership, parentage, audit ordering or historical reconstruction.
  Map<String, String> historyParents(TrackingMeasurementRevision a) {
    final source = a.source;
    final h = source.history;
    if (h == null) return const {};
    final scope = source.programmeScope;
    return {
      jsonEncode(['record', h.recordId]): jsonEncode([a.athleteId]),
      if (source.assignmentId != null)
        jsonEncode(['record_assignment', h.recordId]): jsonEncode([
          source.assignmentId,
        ]),
      if (source.occurrenceId != null)
        jsonEncode(['record_occurrence', h.recordId]): jsonEncode([
          source.occurrenceId,
        ]),
      if (source.trainingSessionId != null)
        jsonEncode(['record_session', h.recordId]): jsonEncode([
          source.trainingSessionId,
        ]),
      if (scope != null)
        jsonEncode(['record_programme', h.recordId]): jsonEncode([
          scope.programmeVersionId,
          scope.packageHash,
          scope.slotKey,
          scope.protocolId,
          scope.protocolRevision,
        ]),
      jsonEncode(['block', h.blockResultId]): jsonEncode([
        h.recordId,
        h.sourceBlockId,
      ]),
      if (h.exerciseResultId != null)
        jsonEncode(['exercise', h.exerciseResultId]): jsonEncode([
          h.blockResultId,
        ]),
      if (h.setResultId != null)
        jsonEncode(['set', h.setResultId]): jsonEncode([h.exerciseResultId]),
    };
  }

  // Immutable declared origin envelope; correction cannot reclassify a source
  // into a test attempt or silently attach it to a different programme.
  String originIdentity(TrackingMeasurementSource s) => jsonEncode([
    s.kind.name,
    s.sourceId,
    s.assessment?.toJson(),
    s.attemptId,
    s.programmeScope?.toJson(),
    s.assignmentId,
    s.occurrenceId,
    s.trainingSessionId,
  ]);

  /// Correction/input digests identify revisions, not independent attempts.
  String sourceIdentity(TrackingMeasurementSource s) {
    final h = s.history;
    return jsonEncode(
      h == null
          ? [s.kind.name, s.sourceId, s.attemptId, s.assessment?.toJson()]
          : [
              h.recordId,
              h.blockResultId,
              h.sourceBlockId,
              h.exerciseResultId,
              h.setResultId,
              h.fieldPath,
              h.workoutId,
              h.stepId,
              h.repeatOrdinal,
            ],
    );
  }
}
