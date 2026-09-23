import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../presentation/athlete_programme_decision_copy.dart';
import '../presentation/athlete_programme_decision_facts.dart';

class AthleteProgrammeEnrolmentReviewScreen extends StatefulWidget {
  const AthleteProgrammeEnrolmentReviewScreen({
    super.key,
    required this.controller,
    required this.versionId,
    this.refreshController,
  });

  final AthleteProgrammeSelectionController controller;
  final String versionId;
  final HomeTodaySessionRefreshController? refreshController;

  @override
  State<AthleteProgrammeEnrolmentReviewScreen> createState() =>
      _AthleteProgrammeEnrolmentReviewScreenState();
}

class _AthleteProgrammeEnrolmentReviewScreenState
    extends State<AthleteProgrammeEnrolmentReviewScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _confirm() async {
    if (widget.controller.isSubmitting) return;
    final entry = widget.controller.entryByVersionId(widget.versionId);
    if (entry == null) return;
    widget.controller.selectProgramme(entry);

    final result = await widget.controller.confirmEnrol(
      startedAt: DateTime.now(),
      timezone: DateTime.now().timeZoneName,
    );
    if (!mounted || result == null) return;

    if (result.isSuccess) {
      widget.refreshController?.requestRefresh(
        source: 'athlete_catalogue_enrolment',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isIdempotentAlreadyEnrolled
                ? AthleteProgrammeDecisionCopy.alreadyEnrolled
                : AthleteProgrammeDecisionCopy.enrolSuccess,
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
            const SizedBox(height: CohortSpacing.md),
            Text(
              AthleteProgrammeDecisionCopy.enrolReviewBody(facts.title),
              style: CohortTextStyles.body,
            ),
            const SizedBox(height: CohortSpacing.xl),
            if (blockedByAssignment)
              const CohortCard(
                child: Text(
                  AthleteProgrammeDecisionCopy.assignedDuringFlow,
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
              onPressed: (controller.isSubmitting || blockedByAssignment)
                  ? null
                  : _confirm,
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
