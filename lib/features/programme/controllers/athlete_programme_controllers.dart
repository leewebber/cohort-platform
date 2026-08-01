import 'package:flutter/foundation.dart';

import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_version_store.dart';
import '../../../models/programme_assignment.dart';
import '../../../models/programme_version.dart';
import '../models/athlete_catalogue_enrolment.dart';
import '../models/athlete_plan_materialisation.dart';
import '../models/programme_catalog_entry.dart';
import '../models/athlete_programme_prepared_session.dart';
import '../services/athlete_catalogue_enrolment_service.dart';
import '../services/athlete_plan_materialisation_service.dart';
import '../services/athlete_programme_session_prepare_service.dart';
import '../services/athlete_programme_switch_catalog_service.dart';

class AthleteProgrammeScreenController extends ChangeNotifier {
  AthleteProgrammeScreenController({
    required String athleteId,
    ProgrammeAssignmentStore? assignmentStore,
    ProgrammeVersionStore? versionStore,
    AthletePlanMaterialisationService? materialisationService,
    AthleteProgrammeSessionPrepareService? prepareService,
  }) : _athleteId = athleteId.trim(),
       _assignmentStore = assignmentStore,
       _versionStore = versionStore,
       _materialisationService = materialisationService,
       _prepareService = prepareService;

  final String _athleteId;
  final ProgrammeAssignmentStore? _assignmentStore;
  final ProgrammeVersionStore? _versionStore;
  final AthletePlanMaterialisationService? _materialisationService;
  final AthleteProgrammeSessionPrepareService? _prepareService;

  bool _loading = true;
  bool _starting = false;
  bool _preparing = false;
  ProgrammeAssignment? _assignment;
  ProgrammeVersion? _version;
  String? _errorMessage;
  AthletePlanMaterialisationResult? _lastMaterialisationResult;
  AthleteProgrammePrepareResult? _lastPrepareResult;

  bool get isLoading => _loading;
  bool get isStarting => _starting;
  bool get isPreparing => _preparing;
  ProgrammeAssignment? get activeAssignment => _assignment;
  ProgrammeVersion? get activeVersion => _version;
  String? get errorMessage => _errorMessage;
  bool get hasActiveProgramme => _assignment != null;
  bool get canStartProgramme => _assignment?.canStartProgramme ?? false;
  bool get isMaterialised => _assignment?.isMaterialised ?? false;
  AthletePlanMaterialisationResult? get lastMaterialisationResult =>
      _lastMaterialisationResult;
  AthleteProgrammePrepareResult? get lastPrepareResult => _lastPrepareResult;

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

  /// Explicit Start Programme — materialises, then prepares the current session.
  Future<AthletePlanMaterialisationResult?> startProgramme({
    String? timezone,
  }) async {
    final assignment = _assignment;
    final service = _materialisationService;
    if (assignment == null || service == null || _starting) return null;
    if (!assignment.canStartProgramme) {
      if (assignment.isMaterialised) {
        final already = AthletePlanMaterialisationResult(
          status: AthletePlanMaterialisationStatus.alreadyMaterialised,
          enrolmentId: assignment.id,
          programmeVersionId: assignment.programmeVersionId,
          lineageCode: assignment.lineageCode,
          materialisedAt: assignment.materialisedAt,
          materialisationSource: assignment.materialisationSource,
          materialisedPackageContentHash:
              assignment.materialisedPackageContentHash,
          materialisedPackageSchemaVersion:
              assignment.materialisedPackageSchemaVersion,
          startedAt: assignment.startedAt,
          timezone: assignment.timezone,
          currentWeek: assignment.currentWeek,
          currentDayKey: assignment.currentDayKey,
          currentSlotOrder: assignment.currentSessionOrder,
          athleteId: assignment.athleteId,
          message: 'This programme is already started.',
        );
        _lastMaterialisationResult = already;
        await prepareCurrentSession();
        notifyListeners();
        return already;
      }
      return null;
    }

    _starting = true;
    _errorMessage = null;
    notifyListeners();

    final result = await service.startProgramme(
      programmeAssignmentId: assignment.id,
      athleteId: _athleteId,
      timezone: timezone ?? assignment.timezone,
    );
    _lastMaterialisationResult = result;

    if (result.isSuccess) {
      await load();
      await prepareCurrentSession();
    } else {
      _errorMessage = result.message;
      _starting = false;
      notifyListeners();
    }

    _starting = false;
    notifyListeners();
    return result;
  }

