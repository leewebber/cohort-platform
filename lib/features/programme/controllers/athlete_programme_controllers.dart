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
    this.assignmentStore,
    this.versionStore,
    this.materialisationService,
    this.prepareService,
  }) : _athleteId = athleteId.trim();

  final String _athleteId;
  final ProgrammeAssignmentStore? assignmentStore;
  final ProgrammeVersionStore? versionStore;
  final AthletePlanMaterialisationService? materialisationService;
  final AthleteProgrammeSessionPrepareService? prepareService;

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

    final assignments = assignmentStore;
    final versions = versionStore;
    if (assignments == null || versions == null) {
      _errorMessage = 'Programme data is unavailable.';
      _loading = false;
      notifyListeners();
      return;
    }

    try {
      final assignment = await assignments.getActiveAssignment(_athleteId);
      ProgrammeVersion? version;
      if (assignment != null) {
        version = await versions.getVersionById(assignment.programmeVersionId);
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
    DateTime? startDate,
  }) async {
    final assignment = _assignment;
    final service = materialisationService;
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
      startDate: startDate ?? assignment.startedAt,
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
    final prepare = prepareService;
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
    required this.catalogService,
    required this.enrolmentService,
    this.assignmentStore,
  }) : _athleteId = athleteId.trim();

  final String _athleteId;
  final AthleteProgrammeSwitchCatalogService catalogService;
  final AthleteCatalogueEnrolmentService enrolmentService;
  final ProgrammeAssignmentStore? assignmentStore;

  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  List<ProgrammeCatalogEntry> _programmes = const [];
  ProgrammeCatalogEntry? _selected;
  String? _activeVersionId;
  AthleteCatalogueEnrolmentResult? _lastResult;
  final List<String> _comparisonVersionIds = [];

  bool get isLoading => _loading;
  bool get isSubmitting => _submitting;
  String? get errorMessage => _errorMessage;
  List<ProgrammeCatalogEntry> get programmes => _programmes;
  ProgrammeCatalogEntry? get selectedProgramme => _selected;
  String? get activeVersionId => _activeVersionId;
  AthleteCatalogueEnrolmentResult? get lastEnrolmentResult => _lastResult;
  bool get hasActiveAssignment =>
      _activeVersionId != null && _activeVersionId!.isNotEmpty;
  bool get canEnrol => !hasActiveAssignment;
  List<String> get comparisonVersionIds =>
      List<String>.unmodifiable(_comparisonVersionIds);
  List<ProgrammeCatalogEntry> get comparisonSelections {
    return _comparisonVersionIds
        .map(entryByVersionId)
        .whereType<ProgrammeCatalogEntry>()
        .toList(growable: false);
  }

  ProgrammeCatalogEntry? entryByVersionId(String versionId) {
    for (final entry in _programmes) {
      if (entry.versionId == versionId) return entry;
    }
    return null;
  }

  bool isSelectedForCompare(ProgrammeCatalogEntry entry) {
    return _comparisonVersionIds.contains(entry.versionId);
  }

  void toggleCompare(ProgrammeCatalogEntry entry) {
    if (_comparisonVersionIds.contains(entry.versionId)) {
      _comparisonVersionIds.remove(entry.versionId);
      notifyListeners();
      return;
    }
    if (_comparisonVersionIds.length >= 2) {
      _comparisonVersionIds.removeAt(0);
    }
    _comparisonVersionIds.add(entry.versionId);
    notifyListeners();
  }

  void clearComparison() {
    if (_comparisonVersionIds.isEmpty) return;
    _comparisonVersionIds.clear();
    notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    _lastResult = null;
    notifyListeners();

    try {
      final assignments = assignmentStore;
      if (assignments != null) {
        final active = await assignments.getActiveAssignment(_athleteId);
        _activeVersionId = active?.programmeVersionId;
      }
      _programmes = await catalogService.listPublishedAssignableProgrammes();
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
    return entry.versionId == activeVersionId;
  }

  /// Enrols in the selected catalogue programme (exact version id).
  ///
  /// Sprint 1 never replaces an active assignment. [replaceActive] is
  /// ignored so the existing RPC cannot be reused as a hidden switch.
  Future<AthleteCatalogueEnrolmentResult?> confirmEnrol({
    required DateTime startedAt,
    required String timezone,
    bool replaceActive = false,
  }) async {
    // Sprint 1 never uses replacement, even if a caller passes the flag.
    if (replaceActive) {
      replaceActive = false;
    }

    final selected = _selected;
    if (selected == null || _submitting) return null;

    _submitting = true;
    _errorMessage = null;
    notifyListeners();

    await _refreshActiveAssignment();

    if (selected.versionId == _activeVersionId) {
      final already = AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.alreadyEnrolled,
        programmeVersionId: selected.versionId,
        athleteId: _athleteId,
        message: 'You are already enrolled in this programme.',
      );
      _lastResult = already;
      _submitting = false;
      notifyListeners();
      return already;
    }

    if (hasActiveAssignment) {
      final blocked = AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.conflict,
        programmeVersionId: selected.versionId,
        athleteId: _athleteId,
        code: 'sprint1_switch_unavailable',
        message: 'Programme switching is not available here yet.',
      );
      _lastResult = blocked;
      _submitting = false;
      notifyListeners();
      return blocked;
    }

    final stillListed = _programmes.any(
      (entry) => entry.versionId == selected.versionId,
    );
    if (!stillListed) {
      final stale = AthleteCatalogueEnrolmentResult(
        status: AthleteCatalogueEnrolmentStatus.authorizationFailure,
        programmeVersionId: selected.versionId,
        athleteId: _athleteId,
        code: 'version_not_catalogue_eligible',
        message: 'This programme is not available to enrol in right now.',
      );
      _lastResult = stale;
      _errorMessage = stale.message;
      _submitting = false;
      notifyListeners();
      return stale;
    }

    final result = await enrolmentService.enrol(
      athleteId: _athleteId,
      programmeVersionId: selected.versionId,
      timezone: timezone,
      replaceActive: false,
    );

    _lastResult = result;
    if (result.isSuccess) {
      _activeVersionId = result.programmeVersionId ?? selected.versionId;
      await _refreshActiveAssignment();
    } else if (result.status != AthleteCatalogueEnrolmentStatus.conflict) {
      _errorMessage = result.message;
    }

    _submitting = false;
    notifyListeners();
    return result;
  }

  Future<void> _refreshActiveAssignment() async {
    final assignments = assignmentStore;
    if (assignments == null) return;
    try {
      final active = await assignments.getActiveAssignment(_athleteId);
      _activeVersionId = active?.programmeVersionId;
    } catch (_) {
      // Keep last known pin. Enrol still uses the existing RPC authority.
    }
  }
}
