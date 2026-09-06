import 'app_release_configuration.dart';
import 'endpoint_policy.dart';
import 'release_configuration_code.dart';
import 'supabase_key_policy.dart';

class ReleaseConfigurationResult {
  const ReleaseConfigurationResult._({
    required this.isConfigured,
    this.code,
    this.athleteMessage,
  });

  final bool isConfigured;
  final ReleaseConfigurationCode? code;
  final String? athleteMessage;

  factory ReleaseConfigurationResult.accepted() {
    return const ReleaseConfigurationResult._(isConfigured: true);
  }

  factory ReleaseConfigurationResult.rejected({
    required ReleaseConfigurationCode code,
    required String athleteMessage,
  }) {
    return ReleaseConfigurationResult._(
      isConfigured: false,
      code: code,
      athleteMessage: athleteMessage,
    );
  }

  String get developerCode => code?.name ?? '';
}

class ReleaseConfigurationPolicy {
  const ReleaseConfigurationPolicy({
    EndpointPolicy? endpointPolicy,
    SupabaseKeyPolicy? keyPolicy,
  }) : _endpointPolicy = endpointPolicy ?? const EndpointPolicy(),
       _keyPolicy = keyPolicy ?? const SupabaseKeyPolicy();

  final EndpointPolicy _endpointPolicy;
  final SupabaseKeyPolicy _keyPolicy;

  ReleaseConfigurationResult validate(AppReleaseConfiguration configuration) {
    final environment = configuration.environment;
    if (environment == null) {
      return ReleaseConfigurationResult.rejected(
        code: ReleaseConfigurationCode.missingEnvironment,
        athleteMessage: 'This build has invalid configuration.',
      );
    }

    final endpoint = _endpointPolicy.validate(
      environment: environment,
      rawUrl: configuration.supabaseUrl,
    );
    if (!endpoint.isAccepted) {
      return ReleaseConfigurationResult.rejected(
        code: endpoint.code!,
        athleteMessage: environment.invalidConfigurationMessage,
      );
    }

    final key = _keyPolicy.validate(configuration.supabaseAnonKey);
    if (!key.isAccepted) {
      return ReleaseConfigurationResult.rejected(
        code: key.code!,
        athleteMessage: environment.invalidConfigurationMessage,
      );
    }

    return ReleaseConfigurationResult.accepted();
  }
}
