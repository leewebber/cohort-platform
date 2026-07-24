import 'package:flutter/foundation.dart';

import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_version.dart';
import '../models/athlete_programme_switch_result.dart';
import '../models/programme_catalog_entry.dart';
import '../services/athlete_programme_switch_catalog_service.dart';
import '../services/athlete_programme_switch_coordinator.dart';

class AthleteProgrammeScreenController extends ChangeNotifier {
  AthleteProgrammeScreenController({
    required String athleteId,
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeVersionStore? versionStore,
  })  : _athleteId = athleteId.trim(),
        _assignmentStore = assignmentStore,
        _versionStore = versionStore;

  final String _athleteId;
  final ProgrammeAssignmentStore? _assignmentStore;
  final ProgrammeVersionStore? _versionStore;

  bool _loading = true;
  ProgrammeAssignment? _assignment;
  ProgrammeVersion? _version;
  String? _errorMessage;

  bool get isLoading => _loading;
  ProgrammeAssignment? get activeAssignment => _assignment;
  ProgrammeVersion? get activeVersion => _version;
  String? get errorMessage => _errorMessage;
  bool get hasActiveProgramme => _assignment != null;

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    final assignmentStore = _assignmentStore;
    final versionStore = _versionStore;
    if (assignmentStore == null || versionStore == null) {
      _errorMessage = 'Programme data is unavailable.';
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final assignment = await assignmentStore.getActiveAssignment(_athleteId);
      ProgrammeVersion? version;
      if (assignment != null) {
        version = await versionStore.getVersionById(
          assignment.programmeVersionId,
        );
      }
      _assignment = assignment;
      _version = version;
    } catch (error) {
      _errorMessage = error.toString();
    }

    _loading = false;
    notifyListeners();
  }
}

class AthleteProgrammeSelectionController extends ChangeNotifier {
  AthleteProgrammeSelectionController({
    required String athleteId,
    required AthleteProgrammeSwitchCatalogService catalogService,
    required AthleteProgrammeSwitchCoordinator switchCoordinator,
    ProgrammeAssignmentStore? assignmentStore,
  })  : _athleteId = athleteId.trim(),
        _catalogService = catalogService,
        _switchCoordinator = switchCoordinator,
        _assignmentStore = assignmentStore;

  final String _athleteId;
  final AthleteProgrammeSwitchCatalogService _catalogService;
  final AthleteProgrammeSwitchCoordinator _switchCoordinator;
  final ProgrammeAssignmentStore? _assignmentStore;

  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  List<ProgrammeCatalogEntry> _programmes = const [];
  ProgrammeCatalogEntry? _selected;
  String? _activeVersionId;

  bool get isLoading => _loading;
  bool get isSubmitting => _submitting;
  String? get errorMessage => _errorMessage;
  List<ProgrammeCatalogEntry> get programmes => _programmes;
  ProgrammeCatalogEntry? get selectedProgramme => _selected;
  String? get activeVersionId => _activeVersionId;

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final assignmentStore = _assignmentStore;
      if (assignmentStore != null) {
        final active = await assignmentStore.getActiveAssignment(_athleteId);
        _activeVersionId = active?.programmeVersionId;
      }
      _programmes = await _catalogService.listPublishedAssignableProgrammes();
    } catch (error) {
      _errorMessage = error.toString();
    }

    _loading = false;
    notifyListeners();
  }

  void selectProgramme(ProgrammeCatalogEntry entry) {
    if (entry.versionId == _activeVersionId) return;
    _selected = entry;
    _errorMessage = null;
    notifyListeners();
  }

  bool isCurrentProgramme(ProgrammeCatalogEntry entry) {
    return entry.versionId == _activeVersionId;
  }

  Future<AthleteProgrammeSwitchResult?> confirmSwitch({
    required DateTime startedAt,
    required String timezone,
  }) async {
    final selected = _selected;
    if (selected == null || _submitting) return null;

    if (selected.versionId == _activeVersionId) {
      return AthleteProgrammeSwitchResult.alreadyActive();
    }

    _submitting = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _switchCoordinator.switchToProgramme(
      athleteId: _athleteId,
      programmeVersionId: selected.versionId,
      startedAt: startedAt,
      timezone: timezone,
    );

    if (!result.isSuccess && result.status != AthleteProgrammeSwitchStatus.alreadyActive) {
      _errorMessage = result.message;
    }

    _submitting = false;
    notifyListeners();
    return result;
  }
}
