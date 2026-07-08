import '../../core/services/supabase_service.dart';
import '../../models/protocol_step.dart';

class ProtocolStepRepository {
  const ProtocolStepRepository();

  Future<List<ProtocolStep>> getProtocolSteps(
    String protocolId,
  ) async {
    final response = await SupabaseService.client
        .from('protocol_steps')
        .select()
        .eq('protocol_id', protocolId)
        .order(
          'step_order',
          ascending: true,
        );

    return response
        .map<ProtocolStep>(
          (row) => ProtocolStep.fromMap(row),
        )
        .toList();
  }
}