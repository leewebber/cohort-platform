import '../models/production_restore_envelope.dart';

/// Companion store for identity + UI cursor. Not a second actuals store.
class ProductionRestoreEnvelopeStore {
  ProductionRestoreEnvelopeStore();

  static final ProductionRestoreEnvelopeStore instance =
      ProductionRestoreEnvelopeStore();

  final Map<String, ProductionRestoreEnvelope> _byKey = {};

  static String key({
    required String athleteId,
    required int trainingSessionId,
  }) =>
      '$athleteId:$trainingSessionId';

  ProductionRestoreEnvelope? read({
    required String athleteId,
    required int trainingSessionId,
  }) {
    return _byKey[key(
      athleteId: athleteId,
      trainingSessionId: trainingSessionId,
    )];
  }

  void write(ProductionRestoreEnvelope envelope) {
    _byKey[key(
      athleteId: envelope.identity.athleteId,
      trainingSessionId: envelope.identity.trainingSessionId,
    )] = envelope;
  }

  void clear({
    required String athleteId,
    required int trainingSessionId,
  }) {
    _byKey.remove(
      key(athleteId: athleteId, trainingSessionId: trainingSessionId),
    );
  }

  void clearForAthlete(String athleteId) {
    final prefix = '$athleteId:';
    _byKey.removeWhere((storeKey, _) => storeKey.startsWith(prefix));
  }

  void clearAll() => _byKey.clear();
}
