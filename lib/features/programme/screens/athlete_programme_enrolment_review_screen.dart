import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../domain/enrolment_iana_timezone.dart';
import '../domain/enrolment_local_date.dart';
import '../domain/enrolment_timezone_capture.dart';
import '../domain/flutter_device_iana_timezone_source.dart';
import '../presentation/athlete_programme_continuity_copy.dart';
import '../presentation/athlete_programme_decision_copy.dart';
import '../presentation/athlete_programme_decision_facts.dart';
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
    );
    if (!mounted || selected == null) return;
    setState(() {
      _timezone = _timezone.select(selected);
    });
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isIdempotentAlreadyEnrolled
                ? AthleteProgrammeDecisionCopy.alreadyEnrolled
                : confirmedDate == null
                ? AthleteProgrammeDecisionCopy.enrolSuccess
                : '${AthleteProgrammeDecisionCopy.enrolSuccess} Starts $confirmedDate.',
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
            child: CohortCard(
              child: Text(
                AthleteProgrammeDecisionCopy.detailUnavailable,
                style: CohortTextStyles.body,
              ),
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
    final intendedDate = _timezone.iana == null
        ? null
        : EnrolmentLocalDate.isoDate(iana: _timezone.iana!, utcNow: _utcNow);
    final canConfirm =
        !controller.isSubmitting &&
        !blockedByAssignment &&
        _timezone.canConfirm &&
        intendedDate != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AthleteProgrammeDecisionCopy.enrolReviewAppBar),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(CohortSpacing.lg),
          children: [
            Semantics(
              header: true,
              child: Text(
                AthleteProgrammeDecisionCopy.enrolReviewTitle(facts.title),
                style: CohortTextStyles.h1,
              ),
            ),
            const SizedBox(height: CohortSpacing.lg),
            _ReviewFact(
              label: 'Programme',
              value: facts.title,
            ),
            _ReviewFact(
              label: 'Goal',
              value: facts.glanceValue(facts.primaryGoal),
            ),
            _ReviewFact(
              label: 'Duration',
              value: facts.glanceValue(facts.durationDisplay),
            ),
            _ReviewFact(
              label: 'Sessions per week',
              value: facts.glanceValue(facts.frequencyDisplay),
            ),
            _ReviewFact(
              label: 'Intended level',
              value: facts.glanceValue(facts.intendedLevel),
            ),
            _TimezoneFact(
              capture: _timezone,
              onChange: controller.isSubmitting ? null : _changeTimezone,
            ),
            _ReviewFact(
              label: last?.startedAt != null && last!.isSuccess
                  ? AthleteProgrammeContinuityCopy.confirmedStartDate
                  : AthleteProgrammeContinuityCopy.intendedStartProvisional,
              value: last?.startedAt != null && last!.isSuccess
                  ? last.startedAt!.toIso8601String().substring(0, 10)
                  : (intendedDate ?? AthleteProgrammeDecisionCopy.notSpecified),
            ),
            const SizedBox(height: CohortSpacing.md),
            Text(
              AthleteProgrammeDecisionCopy.enrolReviewBody(facts.title),
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.sm),
            Text(
              AthleteProgrammeContinuityCopy.travelAnchor,
              style: CohortTextStyles.small,
            ),
            const SizedBox(height: CohortSpacing.xl),
            if (blockedByAssignment)
              const CohortCard(
                child: Text(
                  AthleteProgrammeDecisionCopy.assignedDuringFlow,
                  style: CohortTextStyles.body,
                ),
              )
            else if (_timezone.needsExplicitSelection &&
                _timezone.kind != EnrolmentTimezoneCaptureKind.detecting)
              const CohortCard(
                child: Text(
                  AthleteProgrammeContinuityCopy.timezoneRequired,
                  style: CohortTextStyles.body,
                ),
              )
            else if (controller.isSubmitting)
              const CohortCard(
                child: Text(
                  AthleteProgrammeDecisionCopy.enrolPending,
                  style: CohortTextStyles.body,
                ),
              )
            else if (rejected)
              CohortCard(
                child: Text(
                  last.message ??
                      AthleteProgrammeDecisionCopy.catalogueUnavailable,
                  style: CohortTextStyles.body,
                ),
              ),
            const SizedBox(height: CohortSpacing.xl),
            CohortButton(
              label: controller.isSubmitting
                  ? AthleteProgrammeDecisionCopy.enrolPending
                  : rejected
                  ? AthleteProgrammeDecisionCopy.retry
                  : AthleteProgrammeDecisionCopy.enrolConfirm,
              onPressed: canConfirm ? _confirm : null,
            ),
            const SizedBox(height: CohortSpacing.md),
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
    );
  }
}

class _TimezoneFact extends StatelessWidget {
  const _TimezoneFact({required this.capture, required this.onChange});

  final EnrolmentTimezoneCapture capture;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final iana = capture.iana;
    final value = capture.kind == EnrolmentTimezoneCaptureKind.detecting
        ? 'Detecting timezone…'
        : iana == null
        ? AthleteProgrammeDecisionCopy.notSpecified
        : EnrolmentIanaLabels.display(iana);
    final changeLabel = iana == null
        ? AthleteProgrammeContinuityCopy.selectTimezone
        : AthleteProgrammeContinuityCopy.changeTimezone;
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            label:
                '${AthleteProgrammeContinuityCopy.trainingTimezone}, $value',
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    AthleteProgrammeContinuityCopy.trainingTimezone,
                    style: CohortTextStyles.small,
                  ),
                  const SizedBox(height: 2),
                  Text(value, style: CohortTextStyles.body),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(changeLabel),
          ),
        ],
      ),
    );
  }
}

class _ReviewFact extends StatelessWidget {
  const _ReviewFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
      child: Semantics(
        container: true,
        label: '$label, $value',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: CohortTextStyles.small),
              const SizedBox(height: 2),
              Text(value, style: CohortTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}
