import 'package:cohort_platform/domain/adaptation/vocabulary/training_environment.dart';
import 'package:cohort_platform/application/adaptation/adaptation_application.dart';
import 'package:cohort_platform/domain/adaptation/adaptation_domain.dart';
import 'package:cohort_platform/models/adaptation_reason.dart';
import 'package:cohort_platform/models/adaptation_request.dart';
import 'package:cohort_platform/models/recovery_state.dart';

import 'adaptation_training_environment_adapter.dart';

/// Maps athlete [AdaptationRequest] questionnaire output to domain constraints.
class AdaptationRequestConstraintMapper {
  const AdaptationRequestConstraintMapper._();

  static AdaptationConstraintContext fromRequest(AdaptationRequest request) {
    final mapped = AdaptationReasonMapping.constraintsFromRequest(request);

    int? availableDurationMin;
    Set<String> availableEquipment = {};
    TrainingEnvironment? trainingEnvironment;
    String? recoveryStateLabel;

    for (final constraint in mapped) {
      if (constraint.availableMinutes != null) {
        availableDurationMin = constraint.availableMinutes;
      }
      if (constraint.availableEquipment.isNotEmpty) {
        availableEquipment = Set<String>.from(constraint.availableEquipment);
      }
      if (constraint.trainingEnvironment != null) {
        trainingEnvironment = TrainingEnvironmentDb.fromDb(
          constraint.trainingEnvironment,
        );
      }
      if (constraint.recoveryStateLabel != null) {
        recoveryStateLabel = constraint.recoveryStateLabel;
      }
    }

    if (request.reason == AdaptationReason.time &&
        request.availableMinutes != null) {
      availableDurationMin = request.availableMinutes;
    }
    if (request.reason == AdaptationReason.equipment) {
      availableEquipment = Set<String>.from(request.availableEquipment ?? {});
    }
    if (request.reason == AdaptationReason.environment &&
        request.environment != null) {
      trainingEnvironment =
          mapAdaptationSessionEnvironmentToTrainingEnvironment(
            request.environment!,
          );
    }
    if (request.reason == AdaptationReason.recovery) {
      recoveryStateLabel = request.recoveryState?.label;
    }

    return AdaptationConstraintContext(
      availableDurationMin: availableDurationMin,
      availableEquipment: availableEquipment,
      trainingEnvironment: trainingEnvironment,
      recoveryStateLabel: recoveryStateLabel,
      extensions: mapped.toSet(),
    );
  }
}
