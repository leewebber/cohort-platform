import 'dart:async';
import 'package:cohort_platform/features/auth/services/current_user_session.dart';
import 'package:cohort_platform/features/programme_acquisition/acquisition_controller.dart';
import 'package:cohort_platform/features/programme_acquisition/acquisition_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'acquisition_test_support.dart';

void main() {
  setUp(bindAcquisitionActor);
  tearDown(CurrentUserSession.clear);
  test(
    'draft survives controller restart and completion does not acquire',
    () async {
      final store = FakeAcquisitionStore();
      final a = AcquisitionController(athleteId: 'athlete-a', store: store);
      await a.loadSetup();
      await a.saveSetup('Europe/London', complete: false);
      a.dispose();
      final b = AcquisitionController(athleteId: 'athlete-a', store: store);
      addTearDown(b.dispose);
      expect((await b.loadSetup())!.timezone, 'Europe/London');
      expect(b.setup!.complete, isFalse);
      await b.saveSetup('Europe/London', complete: true);
      expect(b.setup!.complete, isTrue);
      expect(store.acquisitions, 0);
    },
  );
  test('late catalogue after account switch is discarded', () async {
    final store = FakeAcquisitionStore()
      ..pendingList = Completer<List<PrivateProgrammeOffer>>();
    final c = AcquisitionController(athleteId: 'athlete-a', store: store);
    addTearDown(c.dispose);
    final pending = c.loadCatalogue();
    bindAcquisitionActor('athlete-b');
    store.pendingList!.complete(store.offers);
    expect(await pending, isNull);
    expect(c.offers, isEmpty);
    expect(c.error!.code, 'session_expired');
  });
  test(
    'in-flight duplicate acquire is ignored; logout prevents navigation result',
    () async {
      final store = FakeAcquisitionStore()
        ..pendingAcquisition = Completer<String>();
      final c = AcquisitionController(athleteId: 'athlete-a', store: store);
      addTearDown(c.dispose);
      final pending = c.acquire('private-v1', DateTime(2026));
      expect(await c.acquire('private-v1', DateTime(2026)), isNull);
      expect(store.acquisitions, 1);
      CurrentUserSession.clear();
      store.pendingAcquisition!.complete('assignment-old');
      expect(await pending, isNull);
      expect(c.error!.code, 'session_expired');
    },
  );
  test(
    'existing assignment and unavailable remain explicit; retry succeeds',
    () async {
      final store = FakeAcquisitionStore()..failure = 'active_enrolment_exists';
      final c = AcquisitionController(athleteId: 'athlete-a', store: store);
      addTearDown(c.dispose);
      expect(await c.acquire('private-v1', DateTime(2026)), isNull);
      expect(c.error!.message, contains('unchanged'));
      store.failure = null;
      expect(await c.acquire('private-v1', DateTime(2026)), 'assignment-exact');
    },
  );
  test(
    'dispose suppresses completion; invalidation clears old visible offers',
    () async {
      final store = FakeAcquisitionStore();
      final c = AcquisitionController(athleteId: 'athlete-a', store: store);
      await c.loadCatalogue();
      expect(c.offers, isNotEmpty);
      c.invalidate();
      expect(c.offers, isEmpty);
      c.dispose();
      expect(await c.loadCatalogue(), isNull);
    },
  );
}
