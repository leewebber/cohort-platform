import '../../core/services/supabase_service.dart';
import '../../models/protocol.dart';
import '../../models/protocol_metadata_update.dart';

class ProtocolRepository {
  Future<List<Protocol>> getProtocols() async {
    final response = await SupabaseService.client
        .from('performance_protocols')
        .select()
        .order('name');

    return response
        .map<Protocol>((item) => Protocol.fromMap(item))
        .toList();
  }

  Future<Protocol?> getProtocolById(String protocolId) async {
    final response = await SupabaseService.client
        .from('performance_protocols')
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

    final response = await SupabaseService.client
        .from('performance_protocols')
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
    final response = await SupabaseService.client
        .from('performance_protocols')
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
    final response = await SupabaseService.client
        .from('performance_protocols')
        .select(column);

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