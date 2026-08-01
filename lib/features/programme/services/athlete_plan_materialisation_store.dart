import '../models/athlete_plan_materialisation.dart';

abstract class AthletePlanMaterialisationStore {
  Future<AthletePlanMaterialisationResult> materialise({
    required String programmeAssignmentId,
    String? timezone,
  });
}
