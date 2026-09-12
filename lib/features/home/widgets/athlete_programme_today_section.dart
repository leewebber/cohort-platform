import 'package:flutter/material.dart';

import '../../../application/adaptation/programme_adaptation_acceptance_service.dart';
import '../../../application/adaptation/programme_adaptation_reversion_service.dart';
import '../../../core/presentation/athlete_safe_error_presenter.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/programme_adaptation_revert_sheet.dart';
import '../../../models/programme_assignment.dart';
import '../../programme/models/athlete_programme_prepared_session.dart';
import '../../programme/models/fixed_programme_occurrence_projection.dart';
import '../../programme/services/athlete_catalogue_enrolment_services.dart';
import '../../programme/services/athlete_programme_session_prepare_service.dart';
import '../../session/services/programme_session_execution_launcher.dart';
import '../controllers/home_today_session_refresh_controller.dart';
import '../presentation/athlete_home_today_presentation.dart';
import '../services/programme_adapt_flow.dart';
import 'athlete_home_today_session_panel.dart';

/// Home/today surface for a materialised authored programme session.
///
/// Uses Sprint 1.4B deterministic preparation only — no Coach Brain resolve.
/// Sprint 1.6B–1.6D: Adapt Session, explicit accept, and pre-completion revert.
class AthleteProgrammeTodaySection extends StatefulWidget {
  const AthleteProgrammeTodaySection({
    super.key,
    required this.athleteId,
    this.refreshController,
    this.prepareService,
    this.executionLauncher,
    this.adaptFlow,
    this.reversionService,
    this.prepareOverride,
    this.fixedAssignment,
    this.fixedOccurrence,
    this.onExecutionReturned,
    this.onViewFullSession,
    this.dateLabel,
  });

  final String athleteId;
  final HomeTodaySessionRefreshController? refreshController;
  final AthleteProgrammeSessionPrepareService? prepareService;
  final ProgrammeSessionExecutionLauncher? executionLauncher;
  final ProgrammeAdaptFlow? adaptFlow;
  final ProgrammeAdaptationReversionService? reversionService;
  final ProgrammeAssignment? fixedAssignment;
  final FixedProgrammeOccurrenceProjection? fixedOccurrence;
  final Future<void> Function()? onExecutionReturned;
  final VoidCallback? onViewFullSession;
  final String? dateLabel;

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
  late final ProgrammeSessionExecutionLauncher _executionLauncher =
      widget.executionLauncher ?? ProgrammeSessionExecutionLauncher();
  late final ProgrammeAdaptFlow _adaptFlow =
      widget.adaptFlow ??
      ProgrammeAdaptFlow(
        acceptanceService: ProgrammeAdaptationAcceptanceService(
          prepareService: _prepare,
        ),
      );
  late final ProgrammeAdaptationReversionService _reversion =
      widget.reversionService ??
      ProgrammeAdaptationReversionService(prepareService: _prepare);

