import 'package:flutter/material.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../programme/models/programme_execution_context.dart';
import '../controllers/performance_capture_controller.dart';
import '../models/training_session_record_status.dart';
import '../services/performance_record_save_coordinator.dart';
import '../widgets/performance_capture_widgets.dart';
import '../../session/screens/session_complete_screen.dart';
import '../../session/controllers/session_execution_controller.dart';

class SessionFinishReviewScreen extends StatefulWidget {
  const SessionFinishReviewScreen({
    super.key,
    required this.performanceController,
    required this.executionController,
    required this.trainingSessionId,
    required this.athleteId,
    this.programmeContext,
    this.saveCoordinator,
  });

  final PerformanceCaptureController performanceController;
  final SessionExecutionController executionController;
  final int trainingSessionId;
  final String athleteId;
  final ProgrammeExecutionContext? programmeContext;
  final PerformanceRecordSaveCoordinator? saveCoordinator;

  @override
  State<SessionFinishReviewScreen> createState() =>
      _SessionFinishReviewScreenState();
}

class _SessionFinishReviewScreenState extends State<SessionFinishReviewScreen> {
  late PerformanceCaptureController _performanceController =
      widget.performanceController;
  final _noteController = TextEditingController();
  PerformanceSaveState _saveState = PerformanceSaveState.idle;
  String? _errorMessage;

  late final PerformanceRecordSaveCoordinator _saveCoordinator =
      widget.saveCoordinator ?? PerformanceRecordSaveCoordinator();

  @override
  void initState() {
    super.initState();
    _noteController.text = _performanceController.draft.athleteNote ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveAndFinish() async {
    setState(() {
      _saveState = PerformanceSaveState.saving;
      _errorMessage = null;
    });

    _performanceController.updateSessionNote(_noteController.text);

    try {
      final status = _performanceController.resolveCompletionStatus();
      final result = await _saveCoordinator.completeSession(
        controller: _performanceController,
        trainingSessionId: widget.trainingSessionId,
        athleteId: widget.athleteId,
        programmeContext: widget.programmeContext,
        forcedStatus: status,
      );

      widget.executionController.completeSession(
        allowIncomplete: status != TrainingSessionRecordStatus.completed,
      );

      if (!mounted) return;
      setState(() => _saveState = PerformanceSaveState.saved);

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SessionCompleteScreen(
            state: widget.executionController.state,
            savedRecord: result.record,
            onDone: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveState = PerformanceSaveState.error;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _performanceController.draft;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review Session', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.lg),
              Text(
                '${draft.completedBlockCount} completed · '
                '${draft.skippedBlockCount} skipped · '
                '${draft.incompleteBlockCount} incomplete',
                style: CohortTextStyles.body,
              ),
              const SizedBox(height: CohortSpacing.lg),
              SessionRpeSelector(
                value: draft.overallRpe,
                onChanged: (value) {
                  setState(() {
                    _performanceController.updateSessionRpe(value);
                  });
                },
              ),
              const SizedBox(height: CohortSpacing.lg),
              TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Session note (optional)',
                ),
              ),
              const SizedBox(height: CohortSpacing.lg),
              PerformanceSaveIndicator(
                state: _saveState,
                errorMessage: _errorMessage,
              ),
              const SizedBox(height: CohortSpacing.lg),
              CohortButton(label: 'Save and finish', onPressed: _saveAndFinish),
              const SizedBox(height: CohortSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Return to session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
