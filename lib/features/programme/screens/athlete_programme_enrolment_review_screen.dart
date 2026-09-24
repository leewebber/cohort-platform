import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../domain/enrolment_iana_timezone.dart';
import '../domain/enrolment_local_date.dart';
import '../domain/enrolment_timezone_capture.dart';
import '../domain/flutter_device_iana_timezone_source.dart';
import '../presentation/athlete_programme_continuity_copy.dart';
import '../presentation/athlete_programme_decision_copy.dart';
import '../presentation/athlete_programme_decision_facts.dart';
import '../presentation/enrolment_date_presentation.dart';
import '../widgets/athlete_programme_fact_list.dart';
import '../widgets/athlete_programme_status_state.dart';
import '../widgets/enrolment_timezone_picker_sheet.dart';

class AthleteProgrammeEnrolmentReviewScreen extends StatefulWidget {
  const AthleteProgrammeEnrolmentReviewScreen({
    super.key,
    required this.controller,
    required this.versionId,
    this.refreshController,
    this.timezoneSource = const FlutterDeviceIanaTimezoneSource(),
    this.clock,
  });

  final AthleteProgrammeSelectionController controller;
  final String versionId;
  final HomeTodaySessionRefreshController? refreshController;
  final DeviceIanaTimezoneSource timezoneSource;
  final DateTime Function()? clock;

  @override
  State<AthleteProgrammeEnrolmentReviewScreen> createState() =>
      _AthleteProgrammeEnrolmentReviewScreenState();
}

