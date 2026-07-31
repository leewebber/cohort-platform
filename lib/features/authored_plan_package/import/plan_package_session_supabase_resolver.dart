import 'package:supabase_flutter/supabase_flutter.dart';

import 'plan_package_import_models.dart';
import 'plan_package_session_resolver.dart';

/// Read-only Session Revision lookup for import preview/resolution.
class PlanPackageSessionSupabaseResolver implements PlanPackageSessionResolver {
  PlanPackageSessionSupabaseResolver(this._client);

  final SupabaseClient _client;

  @override
  Future<PlanPackageSessionRevisionRecord?> getRevision(
    String protocolId,
  ) async {
    final normalised = protocolId.trim();
    if (normalised.isEmpty) return null;

    final response = await _client
        .from('performance_protocols')
        .select(
          'protocol_id, session_lineage_id, revision_number, lifecycle_status, content_kind, name',
        )
        .eq('protocol_id', normalised)
        .maybeSingle();

    if (response == null) return null;

    final lineage = response['session_lineage_id']?.toString().trim() ?? '';
    if (lineage.isEmpty) return null;

    final revisionRaw = response['revision_number'];
    final revision = revisionRaw is int
        ? revisionRaw
        : int.tryParse('$revisionRaw') ?? 0;

    return PlanPackageSessionRevisionRecord(
      protocolId: response['protocol_id']?.toString() ?? normalised,
      sessionLineageId: lineage,
      revisionNumber: revision,
      lifecycleStatus: response['lifecycle_status']?.toString() ?? '',
      contentKind: response['content_kind']?.toString(),
      name: response['name']?.toString(),
    );
  }
}
