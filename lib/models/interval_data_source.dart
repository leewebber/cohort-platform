/// Origin of actual performance values on an interval rep entry.
///
/// See `07 Documentation/37_Interval_Execution_Engine.md`.
enum IntervalDataSource {
  manual('manual'),
  importedGarmin('imported_garmin'),
  importedStrava('imported_strava'),
  importedAppleHealth('imported_apple_health'),
  other('other');

  const IntervalDataSource(this.dbValue);

  /// Stable vocabulary for future persistence and import pipelines.
  final String dbValue;

  static IntervalDataSource fromDb(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return IntervalDataSource.manual;
    }

    for (final source in IntervalDataSource.values) {
      if (source.dbValue == normalized || source.name == normalized) {
        return source;
      }
    }

    return IntervalDataSource.other;
  }

  bool get isImported => switch (this) {
        IntervalDataSource.manual => false,
        IntervalDataSource.other => false,
        IntervalDataSource.importedGarmin ||
        IntervalDataSource.importedStrava ||
        IntervalDataSource.importedAppleHealth =>
          true,
      };
}
