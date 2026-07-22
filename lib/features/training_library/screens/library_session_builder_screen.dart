import 'package:flutter/material.dart';

import '../../../core/services/current_coach_identity.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/exercise.dart';
import '../../exercises/services/exercise_catalogue_service.dart';
import '../../../models/protocol_draft.dart';
import '../../coach_studio/governance/controllers/session_governance_controller.dart';
import '../../coach_studio/governance/services/coach_studio_governance_services.dart';
import '../../coach_studio/governance/widgets/session_governance_section.dart';
import '../../session/session_preview_screen.dart';
import '../../session_builder/models/session_builder_display_context.dart';
import '../../session_builder/services/session_builder_validation.dart';
import '../../session_builder/services/programme_session_persistence_validation.dart';
import '../../session_builder/widgets/session_builder_view.dart';
import '../../session_revision/models/session_revision_action_vocabulary.dart';
import '../../session_revision/services/session_revision_service.dart';
import '../services/session_library_authoring_coordinator.dart';
import '../services/session_library_draft_factory.dart';

/// Standalone Session Builder for reusable coach Sessions (M4).
class LibrarySessionBuilderScreen extends StatefulWidget {
  const LibrarySessionBuilderScreen({
    super.key,
    required this.coordinator,
    this.coachIdentity,
    this.initialDraft,
    this.isEdit = false,
    this.loadExercises,
    this.governanceController,
    this.revisionService,
  });

  final SessionLibraryAuthoringCoordinator coordinator;
  final CurrentCoachIdentity? coachIdentity;
  final ProtocolDraft? initialDraft;
  final bool isEdit;
  final Future<List<Exercise>> Function()? loadExercises;
  final SessionGovernanceController? governanceController;
  final SessionRevisionService? revisionService;

  @override
  State<LibrarySessionBuilderScreen> createState() =>
      _LibrarySessionBuilderScreenState();
}

class _LibrarySessionBuilderScreenState extends State<LibrarySessionBuilderScreen> {
  late ProtocolDraft _draft;
  List<String> _feedbackMessages = const [];
  String? _coachMessage;
  bool _isSaving = false;
  late final Future<List<Exercise>> _exercisesFuture;
  SessionGovernanceController? _governanceController;
  late final SessionRevisionService _revisionService;
  bool _ownsGovernanceController = false;

