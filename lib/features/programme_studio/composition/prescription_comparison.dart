import '../../../models/session_block_exercise_link.dart';
import '../../../models/strength_prescription_formatter.dart';
import '../protocol_authoring/founder_strength_source_guard.dart';
import '../protocol_authoring/protocol_authoring_fixtures.dart';
import '../protocol_authoring/synthetic_strength_lineage.dart';
import '../protocol_authoring/synthetic_strength_session_compiler.dart';

/// Descriptive authoring review only. No performance equivalence or derivation.
class PrescriptionChange {
  const PrescriptionChange(
    this.subject,
    this.field,
    this.before,
    this.after, {
    this.prescription = true,
  });
  final String subject, field, before, after;
  final bool prescription;
}

class PrescriptionComparison {
  PrescriptionComparison._(List<PrescriptionChange> changes, this.unavailable)
    : changes = List.unmodifiable(changes);
  final List<PrescriptionChange> changes;
  final String? unavailable;
  bool get supported => unavailable == null;
  bool get prescriptionChanged => changes.any((c) => c.prescription);
  String get summary => !supported
      ? 'Comparison unavailable: $unavailable'
      : prescriptionChanged
      ? 'Prescription changes'
      : changes.isNotEmpty
      ? 'Metadata only — no prescription change'
      : 'No prescription or session metadata change';

  /// Inputs are the existing exact-source compiler receipts, verified by the
  /// workspace preparation gate. Never pair exercises by title or link position.
  static PrescriptionComparison compare(
    D2CompiledSession? before,
    D2CompiledSession? after,
  ) {
    if (before == null || after == null) {
      return PrescriptionComparison._(
        [],
        'An exact current or proposed source is missing.',
      );
    }
    try {
      for (final s in [before, after]) {
        const FounderStrengthSourceGuard().read(
          s.source,
          importKey: SyntheticStrengthLineage.resolve(
            s.identity,
          ).importKey(s.identity.revisionNumber),
        );
        if (s.protocol.blocks.length != 1 ||
            s.protocol.blocks.single.linkedExercises.any(
              (e) => e.prescription == null,
            )) {
          throw const FormatException('Unsupported strength representation.');
        }
      }
      if (before.profileFingerprint != after.profileFingerprint) {
        throw const FormatException('Exercise identity profiles differ.');
      }
      final changes = <PrescriptionChange>[];
      String text(Object? v, {bool quote = false}) =>
          v == null || v.toString().trim().isEmpty
          ? 'Unspecified'
          : quote
          ? '“${v.toString().trim()}”'
          : v.toString().trim();
      void field(
        String subject,
        String label,
        Object? a,
        Object? b, {
        bool prescription = true,
        bool quote = false,
      }) {
        if (a != b) {
          changes.add(
            PrescriptionChange(
              subject,
              label,
              text(a, quote: quote),
              text(b, quote: quote),
              prescription: prescription,
            ),
          );
        }
      }

      final a = before.protocol, b = after.protocol;
      field(
        'Session',
        'Title',
        a.name,
        b.name,
        prescription: false,
        quote: true,
      );
      field(
        'Session',
        'Notes',
        a.coachingNotes,
        b.coachingNotes,
        prescription: false,
        quote: true,
      );
      field(
        'Session',
        'Estimated duration (minutes)',
        a.durationMin,
        b.durationMin,
        prescription: false,
      );
      final ab = a.blocks.single, bb = b.blocks.single;
      field(
        'Block',
        'Title',
        ab.title,
        bb.title,
        prescription: false,
        quote: true,
      );
      field(
        'Block',
        'Notes',
        ab.coachNotes,
        bb.coachNotes,
        prescription: false,
        quote: true,
      );
      Map<String, SessionBlockExerciseLink> identities(D2CompiledSession s) {
        final result = <String, SessionBlockExerciseLink>{};
        for (final e in s.protocol.blocks.single.linkedExercises) {
          final bindings = s.bindings.values
              .where((v) => v.startsWith('${e.exerciseId}@'))
              .toList();
          if (bindings.length != 1 || result.containsKey(bindings.single)) {
            throw const FormatException(
              'Exercise identity is unavailable or ambiguous.',
            );
          }
          result[bindings.single] = e;
        }
        return result;
      }

      final old = identities(before), proposed = identities(after);
      final names = {
        for (final d in d2ExerciseDefinitions()) d.id.value: d.canonicalName,
      };
      String label(SessionBlockExerciseLink e) =>
          '${e.displayLabelOverride ?? names[e.exerciseId] ?? 'Exercise'} · Exercise ${e.position}';
      String dose(SessionBlockExerciseLink e) {
        final p = e.prescription!;
        return '${StrengthPrescriptionFormatter.formatSetsReps(p)} · '
            'Load: ${text(StrengthPrescriptionFormatter.formatLoad(p.load))} · '
            '${StrengthPrescriptionFormatter.formatRest(p.restSeconds) ?? 'Rest: Unspecified'} · '
            'Tempo: ${text(p.tempo, quote: true)} · Cues: ${text(p.coachCue, quote: true)}';
      }

      for (final id in {...old.keys, ...proposed.keys}) {
        final x = old[id], y = proposed[id];
        if (x == null) {
          changes.add(
            PrescriptionChange(
              label(y!),
              'Exercise added',
              'Absent',
              'Position ${y.position}: ${dose(y)}',
            ),
          );
        } else if (y == null) {
          changes.add(
            PrescriptionChange(
              label(x),
              'Exercise removed',
              'Position ${x.position}: ${dose(x)}',
              'Absent',
            ),
          );
        } else {
          final subject = label(y), xp = x.prescription!, yp = y.prescription!;
          field(subject, 'Order', x.position, y.position);
          field(
            subject,
            'Exercise label',
            x.displayLabelOverride,
            y.displayLabelOverride,
            prescription: false,
            quote: true,
          );
          field(subject, 'Sets', xp.sets, yp.sets);
          field(subject, 'Exact reps', xp.reps.exactReps, yp.reps.exactReps);
          field(
            subject,
            'Load',
            StrengthPrescriptionFormatter.formatLoad(xp.load),
            StrengthPrescriptionFormatter.formatLoad(yp.load),
          );
          field(
            subject,
            'Rest',
            StrengthPrescriptionFormatter.formatRest(xp.restSeconds),
            StrengthPrescriptionFormatter.formatRest(yp.restSeconds),
          );
          field(subject, 'Tempo', xp.tempo, yp.tempo, quote: true);
          field(subject, 'Cues', xp.coachCue, yp.coachCue, quote: true);
        }
      }
      return PrescriptionComparison._(changes, null);
    } on FormatException catch (e) {
      return PrescriptionComparison._([], e.message);
    }
  }
}
