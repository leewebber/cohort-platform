/// Reusable equipment facts for an exercise definition.
///
/// Whether a session may substitute equipment is programme context, not stored
/// here as an authorisation.
class EquipmentRequirement {
  const EquipmentRequirement({
    this.requiredTokens = const [],
    this.optionalTokens = const [],
    this.oneOfGroups = const [],
    this.supportsExternalLoad = false,
    this.notes,
  });

  /// Stable equipment tokens (e.g. `barbell`, `dumbbell`, `ski_erg`).
  final List<String> requiredTokens;

  final List<String> optionalTokens;

  /// Each inner list is a one-of group (exactly one member satisfies).
  final List<List<String>> oneOfGroups;

  /// Whether the definition can accept external load when equipment allows.
  final bool supportsExternalLoad;

  final String? notes;

  Map<String, Object?> toJson() => {
        'required_tokens': requiredTokens,
        'optional_tokens': optionalTokens,
        'one_of_groups': oneOfGroups,
        'supports_external_load': supportsExternalLoad,
        if (notes != null) 'notes': notes,
      };

  factory EquipmentRequirement.fromJson(Map<String, Object?> json) {
    final oneOfRaw = json['one_of_groups'];
    final oneOf = <List<String>>[];
    if (oneOfRaw is List) {
      for (final group in oneOfRaw) {
        if (group is List) {
          oneOf.add(group.map((e) => e.toString()).toList(growable: false));
        }
      }
    }
    return EquipmentRequirement(
      requiredTokens: _stringList(json['required_tokens']),
      optionalTokens: _stringList(json['optional_tokens']),
      oneOfGroups: oneOf,
      supportsExternalLoad: json['supports_external_load'] == true,
      notes: json['notes']?.toString(),
    );
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList(growable: false);
}
