enum AdaptationSessionEnvironment {
  home,
  hotelRoom,
  hotelGym,
  commercialGym,
  outdoors,
}

extension AdaptationSessionEnvironmentLabel on AdaptationSessionEnvironment {
  String get label {
    switch (this) {
      case AdaptationSessionEnvironment.home:
        return 'Home';
      case AdaptationSessionEnvironment.hotelRoom:
        return 'Hotel Room';
      case AdaptationSessionEnvironment.hotelGym:
        return 'Hotel Gym';
      case AdaptationSessionEnvironment.commercialGym:
        return 'Commercial Gym';
      case AdaptationSessionEnvironment.outdoors:
        return 'Outdoors';
    }
  }
}
