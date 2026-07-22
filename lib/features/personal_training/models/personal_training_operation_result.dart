import '../../programme/models/programme_catalog_entry.dart';
import '../../../models/programme_assignment.dart';
import '../../coach_athlete/services/coach_athlete_service.dart';

enum PersonalTrainingOperationStatus {
  success,
  notAuthenticated,
  dualRoleRequired,
  coachRoleRequired,
  athleteRoleRequired,
  inaccessibleProgramme,
  failed,
}

class PersonalTrainingOperationResult<T> {
  const PersonalTrainingOperationResult._({
    required this.status,
    this.value,
    this.message,
  });

  final PersonalTrainingOperationStatus status;
  final T? value;
  final String? message;

  bool get isSuccess => status == PersonalTrainingOperationStatus.success;

  factory PersonalTrainingOperationResult.success(T value) {
    return PersonalTrainingOperationResult._(
      status: PersonalTrainingOperationStatus.success,
      value: value,
    );
  }

  factory PersonalTrainingOperationResult.failure({
    required PersonalTrainingOperationStatus status,
    String? message,
  }) {
    return PersonalTrainingOperationResult._(
      status: status,
      message: message,
    );
  }
}

typedef PersonalTrainingAssignmentResult =
    PersonalTrainingOperationResult<ProgrammeAssignmentOperationSummary>;
typedef PersonalTrainingCatalogueResult =
    PersonalTrainingOperationResult<List<ProgrammeCatalogEntry>>;
typedef PersonalTrainingCurrentAssignmentResult =
    PersonalTrainingOperationResult<ProgrammeAssignment?>;
