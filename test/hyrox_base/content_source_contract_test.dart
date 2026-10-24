import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_plan_package/cohort_plan_package.dart';
import 'package:cohort_platform/application/hyrox_base/bound_programme.dart';
import 'package:cohort_platform/models/strength_exercise_prescription.dart';
import 'package:cohort_platform/models/timer_configuration.dart';

void main() {
  final source =
      jsonDecode(
            File('docs/programmes/hyrox_base/SESSIONS.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final sessions = (source['sessions'] as List).cast<Map<String, dynamic>>();

  test(
    'all 24 approved intents match the established v3 parameter contract',
    () {
      const catalogue = HyroxBindingCatalogue();
      var count = 0;
      for (final session in sessions) {
        for (final raw in session['binding_intents'] as List) {
          final intent = raw as Map<String, dynamic>;
          final kind = PersonalisationTargetKind.values.byName(
            intent['kind'] as String,
          );
          expect(
            intent['parameters'],
            catalogue.parameters(kind, session['week'] as int),
            reason: session['source_id'] as String,
          );
          count++;
        }
        expect(session['canonical_source'], isNull);
        expect(session['exact_exercise_versions'], isNull);
      }
      expect(count, 24);
    },
  );

  test(
    'established strength model preserves representable rep and side fragments',
    () {
      var count = 0;
      for (final session in sessions) {
        for (final raw in session['blocks'] as List) {
          final block = raw as Map<String, dynamic>;
          final items = block['kind'] == 'superset'
              ? (block['exercises'] as List).cast<Map<String, dynamic>>()
              : [block];
          for (final item in items) {
            final reps = item['reps'];
            if (item['kind'] != 'strength' || reps == null) continue;
            final values = (reps as List).cast<int>();
            final model = StrengthExercisePrescription(
              sets: item['sets'] as int,
              reps: values[0] == values[1]
                  ? StrengthRepPrescription.exact(values[0])
                  : StrengthRepPrescription.range(
                      min: values[0],
                      max: values[1],
                    ),
              perSide: item['per_side'] == true,
            );
            expect(model.validate(requireComplete: true), isEmpty);
            final roundTrip = StrengthExercisePrescription.fromJson(
              model.toJson(),
            );
            expect(roundTrip.toJson(), model.toJson());
            expect(roundTrip.perSide, item['per_side'] == true);
            // No scalar rest/RIR is invented to lower unsupported ranges.
            expect(roundTrip.restSeconds, isNull);
            expect(roundTrip.load, isNull);
            count++;
          }
        }
      }
      expect(
        count,
        79,
      ); // 24 primary + 48 paired + 8 Pallof - 1 unresolved cable row.
    },
  );

  test(
    'existing timer model preserves totals and minute intervals as fragments',
    () {
      var count = 0;
      for (final session in sessions) {
        for (final raw in session['blocks'] as List) {
          final block = raw as Map<String, dynamic>;
          if (![
            'alternating_emom',
            'three_minute_cycle',
          ].contains(block['kind'])) {
            continue;
          }
          final model = TimerConfiguration(
            totalDurationSeconds: (block['minutes'] as int) * 60,
            intervalSeconds: block['interval_seconds'] as int,
          );
          final decoded = TimerConfiguration.fromJson(model.toJson());
          expect(decoded.emomTotalSeconds, model.emomTotalSeconds);
          expect(decoded.intervalSeconds, 60);
          // Station identity/capture/graph proof is still explicitly T1/T2 blocked.
          expect(decoded.stations, isEmpty);
          expect(session['technical_blockers'], containsAll(['T1', 'T2']));
          count++;
        }
      }
      expect(count, 16);
    },
  );
}
