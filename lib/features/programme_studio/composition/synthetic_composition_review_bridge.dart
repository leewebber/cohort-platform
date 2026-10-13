import 'dart:convert';

import 'package:cohort_plan_package/cohort_plan_package.dart';

import '../authoring/programme_authoring_controller.dart';
import '../authoring/programme_authoring_fixtures.dart';
import '../domain/programme_review_models.dart';
import '../projection/programme_review_projector.dart';
import '../projection/programme_review_source.dart';
import '../protocol_authoring/synthetic_strength_session_compiler.dart';
import 'synthetic_composition_fixtures.dart';
import 'synthetic_programme_revision_catalogue.dart';

class CompositionReviewReceipt {
  CompositionReviewReceipt({
    required this.programmeSource,
    required this.canonicalJson,
    required this.packageHash,
    required Iterable<D2CompiledSession> entries,
    required Iterable<Map<String, Object>> slots,
  }) : sessions = List.unmodifiable(entries),
       slotBindings = List.unmodifiable(
         slots.map((s) => Map<String, Object>.unmodifiable(s)),
       );
  final String programmeSource, canonicalJson, packageHash;
  final List<D2CompiledSession> sessions;
  final List<Map<String, Object>> slotBindings;
  String get programmeSourceDigest => d2SourceDigest(programmeSource);
  // Fresh projection prevents a consumer mutating a derived list becoming authority.
  ProgrammeReviewCatalog get catalog =>
      projectComposition(programmeSource, sessions);
}

ProgrammeReviewCatalog projectComposition(
  String yaml,
  List<D2CompiledSession> sessions,
) => const ProgrammeReviewProjector().project(
  ProgrammeReviewProjectionRequest(
    bundles: [compositionBundle(yaml, sessions)],
  ),
);

CompositionReviewReceipt reviewComposition(
  String yaml,
  List<D2CompiledSession> sessions,
) {
  final package = const PlanPackageCompiler().compile(yaml);
  if (!package.isValid || package.manifest!.packageSchemaVersion != 1) {
    throw FormatException(
      'programme: ${package.issues.map((i) => '${i.path}: ${i.message}').join('\n')}',
    );
  }
  final r1 = sessions.where((s) => s.identity.revisionNumber == 1).toList();
  if (r1.length != 1) {
    throw const FormatException('sources: original R1 is required.');
  }
  // Reuse D1's locked skeleton/slot rules and isolated exact catalogue policy.
  // This temporary read-only checking controller is never the live editor.
  final catalogue = SyntheticProgrammeRevisionCatalogue.readOnly(sessions);
  final check = ProgrammeAuthoringController(
    fixture: programmeAuthoringFixtures.first,
    source: CompositionProgrammeSource(catalogue),
  );
  try {
    if (!check.loadSource(yaml) || !check.validateAndReview()) {
      throw FormatException(
        check.issues.map((i) => '${i.path}: ${i.message}').join('\n'),
      );
    }
  } finally {
    check.dispose();
  }
  final projected = projectComposition(yaml, sessions);
  final programme = projected.developerFixtures.single;
  final byKey = {
    for (final s in sessions) compositionReference(s)['session_key']: s,
  };
  final bindings = <Map<String, Object>>[];
  var count = 0;
  for (final week in programme.weeks) {
    for (final day in week.days) {
      for (final slot in day.sessions) {
        count++;
        final s = byKey[slot.sessionKey];
        if (s == null ||
            !slot.bodiesResolved ||
            slot.protocolId != s.identity.protocolId ||
            slot.sessionLineageId != s.identity.sessionLineageId ||
            slot.revisionNumber != s.identity.revisionNumber ||
            slot.blocks.length != 1) {
          throw FormatException(
            'slots.${slot.slotKey}: exact revision/body is unresolved.',
          );
        }
        final b = slot.blocks.single, expected = s.protocol.blocks.single;
        if (b.unsupportedReason != null ||
            b.title != expected.title ||
            b.coachNotes != expected.coachNotes ||
            b.movements.length != expected.linkedExercises.length) {
          throw FormatException('slots.${slot.slotKey}: body mismatch.');
        }
        for (var i = 0; i < b.movements.length; i++) {
          final m = b.movements[i], e = expected.linkedExercises[i];
          if (m.unsupportedReason != null ||
              m.exerciseId != e.exerciseId ||
              m.position != e.position ||
              m.name != (e.displayLabelOverride ?? e.exerciseId) ||
              m.rawPrescription != jsonEncode(e.prescription!.toJson())) {
            throw FormatException(
              'slots.${slot.slotKey}: prescription mismatch.',
            );
          }
        }
        bindings.add(
          Map.unmodifiable({
            'week_number': week.weekNumber,
            'day_key': day.dayKey,
            'slot_key': slot.slotKey!,
            'session_order': slot.sessionOrder,
            'session_key': slot.sessionKey,
            ...compositionTuple(s.identity),
            'source_digest': s.sourceDigest,
            'exercise_bindings': compositionJson(s.bindings),
          }),
        );
      }
    }
  }
  final expectedCount = package.manifest!.weeks
      .expand((w) => w.days)
      .expand((d) => d.slots)
      .length;
  if (count != expectedCount ||
      programme.findings.any(
        (f) => f.severity == ProgrammeReviewFindingSeverity.error,
      )) {
    throw const FormatException(
      'review: incomplete programme/slot projection.',
    );
  }
  return CompositionReviewReceipt(
    programmeSource: yaml,
    canonicalJson: package.canonicalJson!,
    packageHash: package.contentHashSha256!,
    entries: sessions,
    slots: bindings,
  );
}
