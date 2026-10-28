// Run with Flutter's local test runtime; no app launch, network or hosted access.
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/domain/running_workout/local_activity_association.dart';
import '../../test/running_workout/fixtures/m25/frozen_fixture.dart';

void main() {
  test(
    'emit synthetic frozen FIT representation and association demonstration',
    () {
      const destination = String.fromEnvironment('M25_OUTPUT');
      if (destination.isEmpty) {
        throw StateError('Supply --dart-define=M25_OUTPUT=<local output.json>');
      }
      final e = FrozenFitFixture().export();
      final h = LocalActivityAssociationHarness();
      const file = FitTrainingFileReference(
        manufacturer: 255,
        product: 1,
        serialNumber: 1001,
        timeCreated: 1,
      );
      final a = SyntheticActivityObservation(
        athleteId: e.scope['athlete_id'] as String,
        activityKey: 'SYNTHETIC-RETURN-1',
        trainingFile: file,
        timerMilliseconds: 1100000,
        elapsedMilliseconds: 1200000,
        distanceMillimetres: 4000000,
      );
      final early = h.observe(athleteId: a.athleteId, activity: a);
      h.registerDelivery(
        LocalDeliveryFixture(frozenExport: e.json, trainingFile: file),
      );
      final later = h.observe(athleteId: a.athleteId, activity: a);
      final confirmed = h.confirm(
        athleteId: a.athleteId,
        activityKey: a.activityKey,
        manifestDigest: e.digest,
        expectedObservationDigest: a.digest,
      );
      expect(confirmed.authorisesProgrammeCompletion, false);
      final document = {
        'fixture_only': true,
        'evidence':
            'LOCAL SYNTHETIC REPRESENTATION; NOT A FIT BINARY OR GARMIN ROUND TRIP',
        'export_digest': e.digest,
        'export': e.json,
        'activity_fixture': a.toJson(),
        'association_fixture': {
          'before_delivery': early.status.name,
          'after_delivery': later.status.name,
          'duplicate': later.duplicate,
          'after_explicit_fixture_confirmation': confirmed.status.name,
          'authorises_programme_completion':
              confirmed.authorisesProgrammeCompletion,
        },
      };
      File(destination).writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(document)}\n',
      );
    },
  );
}