  AthleteProgrammePrepareResult? _result;
  bool _loading = true;
  bool _opening = false;
  bool _adapting = false;
  bool _reverting = false;
  String? _error;
  String? _openError;

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
    final occurrenceChanged =
        oldWidget.fixedOccurrence?.occurrenceId !=
            widget.fixedOccurrence?.occurrenceId ||
        oldWidget.fixedOccurrence?.trainingSessionId !=
            widget.fixedOccurrence?.trainingSessionId ||
        oldWidget.fixedOccurrence?.scheduledDate !=
            widget.fixedOccurrence?.scheduledDate ||
        oldWidget.fixedAssignment?.id != widget.fixedAssignment?.id;
    if (occurrenceChanged) {
      _load(source: 'authoritative_occurrence');
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
    final fixedAssignment = widget.fixedAssignment;
    final fixedOccurrence = widget.fixedOccurrence;
    final result = widget.prepareOverride != null
        ? await widget.prepareOverride!(widget.athleteId)
        : fixedAssignment != null && fixedOccurrence != null
        ? await _prepare.prepareFixedOccurrence(
            fixedAssignment,
            fixedOccurrence,
          )
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
    setState(() {
      _opening = true;
      _openError = null;
    });
    var returnedFromExecution = false;
    try {
      await _executionLauncher.launch(
        context: context,
        athleteId: widget.athleteId,
        prepared: result,
      );
      returnedFromExecution = true;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _openError = error is ProgrammeSessionExecutionException
            ? '${error.code.name}: ${error.message}'
            : AthleteSafeErrorPresenter.message(
                error,
                fallback:
                    'Cohort could not open this authored session. Retry to resume the same attempt.',
                logTag: 'AthleteProgrammeTodaySection.open',
              );
      });
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        if (returnedFromExecution) {
          await widget.onExecutionReturned?.call();
          if (mounted) await _load(source: 'session_return');
        }
      }
    }
  }

  bool get _canAdapt {
    final package = _result?.package;
    if (_result == null || !_result!.isReady || package == null) return false;
    if (_opening || _adapting || _reverting) return false;
    return package.isProgrammeBacked &&
        package.protocolId != null &&
        package.protocolId!.trim().isNotEmpty &&
        package.assignmentId != null &&
        package.plan.blocks.isNotEmpty &&
        package.acceptedAdaptation == null;
  }

  bool get _canRevert {
    final package = _result?.package;
    if (_result == null || !_result!.isReady || package == null) return false;
    if (_opening || _adapting || _reverting) return false;
    final ctx = _result!.executionContext;
    return package.hasAcceptedAdaptation &&
        package.isProgrammeBacked &&
        ctx != null &&
        package.assignmentId == ctx.assignmentId &&
        package.programmedSessionKey.value == ctx.programmedSessionKey;
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
      if (flowResult.accepted &&
          flowResult.acceptedPackage != null &&
          mounted) {
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

  Future<void> _revert() async {
    final result = _result;
    final package = result?.package;
    final ctx = result?.executionContext;
    final decision = package?.acceptedAdaptation;
    if (package == null || decision == null || ctx == null || !_canRevert) {
      return;
    }

    final confirmed = await showProgrammeAdaptationRevertSheet(
      context,
      decision: decision,
      sessionTitle: package.brief.sessionName,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _reverting = true);
    try {
      final revertResult = await _reversion.revert(
        athleteId: widget.athleteId,
        currentPackage: package,
        executionContext: ctx,
      );
      if (!mounted) return;
      if (!revertResult.success) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Unable to revert'),
            content: Text(
              revertResult.message ??
                  'Cohort could not restore the original session. Your '
                      'adapted prepared session is unchanged.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      setState(() {
        _result = AthleteProgrammePrepareResult(
          status: AthleteProgrammePrepareStatus.restored,
          package: revertResult.package,
          executionContext: ctx,
          programmedSessionKey: revertResult.package!.programmedSessionKey,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Today's prepared session restored to original."),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Unable to revert'),
          content: Text(
            AthleteSafeErrorPresenter.message(
              error,
              fallback:
                  'Cohort could not restore the original session. Your '
                  'adapted prepared session is unchanged.',
              logTag: 'AthleteProgrammeTodaySection.revert',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _reverting = false);
        await _load(source: 'revert_return');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final occurrence = widget.fixedOccurrence;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY', style: CohortTextStyles.sectionLabel),
          if (occurrence != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(occurrence.sessionTitle, style: CohortTextStyles.h2),
          ],
          const SizedBox(height: CohortSpacing.md),
          const Text(
            'Preparing today\'s session…',
            style: CohortTextStyles.muted,
          ),
        ],
      );
    }

    final result = _result;
    if (result == null || !result.isReady || result.package == null) {
      final occurrence = widget.fixedOccurrence;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TODAY', style: CohortTextStyles.sectionLabel),
          if (occurrence != null) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(occurrence.sessionTitle, style: CohortTextStyles.h2),
          ],
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
    final fixedOccurrence = widget.fixedOccurrence;
    final dateLabel = widget.dateLabel ??
        (fixedOccurrence == null
            ? null
            : AthleteHomeTodayFormatter.fullDate(
                DateTime.parse(fixedOccurrence.scheduledDate),
              ));
    final weekDayLabel = AthleteHomeTodayFormatter.weekDayLabel(
      weekNumber: ctx?.weekNumber ?? package.programmedSessionKey.week,
      dayKey: ctx?.dayKey ?? package.dayKey ?? fixedOccurrence?.dayKey,
    );
    final primaryLabel = _opening
        ? 'Opening…'
        : _openError == null
        ? fixedOccurrence?.isResumable == true
              ? 'Resume'
              : 'Begin'
        : 'Retry';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AthleteHomeTodaySessionPanel(
          package: package,
          dateLabel: dateLabel,
          programmeName: ctx?.programmeName,
          weekDayLabel: weekDayLabel,
          occurrence: fixedOccurrence,
          status: package.hasAcceptedAdaptation
              ? 'ADAPTED PREPARED SESSION'
              : fixedOccurrence?.isResumable == true
              ? 'In progress'
              : 'Not started',
          adaptationNotice: package.hasAcceptedAdaptation
              ? 'Adapted for today — original authored prescription retained as reference.'
              : null,
          primaryLabel: primaryLabel,
          primaryBusy: _opening,
          onPrimary: _opening || _adapting || _reverting ? null : _open,
          onViewFullSession: widget.onViewFullSession,
          adaptLabel: _canAdapt || _adapting ? (_adapting ? 'Preparing…' : 'Adapt Session') : null,
          onAdapt: _adapt,
          adaptEnabled: _canAdapt && !_adapting,
          revertLabel: _canRevert || _reverting
              ? (_reverting ? 'Reverting…' : 'Revert to Original')
              : null,
          onRevert: _canRevert ? _revert : null,
        ),
        if (_openError != null) ...[
          const SizedBox(height: CohortSpacing.sm),
          Text(_openError!, style: CohortTextStyles.body),
        ],
      ],
    );
  }
}
