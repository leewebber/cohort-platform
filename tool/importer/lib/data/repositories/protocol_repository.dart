
import 'package:founder_importer/runtime/supabase_client_holder.dart';
import 'package:founder_importer/features/protocols/diagnostics/protocol_repository_diagnostics.dart';
import 'package:founder_importer/models/protocol.dart';
import 'package:founder_importer/models/protocol_metadata_update.dart';
import 'package:founder_importer/models/training_content_vocabulary.dart';

class ProtocolRepository {
  static const String catalogTable = 'performance_protocols';

  /// Official published Cohort Protocol catalogue.
  ///
  /// Used by athlete Protocol Library and Programme Builder Cohort picker.
  Future<List<Protocol>> listCohortProtocols({int limit = 100}) async {
    final response = await SupabaseClientHolder.client
        .from(catalogTable)
        .select()
        .eq('content_kind', TrainingContentKind.cohortProtocol.dbValue)
        .eq('authoring_scope', TrainingAuthoringScope.cohortGlobal.dbValue)
        .eq('published', true)
        .order('name')
        .limit(limit);

    final protocols = response
        .map<Protocol>((item) => Protocol.fromMap(item))
        .toList();

    ProtocolRepositoryDiagnostics.log(
      'listCohortProtocols raw=${response.length} mapped=${protocols.length}',
    );

    return protocols;
  }

  /// Coach-authored reusable sessions available in Session Library.
  ///
  /// Filters: `session` + `coach_private` + `owner_id` + `published=true`.
  /// Programme-only and draft Sessions are excluded.
  Future<List<Protocol>> listReusableCoachSessions(
    String ownerId, {
    int limit = 100,
  }) async {
    final trimmedOwnerId = ownerId.trim();
    if (trimmedOwnerId.isEmpty) {
      return const [];
    }

    final response = await SupabaseClientHolder.client
        .from(catalogTable)
        .select()
        .eq('content_kind', TrainingContentKind.session.dbValue)
        .eq('authoring_scope', TrainingAuthoringScope.coachPrivate.dbValue)
        .eq('owner_id', trimmedOwnerId)
        .eq('published', true)
        .order('name')
        .limit(limit);

    return response
        .map<Protocol>((item) => Protocol.fromMap(item))
        .toList();
  }

  /// Coach-authored reusable sessions (`content_kind=session`, `coach_private`).
  Future<List<Protocol>> listCoachSessions(
    String ownerId, {
    int limit = 100,
  }) async {
    final trimmedOwnerId = ownerId.trim();
    if (trimmedOwnerId.isEmpty) {
      return const [];
    }

    final response = await SupabaseClientHolder.client
        .from(catalogTable)
        .select()
        .eq('content_kind', TrainingContentKind.session.dbValue)
        .eq('authoring_scope', TrainingAuthoringScope.coachPrivate.dbValue)
        .eq('owner_id', trimmedOwnerId)
        .order('name')
        .limit(limit);

    return response
        .map<Protocol>((item) => Protocol.fromMap(item))
        .toList();
  }

  /// Programme-only sessions bound to a draft programme version.
  Future<List<Protocol>> listProgrammeSessions(
    String programmeVersionId, {
    int limit = 100,
  }) async {
    final trimmedVersionId = programmeVersionId.trim();
    if (trimmedVersionId.isEmpty) {
      return const [];
    }

    final response = await SupabaseClientHolder.client
        .from(catalogTable)
        .select()
        .eq('content_kind', TrainingContentKind.session.dbValue)
        .eq('authoring_scope', TrainingAuthoringScope.programmeOnly.dbValue)
        .eq('programme_version_id', trimmedVersionId)
        .order('name')
        .limit(limit);

    return response
        .map<Protocol>((item) => Protocol.fromMap(item))
        .toList();
  }

  /// Reusable session templates (`content_kind=session_template`).
  ///
  /// When [ownerId] is provided, scopes to that coach's templates.
  Future<List<Protocol>> listSessionTemplates({
    String? ownerId,
    int limit = 100,
  }) async {
    var query = SupabaseClientHolder.client
        .from(catalogTable)
        .select()
        .eq('content_kind', TrainingContentKind.sessionTemplate.dbValue);

    final trimmedOwnerId = ownerId?.trim();
    if (trimmedOwnerId != null && trimmedOwnerId.isNotEmpty) {
      query = query.eq('owner_id', trimmedOwnerId);
    }

    final response = await query.order('name').limit(limit);

    return response
        .map<Protocol>((item) => Protocol.fromMap(item))
        .toList();
  }

  /// Alias for [listCohortProtocols] — Programme Builder and Protocol Library.
  Future<List<Protocol>> listCatalogProtocols({int limit = 100}) {
    return listCohortProtocols(limit: limit);
  }

  /// Unfiltered table read — admin builder and internal surfaces only.
  Future<List<Protocol>> getProtocols() async {
    final response = await SupabaseClientHolder.client
        .from(catalogTable)
        .select()
        .order('name');

    return response
        .map<Protocol>((item) => Protocol.fromMap(item))
        .toList();
  }

  Future<Protocol?> getProtocolById(String protocolId) async {
    final response = await SupabaseClientHolder.client
        .from(catalogTable)
        .select()
        .eq('protocol_id', protocolId)
        .maybeSingle();

    if (response == null) return null;

    return Protocol.fromMap(response);
  }

  /// Resolves protocol display names for a set of ids in one query.
  Future<Map<String, String>> getProtocolNamesByIds(
    Set<String> protocolIds,
  ) async {
    if (protocolIds.isEmpty) {
      return const {};
    }

    final response = await SupabaseClientHolder.client
        .from(catalogTable)
        .select('protocol_id, name')
        .inFilter('protocol_id', protocolIds.toList());

    final names = <String, String>{};
    for (final row in response) {
      final map = Map<String, dynamic>.from(row);
      final protocolId = map['protocol_id']?.toString().trim();
      final name = map['name']?.toString().trim();
      if (protocolId == null || protocolId.isEmpty) {
        continue;
      }

      names[protocolId] =
          name == null || name.isEmpty ? protocolId : name;
    }

    return names;
  }

  Future<Protocol> updateProtocol({
    required String protocolId,
    required ProtocolMetadataUpdate metadata,
  }) async {
    final response = await SupabaseClientHolder.client
        .from(catalogTable)
        .update(metadata.toUpdateMap())
        .eq('protocol_id', protocolId)
        .select()
        .single();

    return Protocol.fromMap(response);
  }

  Future<List<String>> getGoals() {
    return _getDistinctValues('primary_capability');
  }

  Future<List<String>> getEquipment() {
    return _getDistinctValues('equipment');
  }

  Future<List<String>> getCapabilities() {
    return _getDistinctValues('body_focus');
  }

  Future<List<String>> getDemandLevels() {
    return _getDistinctValues('physiological_demand');
  }

  Future<List<String>> getRecoveryLevels() {
    return _getDistinctValues('recovery_cost');
  }

  Future<List<String>> _getDistinctValues(String column) async {
    final response = await SupabaseClientHolder.client
        .from(catalogTable)
        .select(column)
        .eq('content_kind', TrainingContentKind.cohortProtocol.dbValue)
        .eq('authoring_scope', TrainingAuthoringScope.cohortGlobal.dbValue)
        .eq('published', true);

    final values = response
        .map<String?>((item) => item[column]?.toString())
        .where((value) => value != null && value.trim().isNotEmpty)
        .map((value) => value!.trim())
        .toSet()
        .toList();

    values.sort();

    return values;
  }
}
