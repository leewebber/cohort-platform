import 'package:cohort_platform/data/repositories/session_revision_delete_store.dart';

class InMemorySessionRevisionDeleteStore extends SessionRevisionDeleteStore {
  InMemorySessionRevisionDeleteStore();

  final deletedProtocolIds = <String>[];
  final existingProtocolIds = <String>{};

  @override
  Future<void> deleteRevision(String protocolId) async {
    final normalizedProtocolId = protocolId.trim();
    if (normalizedProtocolId.isEmpty) {
      throw const SessionRevisionDeleteStoreException('protocolId is required.');
    }

    deletedProtocolIds.add(normalizedProtocolId);
    existingProtocolIds.remove(normalizedProtocolId);
  }
}
