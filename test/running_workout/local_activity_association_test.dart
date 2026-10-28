import 'package:flutter_test/flutter_test.dart';
import 'package:cohort_platform/domain/running_workout/local_activity_association.dart';
import 'package:cohort_platform/features/session/models/frozen_running_fit_export.dart';
import 'fixtures/m25/frozen_fixture.dart';

const fileA = FitTrainingFileReference(
  manufacturer: 255,
  product: 1,
  serialNumber: 1001,
  timeCreated: 1,
);
const fileB = FitTrainingFileReference(
  manufacturer: 255,
  product: 1,
  serialNumber: 1002,
  timeCreated: 1,
);
LocalDeliveryFixture delivery(
  FrozenRunningFitExport e, {
  FitTrainingFileReference? file = fileA,
  String workout = 'proposed-workout-a',
  String schedule = 'proposed-schedule-a',
}) => LocalDeliveryFixture(
  frozenExport: e.json,
  trainingFile: file,
  proposedWorkoutId: workout,
  proposedScheduleId: schedule,
);
SyntheticActivityObservation activity({
  String owner = 'fixture-owner-a',
  String id = 'return-1',
  FitTrainingFileReference? file,
  String? workout,
  String? schedule,
  int? distance = 4000000,
}) => SyntheticActivityObservation(
  athleteId: owner,
  activityKey: id,
  trainingFile: file,
  proposedWorkoutId: workout,
  proposedScheduleId: schedule,
  name: 'Identical workout name',
  startedAt: DateTime.utc(2026, 10, 28),
  timerMilliseconds: 1100000,
  elapsedMilliseconds: 1200000,
  distanceMillimetres: distance,
);
void main() {
  late FrozenRunningFitExport e;
  late LocalActivityAssociationHarness h;
  setUp(() {
    e = FrozenFitFixture().export();
    h = LocalActivityAssociationHarness();
  });
  LocalAssociationAssessment observe(SyntheticActivityObservation a) =>
      h.observe(athleteId: a.athleteId, activity: a);
  test(
    'documented file reference is a candidate requiring confirmation, never completion',
    () {
      h.registerDelivery(delivery(e));
      final a = activity(file: fileA);
      final r = observe(a);
      expect(r.status, LocalAssociationStatus.documentedFitReferenceCandidate);
      expect(r.requiresAthleteConfirmation, true);
      expect(r.authorisesProgrammeCompletion, false);
      expect(
        h
            .confirm(
              athleteId: a.athleteId,
              activityKey: a.activityKey,
              manifestDigest: e.digest,
              expectedObservationDigest: a.digest,
            )
            .status,
        LocalAssociationStatus.confirmedByAthlete,
      );
      expect(
        h
            .inspect(athleteId: a.athleteId, activityKey: a.activityKey)
            .authorisesProgrammeCompletion,
        false,
      );
    },
  );
  test('timestamp/name/distance without correlation stays unmatched', () {
    h.registerDelivery(delivery(e));
    final r = observe(activity());
    expect(r.status, LocalAssociationStatus.unmatched);
    expect(r.candidateManifestDigests, isEmpty);
  });
  test('proposed API IDs alone remain portal assumptions', () {
    h.registerDelivery(delivery(e));
    final r = observe(activity(workout: 'proposed-workout-a'));
    expect(r.status, LocalAssociationStatus.proposedIdentifiersOnly);
    expect(r.requiresAthleteConfirmation, true);
    expect(r.authorisesProgrammeCompletion, false);
  });
  test('repeated returns and repeated deliveries keep one identity', () {
    h.registerDelivery(delivery(e));
    h.registerDelivery(delivery(e));
    final a = activity(file: fileA);
    expect(observe(a).duplicate, false);
    final repeat = observe(a);
    expect(repeat.duplicate, true);
    expect(repeat.candidateManifestDigests, [e.digest]);
  });
  test(
    'return before delivery re-evaluates without requiring a new activity',
    () {
      final a = activity(file: fileA);
      expect(observe(a).status, LocalAssociationStatus.unmatched);
      h.registerDelivery(delivery(e));
      expect(
        h.inspect(athleteId: a.athleteId, activityKey: a.activityKey).status,
        LocalAssociationStatus.documentedFitReferenceCandidate,
      );
      expect(observe(a).duplicate, true);
    },
  );
  test(
    'reused reference across occurrences is ambiguous; hints cannot resolve it',
    () {
      final other = FrozenFitFixture(occurrence: 'other').export();
      h.registerDelivery(delivery(e));
      h.registerDelivery(delivery(other, workout: 'other', schedule: 'other'));
      final a = activity(file: fileA, workout: 'proposed-workout-a');
      final r = observe(a);
      expect(r.status, LocalAssociationStatus.ambiguous);
      expect(r.candidateManifestDigests, containsAll([e.digest, other.digest]));
      expect(
        h
            .confirm(
              athleteId: a.athleteId,
              activityKey: a.activityKey,
              manifestDigest: e.digest,
              expectedObservationDigest: a.digest,
            )
            .status,
        LocalAssociationStatus.confirmedByAthlete,
      );
    },
  );
  test(
    'contradictory proposed hints cannot disambiguate a reused FIT reference',
    () {
      final other = FrozenFitFixture(occurrence: 'other').export();
      h.registerDelivery(delivery(e));
      h.registerDelivery(delivery(other, workout: 'other', schedule: 'other'));
      expect(
        observe(
          activity(
            file: fileA,
            workout: 'proposed-workout-a',
            schedule: 'other',
          ),
        ).status,
        LocalAssociationStatus.conflictingIdentifiers,
      );
    },
  );
  test('conflicting documented and proposed identifiers quarantine', () {
    final other = FrozenFitFixture(occurrence: 'other').export();
    h.registerDelivery(delivery(e));
    h.registerDelivery(
      delivery(other, file: fileB, workout: 'other', schedule: 'other'),
    );
    final a = activity(file: fileA, workout: 'other');
    expect(observe(a).status, LocalAssociationStatus.conflictingIdentifiers);
    expect(
      () => h.confirm(
        athleteId: a.athleteId,
        activityKey: a.activityKey,
        manifestDigest: e.digest,
        expectedObservationDigest: a.digest,
      ),
      throwsFormatException,
    );
  });
  test('conflicting proposed workout/schedule IDs are not combined', () {
    final other = FrozenFitFixture(occurrence: 'other').export();
    h.registerDelivery(delivery(e));
    h.registerDelivery(
      delivery(other, file: fileB, workout: 'other', schedule: 'other'),
    );
    expect(
      observe(
        activity(workout: 'proposed-workout-a', schedule: 'other'),
      ).status,
      LocalAssociationStatus.conflictingIdentifiers,
    );
  });
  test(
    'same activity key with changed actuals is conflict in either order',
    () {
      h.registerDelivery(delivery(e));
      for (final distances in [
        [4000000, 5000000],
        [5000000, 4000000],
      ]) {
        final key = 'order-${distances.first}';
        observe(activity(id: key, file: fileA, distance: distances.first));
        final changed = observe(
          activity(id: key, file: fileA, distance: distances.last),
        );
        expect(changed.status, LocalAssociationStatus.conflictingReturns);
        expect(
          observe(
            activity(id: key, file: fileA, distance: distances.first),
          ).status,
          LocalAssociationStatus.conflictingReturns,
        );
      }
    },
  );
  test(
    'late conflicting return cannot replace a confirmation or prescribed targets',
    () {
      final frozen = e.digest;
      h.registerDelivery(delivery(e));
      final a = activity(file: fileA);
      observe(a);
      h.confirm(
        athleteId: a.athleteId,
        activityKey: a.activityKey,
        manifestDigest: e.digest,
        expectedObservationDigest: a.digest,
      );
      expect(
        observe(activity(file: fileB)).status,
        LocalAssociationStatus.conflictingReturns,
      );
      expect(e.digest, frozen);
      expect(
        e.json['prescription']['resolved_body']['steps'][1]['steps'][0]['target']['low'],
        294000,
      );
    },
  );
  test(
    'owner isolation covers observations, candidate discovery and confirmation',
    () {
      h.registerDelivery(delivery(e));
      final foreign = FrozenFitFixture(owner: 'foreign').export();
      h.registerDelivery(delivery(foreign, file: fileB));
      expect(
        () => h.observe(
          athleteId: 'foreign',
          activity: activity(file: fileA),
        ),
        throwsFormatException,
      );
      final a = activity(file: fileB);
      expect(observe(a).status, LocalAssociationStatus.unmatched);
      expect(
        () => h.confirm(
          athleteId: a.athleteId,
          activityKey: a.activityKey,
          manifestDigest: foreign.digest,
          expectedObservationDigest: a.digest,
        ),
        throwsFormatException,
      );
      final sameKey = activity(owner: 'foreign', file: fileB);
      expect(observe(sameKey).candidateManifestDigests, [foreign.digest]);
      expect(observe(a).duplicate, true);
    },
  );
  test(
    'old return binds the old frozen version after new version registration',
    () {
      final later = FrozenFitFixture(
        version: 'version-2',
        occurrence: 'occurrence-2',
      ).export();
      h.registerDelivery(delivery(e));
      h.registerDelivery(
        delivery(later, file: fileB, workout: 'new', schedule: 'new'),
      );
      expect(observe(activity(file: fileA)).candidateManifestDigests, [
        e.digest,
      ]);
      expect(
        observe(activity(id: 'later', file: fileB)).candidateManifestDigests,
        [later.digest],
      );
      expect(e.scope['programme_version_id'], 'fixture-version-1');
    },
  );
  test('stale confirmation and retargeting a confirmed activity refuse', () {
    h.registerDelivery(delivery(e));
    final a = activity();
    observe(a);
    expect(
      () => h.confirm(
        athleteId: a.athleteId,
        activityKey: a.activityKey,
        manifestDigest: e.digest,
        expectedObservationDigest: 'stale',
      ),
      throwsFormatException,
    );
    h.confirm(
      athleteId: a.athleteId,
      activityKey: a.activityKey,
      manifestDigest: e.digest,
      expectedObservationDigest: a.digest,
    );
    final other = FrozenFitFixture(occurrence: 'other').export();
    h.registerDelivery(delivery(other, file: fileB));
    expect(
      () => h.confirm(
        athleteId: a.athleteId,
        activityKey: a.activityKey,
        manifestDigest: other.digest,
        expectedObservationDigest: a.digest,
      ),
      throwsFormatException,
    );
  });
  test(
    'actuals preserve missing measurements and cannot replace prescription',
    () {
      final a = activity(distance: null);
      expect(a.toJson()['actuals']['distance_millimetres'], isNull);
      expect(a.toJson()['actuals']['average_heart_rate_bpm'], isNull);
      h.registerDelivery(delivery(e));
      expect(observe(a).authorisesProgrammeCompletion, false);
      expect(e.json.containsKey('actuals'), false);
      expect(
        () => SyntheticActivityObservation(
          athleteId: 'a',
          activityKey: 'id',
          timerMilliseconds: 2,
          elapsedMilliseconds: 1,
        ),
        throwsFormatException,
      );
    },
  );
  test('changed immutable delivery receipt refuses', () {
    h.registerDelivery(delivery(e));
    expect(
      () => h.registerDelivery(delivery(e, file: fileB)),
      throwsFormatException,
    );
  });
}
