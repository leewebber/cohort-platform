import '../../core/services/supabase_service.dart';
import '../../models/protocol.dart';

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