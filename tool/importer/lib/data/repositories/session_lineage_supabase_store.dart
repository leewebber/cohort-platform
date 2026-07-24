import 'package:founder_importer/runtime/supabase_client_holder.dart';
import 'package:founder_importer/core/utils/database_uuid.dart';
import 'package:founder_importer/features/session_revision/models/session_revision_usage_models.dart';
import 'package:founder_importer/models/session_lineage.dart';
import 'package:founder_importer/models/session_revision_vocabulary.dart';
import 'package:founder_importer/data/repositories/session_lineage_store.dart';

class SessionLineageSupabaseStore extends SessionLineageStore {
  const SessionLineageSupabaseStore();

  static const _lineagesTable = 'session_lineages';
  static const _protocolsTable = 'performance_protocols';

  @override
  Future<SessionLineage> insertLineage({
    required String displayName,
    String? id,
  }) async {
    final payload = <String, dynamic>{
      'display_name': displayName.trim(),
    };
    if (id != null && id.isNotEmpty) {
      payload['id'] = id;
    }

    final response = await SupabaseClientHolder.client
        .from(_lineagesTable)
        .insert(payload)
        .select()
        .single();

    return SessionLineage.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<SessionLineage?> getLineageById(String lineageId) async {
    final response = await SupabaseClientHolder.client
        .from(_lineagesTable)
        .select()
        .eq('id', lineageId.trim())
        .maybeSingle();

    if (response == null) return null;
    return SessionLineage.fromMap(Map<String, dynamic>.from(response));
  }

  @override
  Future<int> getMaxRevisionNumber(String lineageId) async {
    final response = await SupabaseClientHolder.client
        .from(_protocolsTable)
        .select('revision_number')
        .eq('session_lineage_id', lineageId.trim())
        .order('revision_number', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return 0;
    return response['revision_number'] as int? ?? 0;
  }

  @override
  Future<SessionRevisionLifecycleStatus?> getRevisionLifecycleStatus(
    String protocolId,
  ) async {
    final response = await SupabaseClientHolder.client
        .from(_protocolsTable)
        .select('lifecycle_status')
        .eq('protocol_id', protocolId.trim())
        .maybeSingle();

    if (response == null) return null;
    return SessionRevisionLifecycleStatusDb.fromDb(
      response['lifecycle_status']?.toString(),
    );
  }

  @override
  Future<String?> getLineageIdForRevision(String protocolId) async {
    final response = await SupabaseClientHolder.client
        .from(_protocolsTable)
        .select('session_lineage_id')
        .eq('protocol_id', protocolId.trim())
        .maybeSingle();

    return response?['session_lineage_id']?.toString();
  }

  @override
  Future<SessionRevisionIdentity?> getRevisionIdentity(String protocolId) async {
    final response = await SupabaseClientHolder.client
        .from(_protocolsTable)
        .select('protocol_id, session_lineage_id, revision_number')
        .eq('protocol_id', protocolId.trim())
        .maybeSingle();

    if (response == null) return null;

    final lineageId = response['session_lineage_id']?.toString().trim();
    if (lineageId == null || lineageId.isEmpty) return null;

    return SessionRevisionIdentity(
      protocolId: response['protocol_id']?.toString() ?? protocolId.trim(),
      sessionLineageId: lineageId,
      revisionNumber: response['revision_number'] is int
          ? response['revision_number'] as int
          : int.tryParse(response['revision_number']?.toString() ?? '') ?? 1,
    );
  }

  @override
  Future<void> updateRevisionLifecycle({
    required String protocolId,
    required SessionRevisionLifecycleStatus lifecycleStatus,
    DateTime? publishedAt,
    DateTime? archivedAt,
  }) async {
    final updateMap = <String, dynamic>{
      'lifecycle_status': lifecycleStatus.dbValue,
      'published': lifecycleStatus == SessionRevisionLifecycleStatus.published,
    };

    if (publishedAt != null) {
      updateMap['published_at'] = publishedAt.toIso8601String();
    }
    if (archivedAt != null) {
      updateMap['archived_at'] = archivedAt.toIso8601String();
    }

    await SupabaseClientHolder.client
        .from(_protocolsTable)
        .update(updateMap)
        .eq('protocol_id', protocolId.trim());
  }

  @override
  Future<void> assignRevisionLineage({
    required String protocolId,
    required String sessionLineageId,
    required int revisionNumber,
    required SessionRevisionLifecycleStatus lifecycleStatus,
    DateTime? publishedAt,
  }) async {
    await SupabaseClientHolder.client.from(_protocolsTable).update({
      'session_lineage_id': sessionLineageId,
      'revision_number': revisionNumber,
      'lifecycle_status': lifecycleStatus.dbValue,
      'published': lifecycleStatus == SessionRevisionLifecycleStatus.published,
      if (publishedAt != null) 'published_at': publishedAt.toIso8601String(),
    }).eq('protocol_id', protocolId.trim());
  }
}

/// Generates deterministic lineage ids for tests when needed.
String newSessionLineageId() => DatabaseUuid.newV4();
