import 'package:flutter/foundation.dart';

import '../../programme/models/programme_catalog_entry.dart';
import '../../../models/programme_assignment.dart';
import '../services/personal_training_setup_service.dart';

enum PersonalTrainingSetupStatus {
  loading,
  ready,
  empty,
  error,
  assigning,
}

class PersonalTrainingSetupController extends ChangeNotifier {
  PersonalTrainingSetupController({
    required PersonalTrainingSetupService service,
  }) : _service = service;

  final PersonalTrainingSetupService _service;

  PersonalTrainingSetupStatus status = PersonalTrainingSetupStatus.loading;
  String? errorMessage;
  List<ProgrammeCatalogEntry> programmes = const [];
  ProgrammeCatalogEntry? selectedProgramme;
  ProgrammeAssignment? currentAssignment;
  bool hasActiveAssignment = false;
  String? successMessage;

  Future<void> load() async {
    status = PersonalTrainingSetupStatus.loading;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    if (!_service.canSetupPersonalTraining) {
      status = PersonalTrainingSetupStatus.error;
      errorMessage =
          'Coach and athlete roles are required to set up personal training.';
      notifyListeners();
      return;
    }

    final assignmentResult = await _service.getCurrentAssignment();
    if (!assignmentResult.isSuccess) {
      status = PersonalTrainingSetupStatus.error;
      errorMessage = assignmentResult.message;
      notifyListeners();
      return;
    }

    currentAssignment = assignmentResult.value;
    hasActiveAssignment = currentAssignment != null;

    final catalogueResult = await _service.listPublishedProgrammes();
    if (!catalogueResult.isSuccess) {
      status = PersonalTrainingSetupStatus.error;
      errorMessage = catalogueResult.message;
      notifyListeners();
      return;
    }

    programmes = catalogueResult.value ?? const [];
    selectedProgramme = programmes.isNotEmpty ? programmes.first : null;
    status = programmes.isEmpty
        ? PersonalTrainingSetupStatus.empty
        : PersonalTrainingSetupStatus.ready;
    notifyListeners();
  }

  void selectProgramme(ProgrammeCatalogEntry entry) {
    selectedProgramme = entry;
    notifyListeners();
  }

  Future<bool> assignSelected({
    required DateTime startDate,
    required String timezone,
    required bool replaceExisting,
  }) async {
    final entry = selectedProgramme;
    if (entry == null) return false;

    status = PersonalTrainingSetupStatus.assigning;
    errorMessage = null;
    successMessage = null;
    notifyListeners();

    final result = await _service.assignProgrammeToSelf(
      programmeVersionId: entry.versionId,
      startedAt: startDate,
      timezone: timezone,
      replaceExistingActive: replaceExisting,
    );

    if (!result.isSuccess) {
      status = PersonalTrainingSetupStatus.ready;
      errorMessage = result.message;
      notifyListeners();
      return false;
    }

    currentAssignment = result.value!.assignment;
    hasActiveAssignment = true;
    successMessage = '${entry.name} is now your active programme.';
    status = PersonalTrainingSetupStatus.ready;
    notifyListeners();
    return true;
  }
}
