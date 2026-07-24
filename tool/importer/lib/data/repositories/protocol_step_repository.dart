import 'package:founder_importer/runtime/supabase_client_holder.dart';
import 'package:founder_importer/models/protocol_step.dart';

class ProtocolStepRepository {
  const ProtocolStepRepository();

  Future<List<ProtocolStep>> getProtocolSteps(
    String protocolId,
  ) async {
    final response = await SupabaseClientHolder.client
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