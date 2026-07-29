/// Where training can occur — superset of athlete questionnaire + protocol metadata.
enum TrainingEnvironment {
  home,
  hotelRoom,
  hotelGym,
  commercialGym,
  fullGym,
  outdoors,
  track,
  trail,
  anywhere,
}

extension TrainingEnvironmentDb on TrainingEnvironment {
  String get dbValue {
    return switch (this) {
      TrainingEnvironment.home => 'home',
      TrainingEnvironment.hotelRoom => 'hotel_room',
      TrainingEnvironment.hotelGym => 'hotel_gym',
      TrainingEnvironment.commercialGym => 'commercial_gym',
      TrainingEnvironment.fullGym => 'full_gym',
      TrainingEnvironment.outdoors => 'outdoors',
      TrainingEnvironment.track => 'track',
      TrainingEnvironment.trail => 'trail',
      TrainingEnvironment.anywhere => 'anywhere',
    };
  }

  static TrainingEnvironment? fromDb(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
    for (final env in TrainingEnvironment.values) {
      if (env.dbValue == normalized) return env;
    }
    return null;
  }
}
