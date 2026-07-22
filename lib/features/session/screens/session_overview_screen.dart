import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/cohort_card.dart';
import '../../../core/widgets/section_title.dart';
import '../../adaptation/services/adaptation_prescription_service.dart';
import '../../performance/controllers/performance_capture_controller.dart';
import '../../performance/services/performance_record_save_coordinator.dart';
import '../../programme/models/programme_execution_context.dart';
import '../controllers/session_execution_controller.dart';
import '../models/session_execution_plan.dart';
import '../models/session_execution_status.dart';
import '../services/session_execution_loader.dart';
import '../widgets/athlete/athlete_block_card.dart';
import '../widgets/athlete/athlete_session_components.dart';
import '../services/session_execution_launcher.dart';
import 'active_session_screen.dart';

class SessionOverviewScreen extends StatefulWidget {
  const SessionOverviewScreen({
    super.key,
    required this.protocolId,
    this.displayTitle,
    this.trainingSessionId,
    this.programmeContext,
    this.programmeContextLabel,
    this.sessionGoal,
    this.adaptationNotice,
    this.athleteId,
    SessionExecutionLoader? loader,
    PerformanceRecordSaveCoordinator? saveCoordinator,
    SessionExecutionLauncher? sessionLauncher,
  })  : _loader = loader,
        _saveCoordinator = saveCoordinator,
        _sessionLauncher = sessionLauncher;

  final String protocolId;
  final String? displayTitle;
  final int? trainingSessionId;
  final ProgrammeExecutionContext? programmeContext;
  final String? programmeContextLabel;
  final String? sessionGoal;
  final String? adaptationNotice;
  final String? athleteId;
  final SessionExecutionLoader? _loader;
  final PerformanceRecordSaveCoordinator? _saveCoordinator;
  final SessionExecutionLauncher? _sessionLauncher;

  @override
  State<SessionOverviewScreen> createState() => _SessionOverviewScreenState();
}

class _SessionOverviewScreenState extends State<SessionOverviewScreen> {
  late final SessionExecutionLoader _loader =
      widget._loader ?? SessionExecutionLoader();
  late final PerformanceRecordSaveCoordinator _saveCoordinator =
      widget._saveCoordinator ?? PerformanceRecordSaveCoordinator();
  late final SessionExecutionLauncher _sessionLauncher =
      widget._sessionLauncher ?? SessionExecutionLauncher();
  late final AdaptationPrescriptionService _prescriptionService =
      AdaptationPrescriptionService();
  late Future<SessionExecutionLoadResult> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadSession();
  }

  Future<SessionExecutionLoadResult> _loadSession() async {
    var loadOverrides = const <String, String>{};
    final programmeContext = widget.programmeContext;
    if (programmeContext != null && programmeContext.isProgrammeBacked) {
      loadOverrides = await _prescriptionService.loadLoadOverrides(
        assignmentId: programmeContext.assignmentId,
        sessionSlotId: programmeContext.sessionSlotId,
      );
    }

    return _loader.load(
      protocolId: widget.protocolId,
      displayTitle: widget.displayTitle,
      programmeContextLabel: widget.programmeContextLabel,
      prescriptionLoadOverrides: loadOverrides,
    );
  }

  String get _sessionKey => AthleteSessionMemoryStore.sessionKey(
        protocolId: widget.protocolId,
        trainingSessionId: widget.trainingSessionId,
      );

  Future<void> _startSession(SessionExecutionPlan plan) async {
    final trainingSessionId = widget.trainingSessionId;
    final athleteId = widget.athleteId;

    if (trainingSessionId != null && athleteId != null) {
      await _sessionLauncher.launchActiveSessionWithPlan(
        context: context,
        plan: plan,
        protocolId: widget.protocolId,
        trainingSessionId: trainingSessionId,
        athleteId: athleteId,
        programmeContext: widget.programmeContext,
      );
      return;
    }

    final restored = AthleteSessionMemoryStore.instance.read(_sessionKey);
    final controller = SessionExecutionController(
      plan: plan,
      sessionKey: _sessionKey,
      restoredState: restored,
    );

    final continueSession =
        restored?.sessionStatus == SessionExecutionStatus.inProgress;

    if (!continueSession) {
      controller.startSession();
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveSessionScreen(
          controller: controller,
          performanceController:
              PerformanceCaptureController.initializeFromExecutionPlan(
            plan: plan,
            athleteId: athleteId ?? 'preview',
            trainingSessionId: trainingSessionId ?? 0,
            programmeContext: widget.programmeContext,
          ),
          trainingSessionId: trainingSessionId,
          programmeContext: widget.programmeContext,
          athleteId: athleteId,
          saveCoordinator: _saveCoordinator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<SessionExecutionLoadResult>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Loading session...', style: CohortTextStyles.body),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: AthleteFeedbackState(
                  title: 'Could not load session',
                  message: 'Please try again or return home.',
                  actionLabel: 'Go back',
                  onAction: () => Navigator.pop(context),
                ),
              );
            }

            final plan = snapshot.data!.plan;
            final restored = AthleteSessionMemoryStore.instance.read(_sessionKey);
            final canStart = plan.hasExecutableBlocks;
            final buttonLabel =
                restored?.sessionStatus == SessionExecutionStatus.inProgress
                    ? 'Continue Session'
                    : 'Start Session';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Back'),
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  AthleteSessionHeader(
                    title: plan.sessionTitle,
                    subtitle: plan.programmeContextLabel,
                  ),
                  const SizedBox(height: CohortSpacing.lg),
                  CohortCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Session overview', style: CohortTextStyles.cardTitle),
                        const SizedBox(height: CohortSpacing.md),
                        if (plan.durationMin != null)
                          Text(
                            '${plan.durationMin} min estimated',
                            style: CohortTextStyles.body,
                          ),
                        Text(
                          '${plan.blockCount} block${plan.blockCount == 1 ? '' : 's'}',
                          style: CohortTextStyles.small,
                        ),
                        if (widget.sessionGoal?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: CohortSpacing.md),
                          Text(widget.sessionGoal!, style: CohortTextStyles.body),
                        ],
                        if (widget.adaptationNotice?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: CohortSpacing.md),
                          Text(
                            widget.adaptationNotice!,
                            style: CohortTextStyles.small,
                          ),
                        ],
                        if (plan.coachNotes?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: CohortSpacing.md),
                          Text(
                            'Coach notes',
                            style: CohortTextStyles.small,
                          ),
                          const SizedBox(height: CohortSpacing.xs),
                          Text(plan.coachNotes!, style: CohortTextStyles.body),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  const SectionTitle('Blocks'),
                  const SizedBox(height: CohortSpacing.md),
                  for (final block in plan.blocks)
                    SessionOverviewBlockSummary(block: block),
                  const SizedBox(height: CohortSpacing.xl),
                  CohortButton(
                    label: buttonLabel,
                    onPressed: canStart ? () => _startSession(plan) : () {},
                  ),
                  if (!canStart) ...[
                    const SizedBox(height: CohortSpacing.sm),
                    const Text(
                      'This session has no executable blocks yet.',
                      style: CohortTextStyles.small,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
