/// Origin of circuit performance values.
///
/// See `07 Documentation/39_Circuit_Execution_Engine.md`.
enum CircuitDataSource {
  manual('manual'),
  importedGarmin('imported_garmin'),
  importedStrava('imported_strava'),
  importedAppleHealth('imported_apple_health'),
  importedCompetition('imported_competition'),
  other('other');

  const CircuitDataSource(this.dbValue);

  final String dbValue;

  static CircuitDataSource fromDb(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return CircuitDataSource.manual;
    }

    for (final source in CircuitDataSource.values) {
      if (source.dbValue == normalized || source.name == normalized) {
        return source;
      }
    }

    return CircuitDataSource.other;
  }

  bool get isImported => switch (this) {
        CircuitDataSource.manual => false,
        CircuitDataSource.other => false,
        CircuitDataSource.importedGarmin ||
        CircuitDataSource.importedStrava ||
        CircuitDataSource.importedAppleHealth ||
        CircuitDataSource.importedCompetition =>
          true,
      };
}
