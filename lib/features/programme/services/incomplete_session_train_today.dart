import 'package:flutter/material.dart';

import '../../../data/repositories/programme_assignment_store.dart';
import '../../../data/repositories/programme_assignment_supabase_store.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../../session/services/programme_session_execution_launcher.dart';
import '../models/fixed_programme_occurrence_projection.dart';
import 'athlete_catalogue_enrolment_services.dart';
import 'athlete_programme_session_prepare_service.dart';

abstract final class IncompleteSessionTrainToday {
  static Future<bool> open({
    required BuildContext context,
    required String athleteId,
    required FixedProgrammeCalendarProjection calendar,
    required FixedProgrammeOccurrenceProjection occurrence,
    ProgrammeAssignmentStore? assignmentStore,
    AthleteProgrammeSessionPrepareService? prepareService,
    ProgrammeSessionExecutionLauncher? executionLauncher,
    HomeTodaySessionRefreshController? refreshController,
  }) async {
    if (!occurrence.isExecutable ||
        occurrence.assignmentId != calendar.assignmentId) {
      return false;
    }
    final assignments =
        assignmentStore ?? const ProgrammeAssignmentSupabaseStore();
    final assignment = await assignments.getById(calendar.assignmentId);
    if (assignment == null ||
        !assignment.isActive ||
        !assignment.isFixedSchedule ||
        assignment.athleteId != athleteId ||
        assignment.id != occurrence.assignmentId) {
      throw StateError('This assigned session is no longer executable.');
    }
    final prepare =
        prepareService ??
        AthleteCatalogueEnrolmentServices.createPrepareService();
    final prepared = await prepare.prepareFixedOccurrence(
      assignment,
      occurrence,
    );
    if (!prepared.isReady) {
      throw StateError(
        prepared.message ?? 'This session could not be prepared safely.',
      );
    }
    await refreshController?.reloadAuthoritativeSurfaces(
      source: 'incomplete_train_today',
    );
    if (!context.mounted) return false;
    await (executionLauncher ?? ProgrammeSessionExecutionLauncher()).launch(
      context: context,
      athleteId: athleteId,
      prepared: prepared,
    );
    return true;
  }
}
