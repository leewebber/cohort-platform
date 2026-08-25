import 'dart:convert';
import 'dart:io';

import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    'supabase/migrations/'
    '20260825120000_structure_all_apollo_warmups_and_athlete_details.sql',
  );

  test('every authored Apollo warm-up template prescription decodes', () {
    final sql = migration.readAsStringSync();
    final encodedPrescriptions = RegExp(r"'(\{[^']+\})'::JSONB")
        .allMatches(sql)
        .map((match) => match.group(1)!)
        .where((encoded) {
          final value = jsonDecode(encoded);
          return value is Map &&
              value.containsKey('sets') &&
              value.containsKey('reps');
        })
        .toList(growable: false);

    expect(encodedPrescriptions, hasLength(29));
    for (final encoded in encodedPrescriptions) {
      final json = Map<String, dynamic>.from(jsonDecode(encoded) as Map);
      final prescription = StrengthExercisePrescription.fromJson(json);
      expect(prescription.validate(requireComplete: true), isEmpty);
      expect(json['reps'], isA<Map>());
      expect(json['load'], isNot(isA<String>()));
    }
  });

  test('migration records the complete fail-closed Apollo inventory', () {
    final sql = migration.readAsStringSync();
    expect(sql, contains('v_total <> 106'));
    expect(sql, contains('v_links <> 514'));
    expect(sql, contains("v_existing_links = 5"));
    expect(sql, contains("v_existing_links = 514"));
    expect(sql, contains('v_exact_existing_links = 514'));
    expect(sql, contains("'EX-111', 'Dead Hang'"));
    expect(sql, contains("'EX-129', 'Running'"));
    expect(sql, contains("'EX-150', 'Thoracic Extension Over Foam Roller'"));
    expect(sql, contains("'EX-169', 'Deep-Squat Pry'"));
  });
}
