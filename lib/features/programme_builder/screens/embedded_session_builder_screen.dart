import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/cohort_button.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/exercise.dart';
import '../../../models/protocol_draft.dart';
import '../../../models/training_content_vocabulary.dart';
import '../../programme_builder/models/cohort_protocol_customisation_result.dart';
import '../../programme_builder/models/programme_session_authoring_result.dart';
import '../../programme_builder/services/cohort_protocol_customisation_coordinator.dart';
import '../../programme_builder/services/programme_session_authoring_coordinator.dart';
import '../../session/session_preview_screen.dart';
import '../../session_builder/diagnostics/embedded_session_builder_diagnostics.dart';
import '../../session_builder/models/cohort_protocol_copy_destination.dart';
import '../../session_builder/models/programme_session_authoring_context.dart';
import '../../session_builder/models/session_builder_display_context.dart';
import '../../session_builder/models/session_builder_host_mode.dart';
import '../../session_builder/services/programme_session_draft_factory.dart';
import '../../session_builder/services/programme_session_persistence_validation.dart';
import '../../session_builder/services/session_builder_validation.dart';
import '../../session_builder/widgets/session_builder_view.dart';

/// Programme-native Session Builder route with Save & Attach (M3/M5).
class EmbeddedSessionBuilderScreen extends StatefulWidget {
  const EmbeddedSessionBuilderScreen({
    super.key,
    required this.authoringContext,
    required this.coordinator,
    this.customisationCoordinator,
    this.initialDraft,
    this.loadExercises,
  });

  final ProgrammeSessionAuthoringContext authoringContext;
  final ProgrammeSessionAuthoringCoordinator coordinator;
  final CohortProtocolCustomisationCoordinator? customisationCoordinator;
  final ProtocolDraft? initialDraft;
  final Future<List<Exercise>> Function()? loadExercises;

  @override
  State<EmbeddedSessionBuilderScreen> createState() =>
      _EmbeddedSessionBuilderScreenState();
}

