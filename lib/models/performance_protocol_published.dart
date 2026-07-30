/// Live `performance_protocols.published` is TEXT, not boolean.
///
/// Observed deployed values include `'true'`, `'false'`, and legacy `'No'`.
/// Only the exact text `'true'` counts as published for catalogue policy.
class PerformanceProtocolPublished {
  const PerformanceProtocolPublished._();

  static const String dbTrue = 'true';
  static const String dbFalse = 'false';

  /// Dec / JSON → domain. Accepts JSON bool `true` for local fakes and exact
  /// text `'true'` for the live schema. `'No'`, `'false'`, other text, and
  /// null are unpublished.
  static bool isPublished(dynamic value) {
    if (identical(value, true) || value == true) return true;
    if (value is String) return value == dbTrue;
    return false;
  }

  /// Domain → DB text representation for upserts against the live TEXT column.
  static String toDb(bool published) => published ? dbTrue : dbFalse;
}