  /// Idempotent prepare/restore for the materialised assignment cursor.
  Future<AthleteProgrammePrepareResult?> prepareCurrentSession() async {
    final prepare = _prepareService;
    final assignment = _assignment;
    if (prepare == null || assignment == null || !assignment.isMaterialised) {
      return null;
    }
    if (_preparing) return _lastPrepareResult;
    _preparing = true;
    notifyListeners();
    final result = await prepare.prepareForAssignment(assignment);
    _lastPrepareResult = result;
    if (result.isRecoverableFailure) {
      _errorMessage = result.message;
    }
    _preparing = false;
    notifyListeners();
    return result;
  }
}

/// Catalogue browse + enrol controller (Sprint 1.3).
class AthleteProgrammeSelectionController extends ChangeNotifier {
  AthleteProgrammeSelectionController({
    required String athleteId,
    required AthleteProgrammeSwitchCatalogService catalogService,
    required AthleteCatalogueEnrolmentService enrolmentService,
    ProgrammeAssignmentStore? assignmentStore,
  }) : _athleteId = athleteId.trim(),
       _catalogService = catalogService,
       _enrolmentService = enrolmentService,
       _assignmentStore = assignmentStore;

  final String _athleteId;
  final AthleteProgrammeSwitchCatalogService _catalogService;
  final AthleteCatalogueEnrolmentService _enrolmentService;
  final ProgrammeAssignmentStore? _assignmentStore;

  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  List<ProgrammeCatalogEntry> _programmes = const [];
  ProgrammeCatalogEntry? _selected;
  String? _activeVersionId;
  AthleteCatalogueEnrolmentResult? _lastResult;

  bool get isLoading => _loading;
  bool get isSubmitting => _submitting;
  String? get errorMessage => _errorMessage;
  List<ProgrammeCatalogEntry> get programmes => _programmes;
  ProgrammeCatalogEntry? get selectedProgramme => _selected;
  String? get activeVersionId => _activeVersionId;
  AthleteCatalogueEnrolmentResult? get lastEnrolmentResult => _lastResult;

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _lastResult = null;
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
    _selected = entry;
    _errorMessage = null;
    _lastResult = null;
    notifyListeners();
  }

  bool isCurrentProgramme(ProgrammeCatalogEntry entry) {
    return entry.versionId == _activeVersionId;
  }

  /// Enrols in the selected catalogue programme (exact version id).
  Future<AthleteCatalogueEnrolmentResult?> confirmEnrol({
    required DateTime startedAt,
    required String timezone,
    bool replaceActive = false,
  }) async {
    final selected = _selected;
    if (selected == null || _submitting) return null;

    if (selected.versionId == _activeVersionId) {
      final already = AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.alreadyEnrolled,
        programmeVersionId: selected.versionId,
        athleteId: _athleteId,
        message: 'You are already enrolled in this programme.',
      );
      _lastResult = already;
      notifyListeners();
      return already;
    }

    _submitting = true;
    _errorMessage = null;
    notifyListeners();

    final hasActive = _activeVersionId != null && _activeVersionId!.isNotEmpty;
    final result = await _enrolmentService.enrol(
      athleteId: _athleteId,
      programmeVersionId: selected.versionId,
      timezone: timezone,
      replaceActive: replaceActive || hasActive,
    );

    _lastResult = result;
    if (result.isSuccess) {
      _activeVersionId = result.programmeVersionId ?? selected.versionId;
    } else if (result.status != AthleteCatalogueEnrolmentStatus.conflict) {
      _errorMessage = result.message;
    }

    _submitting = false;
    notifyListeners();
    return result;
  }
}
