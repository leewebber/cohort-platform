/// Resolves protocol display names for programme editor preview and publish.
abstract class ProgrammeBuilderProtocolNameResolver {
  Future<Map<String, String>> resolveNames(Set<String> protocolIds);
}
