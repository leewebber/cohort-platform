import 'package:cohort_platform/domain/adaptation/vocabulary/training_environment.dart';
import 'package:cohort_platform/models/adaptation_session_environment.dart';

/// Maps athlete questionnaire environments into canonical [TrainingEnvironment].
TrainingEnvironment mapAdaptationSessionEnvironmentToTrainingEnvironment(
  AdaptationSessionEnvironment environment,
) {
  return switch (environment) {
    AdaptationSessionEnvironment.home => TrainingEnvironment.home,
    AdaptationSessionEnvironment.hotelRoom => TrainingEnvironment.hotelRoom,
    AdaptationSessionEnvironment.hotelGym => TrainingEnvironment.hotelGym,
    AdaptationSessionEnvironment.commercialGym =>
      TrainingEnvironment.commercialGym,
    AdaptationSessionEnvironment.outdoors => TrainingEnvironment.outdoors,
  };
}
