import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/circuit_session_card.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/session_progress_bar.dart';
import '../../core/widgets/session_step_card.dart';
import '../../models/protocol.dart';
import '../../models/protocol_draft.dart';
import '../../models/protocol_step.dart';
import '../../models/protocol_step_draft.dart';
import '../../models/session_execution_mode.dart';
import '../../models/session_step.dart';
import 'services/session_execution_router.dart';
import 'widgets/strength_session_view.dart';

/// In-memory protocol preview for Coach Studio.
///
/// Renders a [ProtocolDraft] through the same execution router and views used
/// by [SessionPlayerScreen], without saving, publishing, or training sessions.
class SessionPreviewScreen extends StatefulWidget {
  const SessionPreviewScreen({
    super.key,
    required this.draft,
  });

  final ProtocolDraft draft;

  @override
  State<SessionPreviewScreen> createState() => _SessionPreviewScreenState();
}

class _SessionPreviewScreenState extends State<SessionPreviewScreen> {
  static const _executionRouter = SessionExecutionRouter();

  static const _sessionFormatToSessionType = {
    'circuit': 'Circuit',
    'structured_strength': 'Strength',
    'intervals': 'Running',
    'recovery_flow': 'Recovery',
  };

  bool _isTimerRunning = false;

  String get _sessionTitle {
    final name = widget.draft.name.trim();
    if (name.isNotEmpty) return name;

    final protocolId = widget.draft.protocolId.trim();
    if (protocolId.isNotEmpty) return protocolId;

    return 'Protocol Preview';
  }

  List<SessionStep> get _steps => _stepsFromDraft(widget.draft);

  SessionExecutionMode get _executionMode {
    return _executionRouter.determineExecutionMode(_protocolFromDraft(widget.draft));
  }

  void _startTimer() {
    setState(() => _isTimerRunning = true);
  }

  void _exitPreview() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final mode = _executionMode;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: _exitPreview,
                child: const Text('← Back to Builder'),
              ),
              const SizedBox(height: CohortSpacing.md),
              const _PreviewBanner(),
              const SizedBox(height: CohortSpacing.xl),
              const SectionTitle('Session'),
              const SizedBox(height: CohortSpacing.md),
              Text(
                _sessionTitle,
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.xl),
              if (steps.isEmpty)
                const Text(
                  'No session steps available.',
                  style: CohortTextStyles.body,
                )
              else
                _buildExecutionView(mode: mode, steps: steps),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutionView({
    required SessionExecutionMode mode,
    required List<SessionStep> steps,
  }) {
    switch (mode) {
      case SessionExecutionMode.circuit:
        return CircuitSessionCard(
          steps: steps,
          isTimerRunning: _isTimerRunning,
          onStartTimer: _startTimer,
          onFinishSession: _exitPreview,
        );
      case SessionExecutionMode.structuredStrength:
        return StrengthSessionView(
          sessionTitle: _sessionTitle,
          steps: steps,
          onFinishSession: (_) async => _exitPreview(),
        );
      case SessionExecutionMode.intervals:
        return _legacyGuidedPlayer(steps);
      case SessionExecutionMode.recoveryFlow:
        return _legacyGuidedPlayer(steps);
    }
  }

  Widget _legacyGuidedPlayer(List<SessionStep> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SessionProgressBar(
          currentStep: steps.first.stepNumber,
          totalSteps: steps.length,
        ),
        const SizedBox(height: CohortSpacing.xl),
        SessionStepCard(
          step: steps.first,
          onComplete: () {},
        ),
      ],
    );
  }

  static Protocol _protocolFromDraft(ProtocolDraft draft) {
    return Protocol(
      protocolId: draft.protocolId,
      name: draft.name,
      sessionType: _resolvedSessionType(draft),
      goal: draft.primaryCapability,
      secondaryCapability: draft.secondaryCapability,
      durationMin: draft.durationMin,
      demand: draft.physiologicalDemand,
      recovery: draft.recoveryCost,
      environment: draft.environment,
      suitableFor: draft.suitableFor,
      technicalComplexity: draft.technicalComplexity,
      requiredEquipment: draft.requiredEquipment,
      optionalEquipment: draft.optionalEquipment,
    );
  }

  static String? _resolvedSessionType(ProtocolDraft draft) {
    final sessionType = draft.sessionType?.trim();
    if (sessionType != null && sessionType.isNotEmpty) {
      return sessionType;
    }

    return _sessionFormatToSessionType[draft.sessionFormat?.trim()];
  }

  static List<SessionStep> _stepsFromDraft(ProtocolDraft draft) {
    final ordered = List<ProtocolStepDraft>.from(draft.steps)
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    return ordered.map(_sessionStepFromDraft).toList(growable: false);
  }

  static SessionStep _sessionStepFromDraft(ProtocolStepDraft draft) {
    final protocolStep = ProtocolStep(
      id: draft.persistedId ?? 0,
      protocolId: '',
      stepOrder: draft.stepOrder,
      section: draft.section ?? '',
      stepType: draft.stepType ?? '',
      displayStyle: draft.displayStyle ?? 'exercise',
      exerciseId: draft.exerciseId,
      title: draft.title,
      notes: draft.notes,
      metadata: draft.toMetadataMap(),
    );

    return SessionStep.fromProtocolStep(protocolStep);
  }
}

class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        color: CohortColors.oliveSoft,
        border: Border.all(color: CohortColors.borderStrong),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PREVIEW MODE',
            style: CohortTextStyles.eyebrow.copyWith(
              color: CohortColors.olive,
            ),
          ),
          const SizedBox(height: CohortSpacing.xs),
          Text(
            'No progress will be saved.',
            style: CohortTextStyles.small,
          ),
        ],
      ),
    );
  }
}
