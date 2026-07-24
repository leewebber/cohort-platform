/// Debug logging flag for the founder importer CLI (replaces Flutter [kDebugMode]).
const bool kDebugMode = bool.fromEnvironment(
  'FOUNDER_IMPORTER_DEBUG',
  defaultValue: false,
);