class _AthleteProgrammeEnrolmentReviewScreenState
    extends State<AthleteProgrammeEnrolmentReviewScreen> {
  EnrolmentTimezoneCapture _timezone = EnrolmentTimezoneCapture.detecting;
  final _changeFocus = FocusNode();

  DateTime get _utcNow => (widget.clock ?? DateTime.now)().toUtc();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _detectTimezone();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _changeFocus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _detectTimezone() async {
    try {
      final raw = await widget.timezoneSource.detect();
      if (!mounted) return;
      setState(() {
        _timezone = EnrolmentTimezoneCapture.fromDeviceSuggestion(raw);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _timezone = EnrolmentTimezoneCapture.selectionRequired;
      });
    }
  }

  Future<void> _changeTimezone() async {
    final selected = await showEnrolmentTimezonePicker(
      context: context,
      selectedIana: _timezone.iana,
      suggestedIana: EnrolmentIanaTimezone.canonicalize(
        _timezone.deviceSuggestion,
      ),
    );
    if (!mounted) return;
    if (selected != null) {
      setState(() {
        _timezone = _timezone.select(selected);
      });
    }
    _changeFocus.requestFocus();
  }

  Future<void> _confirm() async {
    if (widget.controller.isSubmitting) return;
    if (!_timezone.canConfirm) return;
    final entry = widget.controller.entryByVersionId(widget.versionId);
    if (entry == null) return;
    widget.controller.selectProgramme(entry);

    final result = await widget.controller.confirmEnrol(
      timezone: _timezone.iana!,
    );
    if (!mounted || result == null) return;

    if (result.isSuccess) {
      widget.refreshController?.requestRefresh(
        source: 'athlete_catalogue_enrolment',
      );
      final confirmedDate = result.startedAt?.toIso8601String().substring(
        0,
        10,
      );
      final facing = EnrolmentDatePresentation.fromIso(confirmedDate);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isIdempotentAlreadyEnrolled
                ? AthleteProgrammeDecisionCopy.alreadyEnrolled
                : facing == null
                ? AthleteProgrammeDecisionCopy.enrolSuccess
                : '${AthleteProgrammeDecisionCopy.enrolSuccess} Starts $facing.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message ?? AthleteProgrammeDecisionCopy.catalogueUnavailable,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final entry = controller.entryByVersionId(widget.versionId);
    final last = controller.lastEnrolmentResult;

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(AthleteProgrammeDecisionCopy.enrolReviewAppBar),
        ),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(CohortSpacing.lg),
            child: AthleteProgrammeStatusState(
              badge: 'Unavailable',
              headline: AthleteProgrammeDecisionCopy.detailUnavailable,
              explanation: AthleteProgrammeDecisionCopy.detailUnavailable,
            ),
          ),
        ),
      );
    }

    final facts = AthleteProgrammeDecisionFacts.fromEntry(
      entry,
      isCurrentProgramme: controller.isCurrentProgramme(entry),
    );

    final blockedByAssignment =
        controller.hasActiveAssignment && !facts.isCurrentProgramme;
    final rejected = last != null && !last.isSuccess;
    final intendedIso = _timezone.iana == null
        ? null
        : EnrolmentLocalDate.isoDate(iana: _timezone.iana!, utcNow: _utcNow);
    final canConfirm =
        !controller.isSubmitting &&
        !blockedByAssignment &&
        _timezone.canConfirm &&
        intendedIso != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AthleteProgrammeDecisionCopy.enrolReviewAppBar),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            CohortSpacing.lg,
            CohortSpacing.md,
            CohortSpacing.lg,
            CohortSpacing.xxl,
          ),
          children: [
            _ProgrammeSection(facts: facts),
            const SizedBox(height: CohortSpacing.xl),
            _ScheduleSection(
              capture: _timezone,
              intendedIso: intendedIso,
              confirmedIso: last?.isSuccess == true
                  ? last!.startedAt?.toIso8601String().substring(0, 10)
                  : null,
              onChange: controller.isSubmitting ? null : _changeTimezone,
              changeFocus: _changeFocus,
            ),
            const SizedBox(height: CohortSpacing.xl),
            EnrolmentContinuityPanel(programmeTitle: facts.title),
            const SizedBox(height: CohortSpacing.xl),
            if (blockedByAssignment)
              const AthleteProgrammeStatusState(
                badge: 'Unavailable',
                headline: AthleteProgrammeDecisionCopy.assignedDuringFlow,
                explanation: AthleteProgrammeDecisionCopy.switchingUnavailable,
              )
            else if (_timezone.needsExplicitSelection &&
                _timezone.kind != EnrolmentTimezoneCaptureKind.detecting)
              AthleteProgrammeStatusState(
                badge: 'Required',
                headline: AthleteProgrammeContinuityCopy.timezoneRepairHeadline,
                explanation: AthleteProgrammeContinuityCopy.timezoneRequired,
                action: CohortButton(
                  label: AthleteProgrammeContinuityCopy.selectTimezone,
                  onPressed: _changeTimezone,
                ),
              )
            else if (controller.isSubmitting)
              const AthleteProgrammeStatusState(
                badge: 'Working',
                headline: AthleteProgrammeDecisionCopy.enrolPending,
                explanation: AthleteProgrammeDecisionCopy.enrolPending,
              )
            else if (rejected)
              AthleteProgrammeStatusState(
                badge: 'Could not enrol',
                headline: 'Enrolment could not be completed',
                explanation:
                    last.message ??
                    AthleteProgrammeDecisionCopy.catalogueUnavailable,
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CohortSpacing.lg,
            CohortSpacing.sm,
            CohortSpacing.lg,
            CohortSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CohortButton(
                label: controller.isSubmitting
                    ? AthleteProgrammeDecisionCopy.enrolPending
                    : rejected
                    ? AthleteProgrammeDecisionCopy.retry
                    : AthleteProgrammeDecisionCopy.enrolConfirm,
                onPressed: canConfirm ? _confirm : null,
              ),
              const SizedBox(height: CohortSpacing.sm),
              CohortButton(
                label: AthleteProgrammeDecisionCopy.cancel,
                variant: CohortButtonVariant.secondary,
                onPressed: controller.isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgrammeSection extends StatelessWidget {
  const _ProgrammeSection({required this.facts});

  final AthleteProgrammeDecisionFacts facts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Programme', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.sm),
        Semantics(
          header: true,
          child: Text(
            AthleteProgrammeDecisionCopy.enrolReviewTitle(facts.title),
            style: CohortTextStyles.h2,
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
        Semantics(
          container: true,
          label: 'Goal, ${facts.glanceValue(facts.primaryGoal)}',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Goal', style: CohortTextStyles.tileLabel),
                const SizedBox(height: 4),
                Text(
                  facts.glanceValue(facts.primaryGoal),
                  style: CohortTextStyles.cardTitle,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
        AthleteProgrammeGlanceTiles(
          facts: facts,
          showHeading: false,
          includeEquipment: false,
          sessionsLabel: 'Sessions per week',
          uppercaseLabels: false,
        ),
      ],
    );
  }
}

class _ScheduleSection extends StatelessWidget {
  const _ScheduleSection({
    required this.capture,
    required this.intendedIso,
    required this.confirmedIso,
    required this.onChange,
    required this.changeFocus,
  });

  final EnrolmentTimezoneCapture capture;
  final String? intendedIso;
  final String? confirmedIso;
  final VoidCallback? onChange;
  final FocusNode changeFocus;

  @override
  Widget build(BuildContext context) {
    final iana = capture.iana;
    final detecting = capture.kind == EnrolmentTimezoneCaptureKind.detecting;
    final friendly = detecting
        ? 'Detecting timezone…'
        : iana == null
        ? AthleteProgrammeDecisionCopy.notSpecified
        : EnrolmentIanaLabels.labelFor(iana);
    final dateIso = confirmedIso ?? intendedIso;
    final dateFacing =
        EnrolmentDatePresentation.fromIso(dateIso) ??
        AthleteProgrammeDecisionCopy.notSpecified;
    final dateLabel = confirmedIso != null
        ? AthleteProgrammeContinuityCopy.confirmedStartDate
        : AthleteProgrammeContinuityCopy.intendedStartProvisional;
    final changeLabel = iana == null
        ? AthleteProgrammeContinuityCopy.selectTimezone
        : AthleteProgrammeContinuityCopy.changeTimezone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Schedule', style: CohortTextStyles.sectionLabel),
        const SizedBox(height: CohortSpacing.md),
        Semantics(
          container: true,
          label:
              '${AthleteProgrammeContinuityCopy.trainingTimezone}, $friendly'
              '${iana == null ? '' : ', $iana'}',
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CohortColors.surfaceRaised,
              border: Border.all(color: CohortColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(CohortSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          AthleteProgrammeContinuityCopy.trainingTimezone,
                          style: CohortTextStyles.tileLabel,
                        ),
                        const SizedBox(height: 6),
                        Text(friendly, style: CohortTextStyles.cardTitle),
                        if (iana != null) ...[
                          const SizedBox(height: 2),
                          Text(iana, style: CohortTextStyles.muted),
                        ],
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      focusNode: changeFocus,
                      onPressed: onChange,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(changeLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: CohortSpacing.md),
        Semantics(
          container: true,
          label: '$dateLabel, $dateFacing',
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateLabel, style: CohortTextStyles.tileLabel),
                const SizedBox(height: 4),
                Text(dateFacing, style: CohortTextStyles.body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
