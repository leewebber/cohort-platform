/// Persistence boundary for deleting Session Revision content rows.
abstract class SessionRevisionDeleteStore {
  const SessionRevisionDeleteStore();

  Future<void> deleteRevision(String protocolId);
}

class SessionRevisionDeleteStoreException implements Exception {
  const SessionRevisionDeleteStoreException(this.message);

  final String message;

  @override
  String toString() => 'SessionRevisionDeleteStoreException: $message';
}
