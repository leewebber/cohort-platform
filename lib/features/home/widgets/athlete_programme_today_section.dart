import 'package:flutter/material.dart';

import '../../../application/adaptation/programme_adaptation_acceptance_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/today_session_card.dart';
import '../../programme/models/athlete_programme_prepared_session.dart';
import '../../programme/services/athlete_catalogue_enrolment_services.dart';
import '../../programme/services/athlete_programme_session_prepare_service.dart';
import '../../workout_player/services/workout_player_launcher.dart';
import '../controllers/home_today_session_refresh_controller.dart';
import '../services/programme_adapt_flow.dart';

/// Home/today surface for a materialised authored programme session.
///
/// Uses Sprint 1.4B deterministic preparation only — no Coach Brain resolve.
/// Sprint 1.6B/1.6C adds athlete-initiated Adapt Session with explicit accept.
class AthleteProgrammeTodaySection extends StatefulWidget {
  const AthleteProgrammeTodaySection({
    super.key,
    required this.athleteId,
    this.refreshController,
    this.prepareService,
    this.launcher,
    this.adaptFlow,
    this.prepareOverride,
  });

  final String athleteId;
  final HomeTodaySessionRefreshController? refreshController;
  final AthleteProgrammeSessionPrepareService? prepareService;
  final WorkoutPlayerLauncher? launcher;
  final ProgrammeAdaptFlow? adaptFlow;

  /// Test seam: when set, used instead of [prepareService] for load.
  final Future<AthleteProgrammePrepareResult> Function(String athleteId)?
  prepareOverride;

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
  late final ProgrammeAdaptFlow _adaptFlow =
      widget.adaptFlow ??
      ProgrammeAdaptFlow(
        acceptanceService: ProgrammeAdaptationAcceptanceService(
          prepareService: _prepare,
        ),
      );

  AthleteProgrammePrepareResult? _result;
  bool _loading = true;
  bool _opening = false;
  bool _adapting = false;
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
    final result = widget.prepareOverride != null
        ? await widget.prepareOverride!(widget.athleteId)
        : await _prepare.prepareForAthlete(widget.athleteId);
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

  bool get _canAdapt {
    final package = _result?.package;
    if (_result == null || !_result!.isReady || package == null) return false;
    if (_opening || _adapting) return false;
    return package.isProgrammeBacked &&
        package.protocolId != null &&
        package.protocolId!.trim().isNotEmpty &&
        package.assignmentId != null &&
        package.plan.blocks.isNotEmpty &&
        package.acceptedAdaptation == null;
  }

  Future<void> _adapt() async {
    final result = _result;
    final package = result?.package;
    if (package == null || !_canAdapt) return;
    setState(() => _adapting = true);
    try {
      final flowResult = await _adaptFlow.open(
        context,
        athleteId: widget.athleteId,
        package: package,
        executionContext: result?.executionContext,
      );
      if (flowResult.accepted && flowResult.acceptedPackage != null && mounted) {
        setState(() {
          _result = AthleteProgrammePrepareResult(
            status: AthleteProgrammePrepareStatus.restored,
            package: flowResult.acceptedPackage,
            executionContext: result?.executionContext,
            programmedSessionKey:
                flowResult.acceptedPackage!.programmedSessionKey,
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _adapting = false);
        await _load(source: 'adapt_return');
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
          adaptationNotice: package.hasAcceptedAdaptation
              ? 'Adapted for today — original authored prescription retained as reference.'
              : null,
          status: package.hasAcceptedAdaptation
              ? 'Adapted Prepared Session'
              : 'Prepared Session',
          statusDetail: package.hasAcceptedAdaptation
              ? 'Accepted adaptation applies only to this prepared session. '
                  'Programme and later sessions unchanged.'
              : 'Authored programme · exact version. Submit completion to advance.',
          buttonLabel: _opening ? 'Opening…' : 'Begin',
          onPressed: _opening || _adapting ? null : _open,
        ),
        if (_canAdapt || _adapting) ...[
          const SizedBox(height: CohortSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _adapting ? null : _adapt,
              child: Text(
                _adapting ? 'Preparing adaptation…' : 'Adapt Session',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
