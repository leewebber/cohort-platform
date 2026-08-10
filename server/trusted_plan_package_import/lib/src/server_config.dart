class TrustedImportServerConfig {
  const TrustedImportServerConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabaseServiceRoleKey,
    required this.founderEmails,
    this.bindAddress = '127.0.0.1',
    this.port = 8080,
    this.maxYamlBytes = 1024 * 1024,
  });

  final Uri supabaseUrl;
  final String supabaseAnonKey;
  final String supabaseServiceRoleKey;
  final Set<String> founderEmails;
  final String bindAddress;
  final int port;
  final int maxYamlBytes;

  factory TrustedImportServerConfig.fromEnvironment(
    Map<String, String> environment,
  ) {
    String requireValue(String name) {
      final value = environment[name]?.trim();
      if (value == null || value.isEmpty) {
        throw StateError('Required server configuration is missing: $name');
      }
      return value;
    }

    final url = Uri.tryParse(requireValue('SUPABASE_URL'));
    if (url == null ||
        !url.hasScheme ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty ||
        (url.scheme != 'https' &&
            !(url.scheme == 'http' &&
                (url.host == 'localhost' || url.host == '127.0.0.1')))) {
      throw StateError('SUPABASE_URL is malformed.');
    }

    final founderEmails = requireValue('FOUNDER_EMAIL_ALLOWLIST')
        .split(',')
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (founderEmails.isEmpty) {
      throw StateError('FOUNDER_EMAIL_ALLOWLIST must not be empty.');
    }

    final port = int.tryParse(environment['PORT']?.trim() ?? '') ?? 8080;
    final maxYamlBytes =
        int.tryParse(
          environment['MAX_PLAN_PACKAGE_YAML_BYTES']?.trim() ?? '',
        ) ??
        1024 * 1024;
    if (port < 1 || port > 65535 || maxYamlBytes < 1) {
      throw StateError('Numeric server configuration is malformed.');
    }

    return TrustedImportServerConfig(
      supabaseUrl: url,
      supabaseAnonKey: requireValue('SUPABASE_ANON_KEY'),
      supabaseServiceRoleKey: requireValue('SUPABASE_SERVICE_ROLE_KEY'),
      founderEmails: founderEmails,
      bindAddress: environment['BIND_ADDRESS']?.trim().isNotEmpty == true
          ? environment['BIND_ADDRESS']!.trim()
          : '127.0.0.1',
      port: port,
      maxYamlBytes: maxYamlBytes,
    );
  }
}
