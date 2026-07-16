/// Suggests a lineage code from a programme name.
String suggestLineageCode(String programmeName) {
  final normalized = programmeName
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');

  if (normalized.isEmpty) {
    return 'COHORT-PROGRAMME';
  }

  if (RegExp(r'^[A-Z0-9][A-Z0-9-]{2,}$').hasMatch(normalized)) {
    return normalized;
  }

  return 'COHORT-$normalized';
}
