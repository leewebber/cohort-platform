/// Immutable JSON prescription metadata. This never turns client data into authority.
Object? freezePrescriptionJson(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map((k, v) => MapEntry(k as String, freezePrescriptionJson(v))),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(freezePrescriptionJson));
  }
  return value;
}
