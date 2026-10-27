import 'package:flutter/foundation.dart';

import '../auth/services/current_user_session.dart';
import 'acquisition_store.dart';

/// Account-scoped acquisition state. Late responses cannot update another visit.
class AcquisitionController extends ChangeNotifier {
  AcquisitionController({
    required this.athleteId,
    required this.store,
    String? Function()? currentAthlete,
  }) : _currentAthlete =
           currentAthlete ??
           (() => CurrentUserSession.maybeInstance?.athleteId);
  final String athleteId;
  final AcquisitionStore store;
  final String? Function() _currentAthlete;
  TrainingSetup? setup;
  List<PrivateProgrammeOffer> offers = const [];
  AcquisitionException? error;
  bool busy = false;
  bool _disposed = false;
  int _generation = 0;

  bool get isCurrent => !_disposed && _currentAthlete() == athleteId;

  void invalidate() {
    _generation++;
    setup = null;
    offers = const [];
    error = const AcquisitionException('session_expired');
    busy = false;
    if (!_disposed) notifyListeners();
  }

  Future<T?> _run<T>(Future<T> Function() work, void Function(T) apply) async {
    if (!isCurrent) {
      invalidate();
      return null;
    }
    if (busy) return null;
    final generation = ++_generation;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final value = await work();
      if (!isCurrent || generation != _generation) return null;
      apply(value);
      return value;
    } catch (e) {
      if (isCurrent && generation == _generation) {
        error = e is AcquisitionException
            ? e
            : const AcquisitionException('unavailable');
      }
      return null;
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        if (!isCurrent) {
          setup = null;
          offers = const [];
          error = const AcquisitionException('session_expired');
        }
        notifyListeners();
      }
    }
  }

  Future<TrainingSetup?> loadSetup() => _run(store.loadSetup, (s) => setup = s);
  Future<TrainingSetup?> saveSetup(String timezone, {required bool complete}) =>
      _run(
        () => store.saveSetup(timezone, complete: complete),
        (s) => setup = s,
      );
  Future<List<PrivateProgrammeOffer>?> loadCatalogue() =>
      _run(store.catalogue, (items) => offers = items);
  Future<PrivateProgrammeOffer?> detail(String versionId) async {
    PrivateProgrammeOffer? offer;
    await _run(() => store.catalogue(versionId: versionId), (items) {
      if (items.length == 1 && items.single.versionId == versionId) {
        offer = items.single;
      } else {
        error = const AcquisitionException('access_denied');
      }
    });
    return offer;
  }

  Future<String?> acquire(String versionId, DateTime date) =>
      _run(() => store.acquire(versionId, date), (_) {});

  @override
  void dispose() {
    _generation++;
    _disposed = true;
    super.dispose();
  }
}