  bool get _showGovernance =>
      widget.isEdit && _draft.protocolId.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft ??
        SessionLibraryDraftFactory.createBlankReusableSessionDraft(
          ownerId: widget.coachIdentity?.coachId,
        );
    _exercisesFuture = widget.loadExercises?.call() ??
        ExerciseCatalogueService().loadPublishedExercises();
    _revisionService = widget.revisionService ??
        CoachStudioGovernanceServices.createRevisionService();
    _initGovernanceController();
  }

  void _initGovernanceController() {
    if (!_showGovernance) return;
    if (widget.governanceController != null) {
      _governanceController = widget.governanceController;
      return;
    }
    _ownsGovernanceController = true;
    _governanceController = CoachStudioGovernanceServices.createSessionGovernanceController(
      protocolId: _draft.protocolId,
      sessionDisplayName: _draft.name,
    );
  }

  @override
  void dispose() {
    if (_ownsGovernanceController) {
      _governanceController?.dispose();
    }
    super.dispose();
  }

  SessionBuilderDisplayContext get _displayContext =>
      SessionBuilderDisplayContext.librarySession();

  void _onDraftChanged(ProtocolDraft draft) {
    setState(() {
      _draft = draft;
      _coachMessage = null;
    });
    _governanceController?.updateSessionDisplayName(draft.name);
  }

  void _onGovernanceDraftChanged(ProtocolDraft draft) {
    setState(() => _draft = draft);
    _governanceController?.updateSessionDisplayName(draft.name);
  }

  void _onGovernanceDeleted() {
    Navigator.pop(context);
  }

  bool get _canEditContent {
    if (!_showGovernance) return true;
    return _governanceController?.isEditAllowed ?? true;
  }

  void _cancel() {
    Navigator.pop(context);
  }

  void _preview() {
    final messages = SessionBuilderValidation.previewReadinessMessages(_draft);
    if (messages.isNotEmpty) {
      setState(() => _feedbackMessages = messages);
      return;
    }

    setState(() => _feedbackMessages = const []);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionPreviewScreen(draft: _draft),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving || !_canEditContent) return;

    final validationMessages =
        ProgrammeSessionPersistenceValidation.validateForSave(_draft);
    if (validationMessages.isNotEmpty) {
      setState(() {
        _feedbackMessages = validationMessages;
        _coachMessage = validationMessages.first;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _feedbackMessages = const [];
      _coachMessage = null;
    });

    final result = widget.isEdit
        ? await widget.coordinator.updateSession(draft: _draft)
        : await widget.coordinator.createSession(draft: _draft);

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.pop(context, result);
      return;
    }

    setState(() {
      _isSaving = false;
      _coachMessage = result.coachMessage;
      _feedbackMessages = result.warnings;
      if (result.persistedDraft != null) {
        _draft = result.persistedDraft!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Exercise>>(
          future: _exercisesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Loading exercises...'),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(onPressed: _cancel, child: const Text('← Cancel')),
                    const SizedBox(height: CohortSpacing.md),
                    const Text(
                      'We could not load exercises right now.',
                      style: CohortTextStyles.body,
                    ),
                  ],
                ),
              );
            }

            final exercises = snapshot.data ?? const [];

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton(
                          onPressed: _isSaving ? null : _cancel,
                          child: const Text('← Cancel'),
                        ),
                        const SizedBox(height: CohortSpacing.md),
                        const SectionTitle('Training Library'),
                        const SizedBox(height: CohortSpacing.md),
                        Text(
                          _displayContext.title,
                          style: CohortTextStyles.h1,
                        ),
                        const SizedBox(height: CohortSpacing.sm),
                        Text(
                          widget.isEdit
                              ? 'Edit this reusable Session. Changes apply wherever this Session is referenced.'
                              : 'Create a reusable Session for your Session Library.',
                          style: CohortTextStyles.body.copyWith(
                            color: CohortColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: CohortSpacing.xl),
                        if (_showGovernance && _governanceController != null) ...[
                          SessionGovernanceSection(
                            controller: _governanceController!,
                            revisionService: _revisionService,
                            draft: _draft,
                            onDraftChanged: _onGovernanceDraftChanged,
                            onDeleted: _onGovernanceDeleted,
                          ),
                          if (!_canEditContent) ...[
                            Text(
                              _governanceController!
                                      .decisionFor(SessionRevisionAction.edit)
                                      ?.userMessage ??
                                  'This Session Revision cannot be edited in place.',
                              style: CohortTextStyles.body.copyWith(
                                color: CohortColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: CohortSpacing.lg),
                          ],
                        ],
                        AbsorbPointer(
                          absorbing: !_canEditContent,
                          child: Opacity(
                            opacity: _canEditContent ? 1 : 0.55,
                            child: SessionBuilderView(
                              draft: _draft,
                              exercises: exercises,
                              displayContext: _displayContext,
                              capabilities:
                                  SessionBuilderCapabilities.librarySession(),
                              onDraftChanged: _onDraftChanged,
                              validationMessages: _feedbackMessages,
                            ),
                          ),
                        ),
                        if (_coachMessage != null) ...[
                          const SizedBox(height: CohortSpacing.lg),
                          Text(
                            _coachMessage!,
                            style: CohortTextStyles.body.copyWith(
                              color: CohortColors.danger,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CohortButton(
                        label: 'Preview',
                        onPressed: _isSaving ? () {} : _preview,
                      ),
                      const SizedBox(height: CohortSpacing.md),
                      CohortButton(
                        label: _isSaving
                            ? 'Saving session…'
                            : (widget.isEdit ? 'Save Session' : 'Save Session'),
                        onPressed: (_isSaving || !_canEditContent) ? () {} : _save,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
