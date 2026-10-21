import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../domain/exercise_knowledge/value_objects/exercise_id.dart';
import '../domain/programme_review_models.dart';
import 'programme_review_catalog.dart';
import 'programme_review_workspace.dart';

/// Derived inspection of existing registered sources, never a source intake,
/// approval record, canonical identity resolver or publication readiness receipt.
Map<String, Object?> sourceReadinessReport({
  required String catalogId,
  required ProgrammeReviewAssetRead readAsset,
}) {
  final specs = ProgrammeReviewCatalogRegistry.realSpecs
      .where((s) => s.catalogId == catalogId)
      .toList();
  final planned = ProgrammeReviewCatalogRegistry.plannedFamilies
      .where((f) => f.id == catalogId)
      .toList();
  if (specs.length + planned.length != 1) {
    throw const FormatException(
      'Choose one existing registered source or planned family ID.',
    );
  }
  final hashes = <String, String>{};
  ProgrammeReviewProgramme? programme;
  if (specs.isNotEmpty) {
    final workspace = ProgrammeReviewWorkspace(
      readAsset: (path) {
        final text = readAsset(path);
        hashes[path] = sha256.convert(utf8.encode(text)).toString();
        return text;
      },
    );
    programme = workspace.projector.projectBundle(
      workspace.loadBundle(specs.single),
    );
  }
  final sessions =
      programme?.weeks
          .expand((w) => w.days)
          .expand((d) => d.sessions)
          .toList() ??
      <ProgrammeReviewSession>[];
  final missingBodies = sessions
      .where((s) => !s.bodiesResolved || s.blocks.isEmpty)
      .map(
        (s) => {
          'session_key': s.sessionKey,
          'protocol_id': s.protocolId,
          'slot_key': s.slotKey,
        },
      )
      .toList();
  final bindings = <Map<String, Object?>>[];
  for (final s in sessions) {
    for (final b in s.blocks) {
      for (final m in b.movements) {
        final id = ExerciseId.tryParse(m.exerciseId);
        bindings.add({
          'session_key': s.sessionKey,
          'slot_key': s.slotKey,
          'block_source_id': b.sourceIdentity,
          'movement_position': m.position,
          'exercise_reference': m.exerciseId,
          'issue': id == null || id.value != m.exerciseId
              ? 'missing_or_malformed_canonical_reference'
              : 'canonical_definition_version_not_supplied',
        });
      }
    }
  }
  final findings = programme?.findings ?? const <ProgrammeReviewFinding>[];
  final unsupported = findings
      .where((f) => f.code == 'unsupported_prescription')
      .map((f) => f.toJson())
      .toList();
  final compileValid =
      programme?.compile.state == ProgrammeReviewCompileState.valid;
  final reviewBlocked =
      !compileValid ||
      sessions.isEmpty ||
      missingBodies.isNotEmpty ||
      findings.any((f) => f.severity == ProgrammeReviewFindingSeverity.error);
  return {
    'report_authority': 'derived_read_only_not_content_approval',
    'catalog_id': catalogId,
    'candidate_source': {
      'status': programme == null ? 'absent' : 'registered_source_present',
      'file_sha256': {
        for (final p in hashes.keys.toList()..sort()) p: hashes[p],
      },
      if (compileValid) 'version_number': programme!.versionNumber,
      if (planned.isNotEmpty)
        'planned_duration_weeks': planned.single.durationWeeks,
    },
    'content_authority': {
      'status': programme == null
          ? 'missing_source_and_approval'
          : 'not_verified',
      'detail':
          'Requires separate documented founder approval tied to the exact '
          'source/version and operation. Registration, filenames, lifecycle labels, '
          'compilation and hashes do not establish that approval.',
    },
    'canonical_package': {
      'status': programme == null
          ? 'not_assessed'
          : compileValid
          ? 'compiled'
          : 'invalid',
      if (programme != null) 'compile': programme.compile.toJson(),
      'detail':
          'The existing compiler validates the package, not session doses or content approval.',
    },
    'exercise_bindings': {
      'status': bindings.isEmpty ? 'not_assessed' : 'unresolved',
      'issues': bindings,
      'detail':
          'EX-* syntax is checked with ExerciseId. These source formats do not '
          'supply authoritative published ExerciseDefinition version bindings. '
          'No definition, version, name mapping or row-snapshot authority is invented.',
    },
    'unsupported_prescriptions': {
      'status': programme == null || !compileValid || sessions.isEmpty
          ? 'not_assessed'
          : unsupported.isNotEmpty
          ? 'detected'
          : missingBodies.isNotEmpty
          ? 'not_assessed'
          : 'none_detected_by_existing_projector',
      'findings': unsupported,
    },
    'readable_review': {
      'status': programme == null
          ? 'not_assessed'
          : reviewBlocked
          ? 'blocked'
          : unsupported.isNotEmpty
          ? 'incomplete'
          : 'requires_human_review',
      'scheduled_sessions': sessions.length,
      'missing_or_empty_bodies': missingBodies,
      'detail':
          'Reuses existing projector findings. Absence of detected limitations '
          'does not prove complete timer/block coverage, editorial or device review.',
    },
    'canonical_publication': {
      'status': 'not_established',
      'detail':
          'This report is not an import or publication format. It performs no '
          'trusted import validation, publication or athlete operation. Pilot envelopes '
          'and row snapshots do not become canonical publication inputs or definitions.',
    },
    'projection_findings': findings.map((f) => f.toJson()).toList(),
  };
}
