import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/today_session_card.dart';
import '../../programme/models/athlete_programme_prepared_session.dart';
import '../../programme/services/athlete_catalogue_enrolment_services.dart';
import '../../programme/services/athlete_programme_session_prepare_service.dart';
import '../../workout_player/services/workout_player_launcher.dart';
import '../controllers/home_today_session_refresh_controller.dart';

/// Home/today surface for a materialised authored programme session.
///
/// Uses Sprint 1.4B deterministic preparation only — no Coach Brain resolve.
class AthleteProgrammeTodaySection extends StatefulWidget {
  const AthleteProgrammeTodaySection({
    super.key,
    required this.athleteId,
    this.refreshController,
    this.prepareService,
    this.launcher,
  });

  final String athleteId;
  final HomeTodaySessionRefreshController? refreshController;
  final AthleteProgrammeSessionPrepareService? prepareService;
  final WorkoutPlayerLauncher? launcher;

  @override
  State<AthleteProgrammeTodaySection> createState() =>
      _AthleteProgrammeTodaySectionState();
}

class _AthleteProgrammeTodaySectionState
    extends State<AthleteProgrammeTodaySection> {
  late final AthleteProgrammeSessionPrepareService _prepare =
      widget.prepareService ??
      AthleteCatalogueEnrolmentServices.createPrepareService();
  late final WorkoutPlayerLauncher _launcher =
      widget.launcher ?? WorkoutPlayerLauncher();

  AthleteProgrammePrepareResult? _result;
  bool _loading = true;
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.refreshController?.attach(_onRefresh);
    _load(source: 'initial');
  }

  @override
  void didUpdateWidget(covariant AthleteProgrammeTodaySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshController != widget.refreshController) {
      oldWidget.refreshController?.detach();
      widget.refreshController?.attach(_onRefresh);
    }
  }

  @override
  void dispose() {
    widget.refreshController?.detach();
    super.dispose();
  }

  void _onRefresh({required String source}) => _load(source: source);

  Future<void> _load({required String source}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _prepare.prepareForAthlete(widget.athleteId);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
      if (!result.isReady) {
        _error = result.message ?? 'Session is not ready yet.';
      }
    });
  }

  Future<void> _open() async {
    final result = _result;
    final package = result?.package;
    if (result == null || package == null || _opening) return;
    setState(() => _opening = true);
    try {
      await _launcher.launchWithPlan(
        context: context,
        athleteId: widget.athleteId,
        plan: _prepare.toOpenablePlan(package),
        programmeContext: result.executionContext,
      );
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        await _load(source: 'session_return');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY', style: CohortTextStyles.sectionLabel),
          SizedBox(height: CohortSpacing.md),
          Text('Preparing today\'s session…', style: CohortTextStyles.muted),
        ],
      );
    }

    final result = _result;
    if (result == null || !result.isReady || result.package == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY', style: CohortTextStyles.sectionLabel),
          const SizedBox(height: CohortSpacing.md),
          Text(
            _error ?? 'Today\'s session could not be prepared.',
            style: CohortTextStyles.body,
          ),
          const SizedBox(height: CohortSpacing.md),
          CohortButton(
            label: 'Retry',
            onPressed: () => _load(source: 'retry'),
          ),
        ],
      );
    }

    final package = result.package!;
    final ctx = result.executionContext;
    final weekLabel = ctx == null
        ? 'Week ${package.programmedSessionKey.week}'
        : 'Week ${ctx.weekNumber}';
    final subtitle = ctx?.dayKey ?? package.dayKey ?? 'day_1';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TodaySessionCard(
          title: package.brief.sessionName,
          subtitle: subtitle,
          weekLabel: weekLabel,
          duration: package.brief.durationLabel,
          programmeName: ctx?.programmeName,
          status: 'Prepared Session',
          statusDetail:
              'Authored programme · exact version. Completion is deferred.',
          buttonLabel: _opening ? 'Opening…' : 'Begin',
          onPressed: _opening ? null : _open,
        ),
      ],
    );
  }
}
