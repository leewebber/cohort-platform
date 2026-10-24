class TrustedImportServerConfig {
  static const productionSupabaseHost = 'otnhhdxstdnwccehacku.supabase.co';

  const TrustedImportServerConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabaseServiceRoleKey,
    required this.founderEmails,
    this.bindAddress = '127.0.0.1',
    this.port = 8080,
    this.maxYamlBytes = 1024 * 1024,
    this.publicationEventsUrl,
    this.publicationEventsCredential,
    this.exerciseProducerCredential,
  });

  final Uri supabaseUrl;
  final String supabaseAnonKey;
  final String supabaseServiceRoleKey;
  final Set<String> founderEmails;
  final String bindAddress;
  final int port;
  final int maxYamlBytes;
  final Uri? publicationEventsUrl;
  final String? publicationEventsCredential;
  final String? exerciseProducerCredential;

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
        url.path != '' && url.path != '/' ||
        url.hasQuery ||
        url.hasFragment ||
        (url.scheme != 'https' &&
            !(url.scheme == 'http' &&
                (url.host == 'localhost' || url.host == '127.0.0.1')))) {
      throw StateError('SUPABASE_URL is malformed.');
    }
    if (url.scheme == 'https' && url.host != productionSupabaseHost) {
      throw StateError('SUPABASE_URL does not identify Cohort Field Manual.');
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

    final flag = environment['TRUSTED_V3_PUBLICATION_ENABLED'] ?? 'false';
    if (flag != 'true' && flag != 'false') {
      throw StateError('Invalid v3 enablement configuration.');
    }
    Uri? eventUrl;
    String? eventCredential;
    String? producerCredential;
    if (flag == 'true') {
      eventUrl = Uri.tryParse(requireValue('PUBLICATION_EVENT_SOURCE_URL'));
      if (eventUrl == null ||
          eventUrl.host.isEmpty ||
          eventUrl.userInfo.isNotEmpty ||
          eventUrl.hasQuery ||
          eventUrl.hasFragment ||
          !eventUrl.path.endsWith('/') ||
          !(eventUrl.scheme == 'https' ||
              eventUrl.scheme == 'http' &&
                  {'localhost', '127.0.0.1'}.contains(eventUrl.host))) {
        throw StateError('Invalid trusted publication event source URL.');
      }
      eventCredential = requireValue('PUBLICATION_EVENT_SOURCE_TOKEN');
      producerCredential = requireValue('EXERCISE_VERSION_PRODUCER_TOKEN');
      if (producerCredential == requireValue('SUPABASE_SERVICE_ROLE_KEY')) {
        throw StateError(
          'Exercise producer must not use ordinary service credentials.',
        );
      }
    }
    return TrustedImportServerConfig(
      publicationEventsUrl: eventUrl,
      publicationEventsCredential: eventCredential,
      exerciseProducerCredential: producerCredential,
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