class _EmbeddedSessionBuilderScreenState
    extends State<EmbeddedSessionBuilderScreen> {
  late ProtocolDraft _draft;
  List<String> _feedbackMessages = const [];
  String? _coachMessage;
  ProgrammeSessionPartialState? _partialState;
  bool _isSaving = false;
  bool _libraryAttachPending = false;
  late final Future<List<Exercise>> _exercisesFuture;
  CohortProtocolCopyDestination _copyDestination =
      CohortProtocolCopyDestination.programmeOnly;

  bool get _isEdit => widget.authoringContext.authoringIntent ==
      ProgrammeSessionAuthoringIntent.editCoachSession;

  bool get _isCopy => widget.authoringContext.authoringIntent ==
      ProgrammeSessionAuthoringIntent.copyCohortProtocol;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft ??
        ProgrammeSessionDraftFactory.createBlankProgrammeSessionDraft(
          widget.authoringContext,
        );
    _exercisesFuture = widget.loadExercises?.call() ??
        Future<List<Exercise>>.value(const []);

    EmbeddedSessionBuilderDiagnostics.log(
      'opened intent=${widget.authoringContext.authoringIntent.name} '
      'version=${widget.authoringContext.programmeVersionId} '
      'slot=${widget.authoringContext.slotLocalId}',
    );
  }

  SessionBuilderDisplayContext get _displayContext {
    return SessionBuilderDisplayContext.embeddedProgrammeSession(
      programmeLocationLabel:
          widget.authoringContext.programmeLocationLabel ?? '',
    );
  }

  void _onDraftChanged(ProtocolDraft draft) {
    setState(() {
      _draft = draft;
      _partialState = null;
      _coachMessage = null;
    });
    EmbeddedSessionBuilderDiagnostics.log(
      'draftChanged steps=${draft.steps.length}',
    );
  }

  void _setCopyDestination(CohortProtocolCopyDestination destination) {
    setState(() {
      _copyDestination = destination;
      _partialState = null;
      _coachMessage = null;
      _libraryAttachPending = false;
      _draft = _draft.copyWith(
        authoringScope: destination ==
                CohortProtocolCopyDestination.programmeOnly
            ? TrainingAuthoringScope.programmeOnly
            : TrainingAuthoringScope.coachPrivate,
        programmeVersionId: destination ==
                CohortProtocolCopyDestination.programmeOnly
            ? widget.authoringContext.programmeVersionId
            : null,
        published: destination == CohortProtocolCopyDestination.sessionLibrary,
      );
    });
  }

  void _cancel() {
    EmbeddedSessionBuilderDiagnostics.log(
      'cancelled slot=${widget.authoringContext.slotLocalId}',
    );
    Navigator.pop(
      context,
      const ProgrammeSessionAuthoringResult(
        status: ProgrammeSessionAuthoringStatus.cancelled,
      ),
    );
  }

  void _preview() {
    final messages = SessionBuilderValidation.previewReadinessMessages(_draft);
    EmbeddedSessionBuilderDiagnostics.log(
      'preview requested valid=${messages.isEmpty}',
    );

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

  Future<void> _saveAndAttach() async {
    if (_isSaving) return;

    final validationMessages =
        ProgrammeSessionPersistenceValidation.validateForSave(_draft);
    if (validationMessages.isNotEmpty) {
      setState(() {
        _feedbackMessages = validationMessages;
        _coachMessage = validationMessages.first;
        _partialState = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _feedbackMessages = const [];
      _coachMessage = null;
      _partialState = null;
      _libraryAttachPending = false;
    });

    if (_isCopy && widget.customisationCoordinator != null) {
      await _saveCopy();
      return;
    }

    final result = await widget.coordinator.saveAndAttach(
      context: widget.authoringContext,
      draft: _draft,
    );

    if (!mounted) return;
    _handleProgrammeResult(result);
  }

  Future<void> _saveCopy() async {
    final customisationCoordinator = widget.customisationCoordinator!;

    final CohortProtocolCustomisationResult result;
    if (_copyDestination == CohortProtocolCopyDestination.programmeOnly) {
      result = await customisationCoordinator.saveProgrammeCopy(
        context: widget.authoringContext,
        draft: _draft,
      );
    } else {
      result = await customisationCoordinator.saveLibraryCopy(
        context: widget.authoringContext,
        draft: _draft,
      );
    }

    if (!mounted) return;

    final programmeResult = result.toProgrammeAuthoringResult();
    if (programmeResult != null) {
      _handleProgrammeResult(programmeResult);
      return;
    }

    setState(() {
      _isSaving = false;
      _coachMessage = result.coachMessage;
      _feedbackMessages = result.warnings;
      _partialState = result.partialState;
      _libraryAttachPending =
          result.status == CohortProtocolCustomisationStatus.savedAttachFailed &&
              _copyDestination == CohortProtocolCopyDestination.sessionLibrary;
      if (result.persistedDraft != null) {
        _draft = result.persistedDraft!;
      }
    });
  }

  void _handleProgrammeResult(ProgrammeSessionAuthoringResult result) {
    if (result.isAttached) {
      Navigator.pop(context, result);
      return;
    }

    setState(() {
      _isSaving = false;
      _coachMessage = result.coachMessage;
      _feedbackMessages = result.warnings;
      _partialState = result.partialState;
      if (result.persistedDraft != null) {
        _draft = result.persistedDraft!;
      }
    });
  }

  Future<void> _retryAttach() async {
    final partial = _partialState;
    if (partial == null || _isSaving) return;

    setState(() {
      _isSaving = true;
      _coachMessage = null;
    });

    if (_libraryAttachPending && widget.customisationCoordinator != null) {
      final result =
          await widget.customisationCoordinator!.retryLibraryAttach(
        context: widget.authoringContext,
        savedContentId: partial.savedContentId,
        displayTitle: _draft.name.trim(),
      );

      if (!mounted) return;

      final programmeResult = result.toProgrammeAuthoringResult();
      if (programmeResult != null) {
        _handleProgrammeResult(programmeResult);
        return;
      }

      setState(() {
        _isSaving = false;
        _coachMessage = result.coachMessage;
        _partialState = result.partialState ?? partial;
      });
      return;
    }

    final result = await widget.coordinator.retryAttach(
      context: widget.authoringContext,
      savedContentId: partial.savedContentId,
      displayTitle: _draft.name.trim(),
    );

    if (!mounted) return;
    _handleProgrammeResult(result);
  }

  @override
  Widget build(BuildContext context) {
    final locationLabel = widget.authoringContext.programmeLocationLabel;

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
                    TextButton(
                      onPressed: _cancel,
                      child: const Text('← Cancel'),
                    ),
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
                        const SectionTitle('Programme Builder'),
                        const SizedBox(height: CohortSpacing.md),
                        Text(
                          _displayContext.title,
                          style: CohortTextStyles.h1,
                        ),
                        if (locationLabel != null) ...[
                          const SizedBox(height: CohortSpacing.xs),
                          Text(
                            locationLabel,
                            style: CohortTextStyles.body.copyWith(
                              color: CohortColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: CohortSpacing.sm),
                        Text(
                          _subtitle,
                          style: CohortTextStyles.body.copyWith(
                            color: CohortColors.textSecondary,
                          ),
                        ),
                        if (_isCopy) ...[
                          const SizedBox(height: CohortSpacing.lg),
                          _CopyDestinationSelector(
                            destination: _copyDestination,
                            enabled: !_isSaving,
                            onChanged: _setCopyDestination,
                          ),
                          if (_copyDestination ==
                              CohortProtocolCopyDestination.sessionLibrary) ...[
                            const SizedBox(height: CohortSpacing.md),
                            const _LiveReferenceWarning(),
                          ],
                        ],
                        const SizedBox(height: CohortSpacing.xl),
                        SessionBuilderView(
                          draft: _draft,
                          exercises: exercises,
                          displayContext: _displayContext,
                          capabilities:
                              SessionBuilderCapabilities.embeddedCoachSession(),
                          onDraftChanged: _onDraftChanged,
                          validationMessages: _feedbackMessages,
                        ),
                        if (_coachMessage != null) ...[
                          const SizedBox(height: CohortSpacing.lg),
                          Text(
                            _coachMessage!,
                            style: CohortTextStyles.body.copyWith(
                              color: _partialState == null
                                  ? CohortColors.danger
                                  : CohortColors.warning,
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
                      Row(
                        children: [
                          Expanded(
                            child: CohortButton(
                              label: 'Preview',
                              onPressed: _isSaving ? () {} : _preview,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: CohortSpacing.md),
                      CohortButton(
                        label: _isSaving ? 'Saving session…' : 'Save & Attach',
                        onPressed: _isSaving ? () {} : _saveAndAttach,
                      ),
                      if (_partialState != null) ...[
                        const SizedBox(height: CohortSpacing.md),
                        TextButton(
                          onPressed: _isSaving ? null : _retryAttach,
                          child: const Text('Retry adding to programme'),
                        ),
                      ],
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

  String get _subtitle {
    if (_isCopy) {
      return 'Customise this copy before saving. The original Cohort Protocol stays unchanged.';
    }
    if (_isEdit) {
      return 'Edit this programme session. Changes save immediately; use Save programme to persist the slot assignment.';
    }
    return 'Build a session for this programme slot. The session saves when you attach it; use Save programme to persist the slot assignment.';
  }
}

class _CopyDestinationSelector extends StatelessWidget {
  const _CopyDestinationSelector({
    required this.destination,
    required this.enabled,
    required this.onChanged,
  });

  final CohortProtocolCopyDestination destination;
  final bool enabled;
  final ValueChanged<CohortProtocolCopyDestination> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Save options', style: CohortTextStyles.cardTitle),
        const SizedBox(height: CohortSpacing.sm),
        RadioListTile<CohortProtocolCopyDestination>(
          value: CohortProtocolCopyDestination.programmeOnly,
          groupValue: destination,
          onChanged: enabled
              ? (value) {
                  if (value != null) onChanged(value);
                }
              : null,
          title: const Text('This programme only'),
          contentPadding: EdgeInsets.zero,
        ),
        RadioListTile<CohortProtocolCopyDestination>(
          value: CohortProtocolCopyDestination.sessionLibrary,
          groupValue: destination,
          onChanged: enabled
              ? (value) {
                  if (value != null) onChanged(value);
                }
              : null,
          title: const Text('Session Library'),
          contentPadding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _LiveReferenceWarning extends StatelessWidget {
  const _LiveReferenceWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(CohortSpacing.md),
      decoration: BoxDecoration(
        color: CohortColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Changes to this library Session may update other programmes using it.',
        style: CohortTextStyles.body.copyWith(color: CohortColors.warning),
      ),
    );
  }
}
