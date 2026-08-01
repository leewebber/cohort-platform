import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../home/controllers/home_today_session_refresh_controller.dart';
import '../controllers/athlete_programme_controllers.dart';
import '../models/athlete_plan_materialisation.dart';
import '../services/athlete_catalogue_enrolment_services.dart';
import '../services/athlete_plan_materialisation_service.dart';
import 'athlete_programme_selection_screen.dart';

/// Athlete-facing programme overview — enrolment, Start Programme, no prepare.
class AthleteProgrammeScreen extends StatefulWidget {
  const AthleteProgrammeScreen({
    super.key,
    required this.athleteId,
    this.refreshController,
    AthleteProgrammeScreenController? controller,
  }) : _controller = controller;

  final String athleteId;
  final HomeTodaySessionRefreshController? refreshController;
  final AthleteProgrammeScreenController? _controller;

  @override
  State<AthleteProgrammeScreen> createState() => _AthleteProgrammeScreenState();
}

class _AthleteProgrammeScreenState extends State<AthleteProgrammeScreen> {
  late final AthleteProgrammeScreenController _controller =
      widget._controller ??
      AthleteCatalogueEnrolmentServices.createProgrammeScreenController(
        athleteId: widget.athleteId,
      );

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openStartNewProgramme() async {
    final switched = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AthleteProgrammeSelectionScreen(
          athleteId: widget.athleteId,
          refreshController: widget.refreshController,
        ),
      ),
    );

    if (switched == true && mounted) {
      await _controller.load();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _startProgramme() async {
    if (_controller.isStarting) return;
    final result = await _controller.startProgramme();
    if (!mounted || result == null) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isIdempotentAlreadyMaterialised
                ? 'This programme is already started.'
                : 'Programme started today.',
          ),
        ),
      );
      return;
    }

    if (result.status == AthletePlanMaterialisationStatus.legacyPlanConflict) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text('Cannot start programme', style: CohortTextStyles.h2),
          content: Text(
            result.message ??
                'You already have an active plan on this device. '
                    'Switching programmes is not available yet.',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Programme')),
      body: SafeArea(
        child: _controller.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(CohortSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_controller.errorMessage != null) ...[
                      Text(
                        _controller.errorMessage!,
                        style: CohortTextStyles.body.copyWith(
                          color: CohortColors.warning,
                        ),
                      ),
                      const SizedBox(height: CohortSpacing.lg),
                    ],
                    const SectionTitle('Current programme'),
                    const SizedBox(height: CohortSpacing.md),
                    _buildCurrentProgrammeCard(),
                    const SizedBox(height: CohortSpacing.xxl),
                    const SizedBox(height: CohortSpacing.xl),
                    Center(
                      child: TextButton(
                        onPressed: _openStartNewProgramme,
                        style: TextButton.styleFrom(
                          foregroundColor: CohortColors.textMuted,
                          textStyle: CohortTextStyles.muted,
                        ),
                        child: const Text('View programmes'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCurrentProgrammeCard() {
    final assignment = _controller.activeAssignment;
    final version = _controller.activeVersion;

    if (assignment == null) {
      return const CohortCard(
        child: Text(
          'You are not enrolled in a programme yet. Choose a programme to get access.',
          style: CohortTextStyles.body,
        ),
      );
    }

    final name = version?.name ?? assignment.lineageCode;
    final goal = version?.primaryGoal ?? version?.description;
    final duration = version?.durationWeeks;
    final sessions = version?.sessionsPerWeek;

    return CohortCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: CohortTextStyles.h2),
          if (goal != null && goal.trim().isNotEmpty) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(goal.trim(), style: CohortTextStyles.body),
          ],
          if (duration != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text('$duration weeks', style: CohortTextStyles.small),
          ],
          if (sessions != null) ...[
            const SizedBox(height: CohortSpacing.xs),
            Text('$sessions sessions per week', style: CohortTextStyles.small),
          ],
          const SizedBox(height: CohortSpacing.md),
          Text(
            AthletePlanMaterialisationLabels.statusLabel(assignment),
            style: CohortTextStyles.small,
          ),
          if (assignment.isEnrolledOnly) ...[
            const SizedBox(height: CohortSpacing.md),
            Text(
              'Start Programme begins this programme today. '
              'It does not purchase access or open a workout session.',
              style: CohortTextStyles.muted,
            ),
            const SizedBox(height: CohortSpacing.md),
            IgnorePointer(
              ignoring: _controller.isStarting,
              child: Opacity(
                opacity: _controller.isStarting ? 0.6 : 1,
                child: CohortButton(
                  label: _controller.isStarting
                      ? 'Starting…'
                      : 'Start Programme',
                  onPressed: _startProgramme,
                ),
              ),
            ),
          ],
          if (assignment.isMaterialised) ...[
            const SizedBox(height: CohortSpacing.sm),
            Text(
              'Programme started. First session preparation comes next.',
              style: CohortTextStyles.muted,
            ),
          ],
        ],
      ),
    );
  }
}
