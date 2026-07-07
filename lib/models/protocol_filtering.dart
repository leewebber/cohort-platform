import 'protocol.dart';
import 'protocol_filters.dart';

List<Protocol> filterProtocols({
  required List<Protocol> protocols,
  required String search,
  required ProtocolFilters filters,
}) {
  final query = search.toLowerCase().trim();

  return protocols.where((protocol) {
    final matchesSearch = query.isEmpty ||
        protocol.name.toLowerCase().contains(query) ||
        protocol.protocolId.toLowerCase().contains(query) ||
        (protocol.goal ?? '').toLowerCase().contains(query) ||
        (protocol.capability ?? '').toLowerCase().contains(query) ||
        (protocol.equipment ?? '').toLowerCase().contains(query);

    final matchesGoal =
        filters.goal == null || protocol.goal == filters.goal;

    final matchesEquipment = filters.equipment == null ||
        (protocol.equipment ?? '').contains(filters.equipment!);

    final matchesCapability =
        filters.capability == null || protocol.capability == filters.capability;

    final matchesDemand =
        filters.demand == null || protocol.demand == filters.demand;

    final matchesRecovery =
        filters.recovery == null || protocol.recovery == filters.recovery;

    return matchesSearch &&
        matchesGoal &&
        matchesEquipment &&
        matchesCapability &&
        matchesDemand &&
        matchesRecovery;
  }).toList();
}