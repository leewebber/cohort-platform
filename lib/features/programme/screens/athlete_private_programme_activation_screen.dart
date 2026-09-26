import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../models/athlete_catalogue_enrolment.dart';
import '../models/private_programme_summary.dart';
import '../presentation/enrolment_date_presentation.dart';
import '../services/private_programme_enrolment_store.dart';

class AthletePrivateProgrammeActivationScreen extends StatefulWidget {
  const AthletePrivateProgrammeActivationScreen({
    super.key,
    required this.programme,
    required this.currentProgrammeTitle,
    required this.enrolmentStore,
    this.refreshController,
    this.onActivated,
  });

  final PrivateProgrammeSummary programme;
  final String? currentProgrammeTitle;
  final PrivateProgrammeEnrolmentStore enrolmentStore;
  final HomeTodaySessionRefreshController? refreshController;
  final ValueChanged<AthleteCatalogueEnrolmentResult>? onActivated;

  @override
  State<AthletePrivateProgrammeActivationScreen> createState() =>
      _AthletePrivateProgrammeActivationScreenState();
}

class _AthletePrivateProgrammeActivationScreenState
    extends State<AthletePrivateProgrammeActivationScreen> {
  bool _submitting = false;
  String? _error;
  bool _confirmedOnce = false;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _weekday(DateTime date) => _weekdays[date.weekday - 1];

  DateTime? get _start => widget.programme.authorisedLocalStartDate;
  String? get _timezone => widget.programme.authorisedTimezone;

  Future<void> _confirm() async {
    if (_submitting || _confirmedOnce) return;
    final start = _start;
    final timezone = _timezone;
    if (start == null || timezone == null || timezone.isEmpty) {
      setState(() {
        _error = 'This private programme has no authorised start date.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await widget.enrolmentStore.enrol(
      programmeVersionId: widget.programme.versionId,
      timezone: timezone,
      localStartDate: start,
      replaceActive: true,
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _confirmedOnce = result.isSuccess;
      _error = result.isSuccess ? null : result.message;
    });
    if (result.isSuccess) {
      widget.refreshController?.requestRefresh(
        source: 'private_programme_activation',
      );
      widget.onActivated?.call(result);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final startLabel = _start == null
        ? null
        : '${_weekday(_start!)} ${EnrolmentDatePresentation.fromIso('${_start!.year.toString().padLeft(4, '0')}-${_start!.month.toString().padLeft(2, '0')}-${_start!.day.toString().padLeft(2, '0')}') ?? ''}';
    final current = widget.currentProgrammeTitle?.trim();
    return Scaffold(
      appBar: AppBar(title: const Text('Activate private programme')),
      body: ListView(
        padding: const EdgeInsets.all(CohortSpacing.lg),
        children: [
          Text(widget.programme.title, style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.sm),
          const Text('Private', style: CohortTextStyles.small),
          const SizedBox(height: CohortSpacing.md),
          ...[
            if (startLabel != null) 'Starts $startLabel',
            if (_timezone != null) 'Timezone $_timezone',
            if (current != null && current.isNotEmpty)
              '$current is currently active',
            if (current != null && current.isNotEmpty)
              'Activating ${widget.programme.title} will move $current to History',
            if (current != null && current.isNotEmpty)
              '$current results will not be deleted',
            '${widget.programme.title} will become the current programme',
          ].map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: CohortSpacing.sm),
              child: Text(line, style: CohortTextStyles.body),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(_error!, style: CohortTextStyles.body),
          ],
          const SizedBox(height: CohortSpacing.lg),
          IgnorePointer(
            ignoring: _submitting,
            child: Opacity(
              opacity: _submitting ? 0.6 : 1,
              child: CohortButton(
                label: _submitting
                    ? 'Activating…'
                    : 'Activate ${widget.programme.title}',
                onPressed: _confirm,
              ),
            ),
          ),
          const SizedBox(height: CohortSpacing.sm),
          CohortButton(
            label: 'Cancel',
            variant: CohortButtonVariant.secondary,
            onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}
