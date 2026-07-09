/// Locked protocol metadata vocabulary.
///
/// Source of truth: 07 Documentation/20_Protocol_Metadata_Standard.md
class ProtocolMetadataVocabulary {
  ProtocolMetadataVocabulary._();

  static const primaryCapabilities = [
    'Capacity',
    'Engine',
    'Hypertrophy',
    'Mobility',
    'Recovery',
    'Speed',
    'Strength',
    'Threshold',
  ];

  static const sessionTypes = [
    'AMRAP',
    'Benchmark',
    'Circuit',
    'Conditioning',
    'EMOM',
    'Hybrid',
    'Hypertrophy',
    'Intervals',
    'Recovery',
    'Running',
    'Strength',
  ];

  static const environments = [
    'Anywhere',
    'Home',
    'Hotel Gym',
    'Gym',
    'Outdoor',
    'Track',
    'Trail',
    'Full Gym',
  ];

  static const physiologicalDemands = [
    'Very Low',
    'Low',
    'Moderate',
    'High',
    'Very High',
  ];

  static const recoveryCosts = [
    'Very Low',
    'Low',
    'Moderate',
    'High',
    'Very High',
  ];

  static const durationCategories = [
    'Short',
    'Medium',
    'Long',
  ];

  static const technicalComplexities = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  static const equipment = [
    'Bodyweight',
    'Minimal Kit',
    'Dumbbell',
    'Barbell',
    'Bench',
    'Kettlebell',
    'Sandbag',
    'Pull-up Bar',
    'Wall Ball',
    'Bike',
    'Bike Erg',
    'Row Erg',
    'Ski Erg',
    'Running Shoes',
    'Full Gym',
  ];

  static const suitableFor = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'General Fitness',
    'HYROX',
    'Tactical',
    'Endurance',
    'Strength',
    'Masters',
    'Travel',
  ];

  static const adaptabilityLevels = [1, 2, 3, 4, 5];

  static List<String> secondaryCapabilityOptionsWithCurrent(String? current) {
    return optionsWithCurrent(current, primaryCapabilities);
  }

  static List<String> requiredEquipmentOptionsWithCurrent(String? current) {
    return multiSelectOptionsWithCurrent(current, equipment);
  }

  static List<String> optionalEquipmentOptionsWithCurrent(String? current) {
    return multiSelectOptionsWithCurrent(current, equipment);
  }

  static List<int> adaptabilityOptionsWithCurrent(int? current) {
    if (current == null || adaptabilityLevels.contains(current)) {
      return adaptabilityLevels;
    }

    return [current, ...adaptabilityLevels];
  }

  static Set<String> parseCommaSeparated(String? value) {
    if (value == null || value.trim().isEmpty) {
      return {};
    }

    return value
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet();
  }

  static List<String> multiSelectOptionsWithCurrent(
    String? current,
    List<String> vocabulary,
  ) {
    final selected = parseCommaSeparated(current);
    final options = List<String>.from(vocabulary);

    for (final item in selected) {
      if (!options.contains(item)) {
        options.add(item);
      }
    }

    return options;
  }

  static List<String> equipmentOptionsWithCurrent(String? current) {
    return multiSelectOptionsWithCurrent(current, equipment);
  }

  static List<String> suitableForOptionsWithCurrent(String? current) {
    return multiSelectOptionsWithCurrent(current, suitableFor);
  }

  static String? formatCommaSeparated(
    Set<String> values,
    List<String> vocabulary,
  ) {
    if (values.isEmpty) {
      return null;
    }

    final ordered = vocabulary.where(values.contains).toList();
    final legacy =
        values.where((value) => !vocabulary.contains(value)).toList()..sort();

    return [...ordered, ...legacy].join(', ');
  }

  static List<String> optionsWithCurrent(
    String? current,
    List<String> locked,
  ) {
    if (current == null || current.trim().isEmpty) {
      return locked;
    }

    if (locked.contains(current)) {
      return locked;
    }

    return [current, ...locked];
  }
}
