/// Programme Builder persistence and authoring constants.
class ProgrammeBuilderConstants {
  ProgrammeBuilderConstants._();

  /// Placeholder stored in Supabase for slots awaiting protocol assignment.
  static const unassignedProtocolId = '__UNASSIGNED__';

  static bool isUnassignedProtocolId(String protocolId) {
    final trimmed = protocolId.trim();
    return trimmed.isEmpty || trimmed == unassignedProtocolId;
  }
}
