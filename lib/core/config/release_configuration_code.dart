/// Developer-safe configuration failure codes. Never include secrets.
enum ReleaseConfigurationCode {
  missingEnvironment,
  missingUrl,
  malformedUrl,
  placeholderHost,
  productionScheme,
  productionHost,
  previewScheme,
  previewHost,
  previewLan,
  developmentEndpoint,
  missingKey,
  placeholderKey,
  malformedKey,
  privilegedKey;

  String get name => switch (this) {
    ReleaseConfigurationCode.missingEnvironment => 'CFG_ENV_MISSING',
    ReleaseConfigurationCode.missingUrl => 'CFG_URL_MISSING',
    ReleaseConfigurationCode.malformedUrl => 'CFG_URL_MALFORMED',
    ReleaseConfigurationCode.placeholderHost => 'CFG_HOST_PLACEHOLDER',
    ReleaseConfigurationCode.productionScheme => 'CFG_PROD_SCHEME',
    ReleaseConfigurationCode.productionHost => 'CFG_PROD_HOST',
    ReleaseConfigurationCode.previewScheme => 'CFG_PREVIEW_SCHEME',
    ReleaseConfigurationCode.previewHost => 'CFG_PREVIEW_HOST',
    ReleaseConfigurationCode.previewLan => 'CFG_PREVIEW_LAN',
    ReleaseConfigurationCode.developmentEndpoint => 'CFG_DEV_ENDPOINT',
    ReleaseConfigurationCode.missingKey => 'CFG_KEY_MISSING',
    ReleaseConfigurationCode.placeholderKey => 'CFG_KEY_PLACEHOLDER',
    ReleaseConfigurationCode.malformedKey => 'CFG_KEY_MALFORMED',
    ReleaseConfigurationCode.privilegedKey => 'CFG_KEY_PRIVILEGED',
  };
}
