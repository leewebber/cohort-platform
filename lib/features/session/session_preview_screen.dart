import 'package:flutter/material.dart';

import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/section_title.dart';
import '../../core/widgets/session_progress_bar.dart';
import '../../core/widgets/session_step_card.dart';
import '../../models/circuit_session_plan.dart';
import '../../models/interval_session_plan.dart';
import '../../models/protocol.dart';
import '../../models/protocol_draft.dart';
import '../../models/protocol_step.dart';
import '../../models/protocol_step_draft.dart';
import '../../models/session_execution_mode.dart';
import '../../models/session_step.dart';
import 'services/circuit_session_plan_builder.dart';
import 'services/interval_session_plan_builder.dart';
import 'services/session_execution_router.dart';
import 'widgets/circuit_session_view.dart';
import 'widgets/interval_session_view.dart';
import 'widgets/shared/preview_mode_banner.dart';
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
  static const _intervalPlanBuilder = IntervalSessionPlanBuilder();
  static const _circuitPlanBuilder = CircuitSessionPlanBuilder();

  static const _sessionFormatToSessionType = {
    'circuit': 'Circuit',
    'structured_strength': 'Strength',
    'intervals': 'Running',
    'recovery_flow': 'Recovery',
  };

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

  _CompiledIntervalPlan? get _compiledIntervalPlan {
    if (_executionMode != SessionExecutionMode.intervals) {
      return null;
    }

    try {
      return _CompiledIntervalPlan(
        plan: _intervalPlanBuilder.build(
          protocol: _protocolFromDraft(widget.draft),
          steps: _protocolStepsFromDraft(widget.draft),
        ),
      );
    } on StateError catch (error) {
      return _CompiledIntervalPlan(error: error.message);
    }
  }

  _CompiledCircuitPlan? get _compiledCircuitPlan {
    if (_executionMode != SessionExecutionMode.circuit) {
      return null;
    }

    try {
      return _CompiledCircuitPlan(
        plan: _circuitPlanBuilder.build(
          protocol: _protocolFromDraft(widget.draft),
          steps: _protocolStepsFromDraft(widget.draft),
        ),
      );
    } on StateError catch (error) {
      return _CompiledCircuitPlan(error: error.message);
    }
  }

  void _exitPreview() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    final mode = _executionMode;
    final intervalCompilation = _compiledIntervalPlan;
    final intervalPlan = intervalCompilation?.plan;
    final intervalPlanError = intervalCompilation?.error;
    final circuitCompilation = _compiledCircuitPlan;
    final circuitPlan = circuitCompilation?.plan;
    final circuitPlanError = circuitCompilation?.error;

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
              const PreviewModeBanner(),
              const SizedBox(height: CohortSpacing.xl),
              const SectionTitle('Session'),
              const SizedBox(height: CohortSpacing.md),
              Text(
                _sessionTitle,
                style: CohortTextStyles.h1,
              ),
              const SizedBox(height: CohortSpacing.xl),
              if (intervalPlanError != null)
                Text(
                  intervalPlanError,
                  style: CohortTextStyles.body,
                )
              else if (circuitPlanError != null)
                Text(
                  circuitPlanError,
                  style: CohortTextStyles.body,
                )
              else if (steps.isEmpty &&
                  mode != SessionExecutionMode.intervals &&
                  mode != SessionExecutionMode.circuit)
                const Text(
                  'No session steps available.',
                  style: CohortTextStyles.body,
                )
              else if (mode == SessionExecutionMode.intervals &&
                  intervalPlan == null)
                const Text(
                  'Unable to compile interval session plan.',
                  style: CohortTextStyles.body,
                )
              else if (mode == SessionExecutionMode.circuit &&
                  circuitPlan == null)
                const Text(
                  'Unable to compile circuit session plan.',
                  style: CohortTextStyles.body,
                )
              else
                _buildExecutionView(
                  mode: mode,
                  steps: steps,
                  intervalPlan: intervalPlan,
                  circuitPlan: circuitPlan,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutionView({
    required SessionExecutionMode mode,
    required List<SessionStep> steps,
    IntervalSessionPlan? intervalPlan,
    CircuitSessionPlan? circuitPlan,
  }) {
    switch (mode) {
      case SessionExecutionMode.circuit:
        if (circuitPlan == null) {
          return const Text(
            'Unable to compile circuit session plan.',
            style: CohortTextStyles.body,
          );
        }

        return CircuitSessionView(
          sessionTitle: _sessionTitle,
          plan: circuitPlan,
          previewMode: true,
          onFinishSession: (_) async => _exitPreview(),
        );
      case SessionExecutionMode.structuredStrength:
        return StrengthSessionView(
          sessionTitle: _sessionTitle,
          steps: steps,
          onFinishSession: (_) async => _exitPreview(),
        );
      case SessionExecutionMode.intervals:
        if (intervalPlan == null) {
          return const Text(
            'Unable to compile interval session plan.',
            style: CohortTextStyles.body,
          );
        }

        return IntervalSessionView(
          sessionTitle: _sessionTitle,
          plan: intervalPlan,
          previewMode: true,
          onFinishSession: (_) async => _exitPreview(),
        );
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

  static List<ProtocolStep> _protocolStepsFromDraft(ProtocolDraft draft) {
    final ordered = List<ProtocolStepDraft>.from(draft.steps)
      ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

    return ordered
        .map(
          (stepDraft) => ProtocolStep(
            id: stepDraft.persistedId ?? 0,
            protocolId: draft.protocolId,
            stepOrder: stepDraft.stepOrder,
            section: stepDraft.section ?? '',
            stepType: stepDraft.stepType ?? '',
            displayStyle: stepDraft.displayStyle ?? 'exercise',
            exerciseId: stepDraft.exerciseId,
            title: stepDraft.title,
            notes: stepDraft.notes,
            metadata: stepDraft.toMetadataMap(),
          ),
        )
        .toList(growable: false);
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

class _CompiledIntervalPlan {
  const _CompiledIntervalPlan({
    this.plan,
    this.error,
  });

  final IntervalSessionPlan? plan;
  final String? error;
}

class _CompiledCircuitPlan {
  const _CompiledCircuitPlan({
    this.plan,
    this.error,
  });

  final CircuitSessionPlan? plan;
  final String? error;
}
