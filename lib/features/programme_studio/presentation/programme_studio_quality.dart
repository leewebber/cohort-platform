import '../domain/programme_review_models.dart';
import 'programme_studio_copy.dart';

enum StudioQualityStatus { passed, needsAttention, notAssessed, notImplemented }

class StudioQualityItem {
  const StudioQualityItem({
    required this.id,
    required this.label,
    required this.status,
    required this.detail,
  });

  final String id;
  final String label;
  final StudioQualityStatus status;
  final String detail;
}

class StudioQualityGroup {
  const StudioQualityGroup({required this.title, required this.items});

  final String title;
  final List<StudioQualityItem> items;
}

class StudioQualityReport {
  const StudioQualityReport({
    required this.technicallyValid,
    required this.groups,
  });

  final bool technicallyValid;
  final bool launchApproved = false;
  final List<StudioQualityGroup> groups;

  String get summaryLine => technicallyValid
      ? '${ProgrammeStudioCopy.technicallyValid}. ${ProgrammeStudioCopy.notLaunchApproved}.'
      : '${ProgrammeStudioCopy.needsAttention}. ${ProgrammeStudioCopy.notLaunchApproved}.';
}

StudioQualityStatus studioStatusFromCheck(ProgrammeReviewCheckStatus status) {
  return switch (status) {
    ProgrammeReviewCheckStatus.passed => StudioQualityStatus.passed,
    ProgrammeReviewCheckStatus.failed => StudioQualityStatus.needsAttention,
    ProgrammeReviewCheckStatus.notAssessed => StudioQualityStatus.notAssessed,
    ProgrammeReviewCheckStatus.notImplemented =>
      StudioQualityStatus.notImplemented,
  };
}

String studioStatusLabel(StudioQualityStatus status) {
  return switch (status) {
    StudioQualityStatus.passed => 'Passed',
    StudioQualityStatus.needsAttention => ProgrammeStudioCopy.needsAttention,
    StudioQualityStatus.notAssessed => 'Not assessed',
    StudioQualityStatus.notImplemented => 'Not implemented',
  };
}

StudioQualityReport buildStudioQualityReport(
  ProgrammeReviewProgramme programme,
) {
  ProgrammeReviewCheck? byId(String id) {
    for (final check in programme.readiness) {
      if (check.id == id) {
        return check;
      }
    }
    return null;
  }

  StudioQualityItem mapped(String id, String label) {
    final check = byId(id);
    return StudioQualityItem(
      id: id,
      label: label,
      status: check == null
          ? StudioQualityStatus.notAssessed
          : studioStatusFromCheck(check.status),
      detail: check?.detail ?? '',
    );
  }

  return StudioQualityReport(
    technicallyValid:
        programme.compile.state == ProgrammeReviewCompileState.valid,
    groups: [
      StudioQualityGroup(
        title: 'Programme source',
        items: [
          mapped('compiler_validation', 'Source compiled'),
          mapped('canonical_hash', 'Package identity stable'),
        ],
      ),
      StudioQualityGroup(
        title: 'Training content',
        items: [
          mapped('protocol_bodies', 'Session content available'),
          if (programme.lineageCode == 'BALI-HYBRID-BASE') ...[
            mapped('session_count_71', 'All 71 sessions represented'),
            mapped('same_day_ampm', 'Same-day AM/PM retained'),
            mapped('spillover_retained', 'Week 8 spillover retained'),
            mapped('private_classification', 'Private classification'),
            mapped('source_fidelity', 'Source-fidelity test'),
          ],
        ],
      ),
      StudioQualityGroup(
        title: 'Athlete experience',
        items: [mapped('athlete_preview', 'Athlete-facing preview')],
      ),
      StudioQualityGroup(
        title: 'Performance infrastructure',
        items: [
          mapped('pace_calculation', 'Running pace calculations'),
          mapped('metrics_profile', 'Programme metrics profile'),
          mapped('device_garmin', 'Garmin/device interoperability'),
        ],
      ),
      StudioQualityGroup(
        title: 'Release approval',
        items: [
          mapped('coaching_approval', 'Founder coaching review'),
          mapped('execution_device_test', 'Athlete device execution'),
          mapped('hosted_private_publication', 'Private hosted publication'),
          mapped('lee_assignment', 'Lee assignment'),
          mapped('complete_phone_execution', 'Complete phone execution'),
          const StudioQualityItem(
            id: 'launch_approval',
            label: 'Launch approval',
            status: StudioQualityStatus.notAssessed,
            detail:
                'Compiler success is not launch approval. Human release '
                'approval has not been given.',
          ),
        ],
      ),
    ],
  );
}

String programmeCardStatus(ProgrammeReviewProgramme programme) {
  if (!programme.compile.validationOk) {
    return ProgrammeStudioCopy.needsAttention;
  }
  final missingBodies = programme.weeks
      .expand((week) => week.days)
      .expand((day) => day.sessions)
      .any((session) => !session.bodiesResolved);
  return missingBodies
      ? ProgrammeStudioCopy.needsAttention
      : ProgrammeStudioCopy.contentReady;
}
