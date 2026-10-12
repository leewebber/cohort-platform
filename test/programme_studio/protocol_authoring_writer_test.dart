import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_source_guard.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/founder_strength_yaml_writer.dart';
import 'package:cohort_platform/features/programme_studio/protocol_authoring/protocol_authoring_fixtures.dart';

void main() {
  const writer = FounderStrengthYamlWriter(),
      guard = FounderStrengthSourceGuard();
  test(
    'all supported fields, Unicode and multiline text survive deterministic export',
    () {
      final tree = d2FounderTree();
      FounderStrengthSourceGuard.session(tree)['coach_notes'] =
          'Line one\n“two”\\ 😀';
      for (final load in [
        null,
        {'unit': 'bodyweight'},
        {'unit': 'kg', 'value': 12},
        {'unit': 'rpe', 'value': 10},
      ]) {
        final p =
            FounderStrengthSourceGuard.exerciseRows(tree).first['prescription']
                as Map;
        if (load == null) {
          p.remove('load');
        } else {
          p['load'] = load;
        }
        final bytes = writer.write(
          guard.canonicalTree(writer.write(tree), importKey: d2ImportKey(1)),
        );
        expect(
          writer.write(guard.canonicalTree(bytes, importKey: d2ImportKey(1))),
          bytes,
        );
        expect(bytes.endsWith('\n'), true);
        expect(bytes.contains('\r'), false);
        expect(
          FounderStrengthSourceGuard.session(
            guard.read(bytes, importKey: d2ImportKey(1)),
          )['coach_notes'],
          'Line one\n“two”\\ 😀',
        );
        expect(
          writer.write(
            guard.canonicalTree(writer.write(tree), importKey: d2ImportKey(1)),
          ),
          bytes,
        );
      }
    },
  );
  test(
    'exact-map and RPE alias normalize intentionally; unspecified stays absent',
    () {
      final tree = d2FounderTree();
      final p =
          FounderStrengthSourceGuard.exerciseRows(tree).first['prescription']
              as Map;
      p['reps'] = {'type': 'exact', 'exact_reps': 5};
      p.remove('load');
      p['target_rpe'] = 7;
      final normalized = guard.canonicalTree(
        writer.write(tree),
        importKey: d2ImportKey(1),
      );
      final dose =
          FounderStrengthSourceGuard.exerciseRows(
                normalized,
              ).first['prescription']
              as Map;
      expect(dose['reps'], 5);
      expect(dose['load'], {'unit': 'rpe', 'value': 7});
      expect(dose.containsKey('target_rpe'), false);
      final unspecified =
          FounderStrengthSourceGuard.exerciseRows(
                normalized,
              ).last['prescription']
              as Map;
      for (final key in ['load', 'rest_seconds', 'tempo', 'notes']) {
        expect(unspecified.containsKey(key), false);
      }
    },
  );
  for (final entry in <String, void Function(Map<String, dynamic>)>{
    'unknown root': (t) => t['future_contract'] = {'required': true},
    'row notes': (t) =>
        FounderStrengthSourceGuard.exerciseRows(t).first['notes'] =
            'must not vanish',
    'performance capture': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
            as Map)['performance_capture'] = {
          'rpe': true,
        },
    'rep range': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
            as Map)['reps'] = {
          'type': 'range',
          'min': 3,
          'max': 6,
        },
    'zero rest': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
                as Map)['rest_seconds'] =
            0,
    'fractional sets': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
                as Map)['sets'] =
            2.5,
    'numeric string': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
                as Map)['reps'] =
            '5',
    'load and RPE': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
                as Map)['target_rpe'] =
            7,
    'RPE over 10': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
            as Map)['load'] = {
          'unit': 'rpe',
          'value': 11,
        },
    'bodyweight value': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
            as Map)['load'] = {
          'unit': 'bodyweight',
          'value': 1,
        },
    'other unit': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
            as Map)['load'] = {
          'unit': 'lb',
          'value': 10,
        },
    'null rest': (t) =>
        (FounderStrengthSourceGuard.exerciseRows(t).first['prescription']
                as Map)['rest_seconds'] =
            null,
    'wrong title type': (t) =>
        FounderStrengthSourceGuard.session(t)['title'] = 7,
    'extra session': (t) =>
        (((((t['weeks'] as List).single as Map)['days'] as List).single
                    as Map)['sessions']
                as List)
            .add({}),
  }.entries) {
    test('refuses ${entry.key} without deleting the input', () {
      final tree = d2FounderTree();
      entry.value(tree);
      final bytes = writer.write(tree);
      expect(
        () => guard.read(bytes, importKey: d2ImportKey(1)),
        throwsFormatException,
      );
      expect(writer.write(tree), bytes);
    });
  }
  test('opaque plain text does not hide later unsupported YAML syntax', () {
    final source = writer
        .write(d2FounderTree())
        .replaceFirst(
          '"Synthetic session note."',
          "don't treat &literal as an identity",
        );
    expect(guard.read(source, importKey: d2ImportKey(1)), isNotNull);
    expect(
      () => guard.read(
        source.replaceFirst('sets: 2', 'sets: &dose 2'),
        importKey: d2ImportKey(1),
      ),
      throwsFormatException,
    );
  });
  test(
    'duplicate keys, aliases, tags and multiple documents are explicit errors',
    () {
      final source = writer.write(d2FounderTree());
      for (final bytes in [
        source.replaceFirst(
          'schema_version: 1',
          'schema_version: 1\nschema_version: 1',
        ),
        '$source\n---\n{}',
        source.replaceFirst('schema_version: 1', 'schema_version: &version 1'),
        source.replaceFirst('schema_version: 1', 'schema_version: !!int 1'),
      ]) {
        expect(
          () => guard.read(bytes, importKey: d2ImportKey(1)),
          throwsFormatException,
        );
      }
      expect(
        () => writer.write({'bad': double.infinity}),
        throwsFormatException,
      );
    },
  );
}
