import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/text_styles.dart';
import '../../core/widgets/cohort_button.dart';
import '../../core/widgets/cohort_card.dart';
import '../../core/widgets/section_title.dart';
import '../../data/repositories/exercise_repository.dart';
import '../../models/exercise.dart';
import '../../models/protocol_builder_save_result.dart';
import '../../models/protocol_draft.dart';
import '../../models/training_content_vocabulary.dart';
import '../session/session_preview_screen.dart';
import '../session_builder/models/session_builder_display_context.dart';
import '../session_builder/widgets/session_builder_view.dart';
import 'services/protocol_builder_service.dart';

/// Coach-facing protocol authoring screen.
///
/// See `07 Documentation/34_Protocol_Builder.md`. Save persists via
/// [ProtocolBuilderService]; preview remains in-memory only.
class ProtocolBuilderScreen extends StatefulWidget {
  const ProtocolBuilderScreen({
    super.key,
    this.protocolId,
  });

  final String? protocolId;

  @override
  State<ProtocolBuilderScreen> createState() => _ProtocolBuilderScreenState();
}

class _ProtocolBuilderScreenState extends State<ProtocolBuilderScreen> {
  final _exerciseRepository = ExerciseRepository();
  final _builderService = ProtocolBuilderService();

  late final Future<List<Exercise>> _bootstrapFuture;

  ProtocolDraft _draft = const ProtocolDraft(
    protocolId: '',
    name: '',
    steps: [],
  );

  List<String> _validationMessages = [];
  bool _isSaving = false;
  bool _isPublishing = false;
  bool _isUnpublishing = false;
  bool _protocolIdLocked = false;
  ProtocolBuilderSaveResult? _saveSuccessResult;
  String? _saveErrorMessage;

  bool get _isBusy => _isSaving || _isPublishing || _isUnpublishing;
  bool get _isPublished => _draft.published;

  @override
  void initState() {
    super.initState();
    _protocolIdLocked = widget.protocolId != null;
    _bootstrapFuture = _loadBootstrap();
  }

  Future<List<Exercise>> _loadBootstrap() async {
    final exercises = await _exerciseRepository.getExercises();

    if (widget.protocolId != null) {
      final loaded = await _builderService.loadProtocol(widget.protocolId!);
      if (mounted) {
        setState(() {
          _draft = loaded;
          _protocolIdLocked = true;
          _validationMessages = [];
          _saveSuccessResult = null;
          _saveErrorMessage = null;
        });
      }
    }

    return exercises;
  }

  void _onDraftChanged(ProtocolDraft draft) {
    setState(() => _draft = draft);
  }

  void _saveDraft() async {
    if (_isBusy) return;

    setState(() {
      _isSaving = true;
      _validationMessages = [];
      _saveSuccessResult = null;
      _saveErrorMessage = null;
    });

    try {
      final result = await _builderService.saveDraft(_draft);

      if (!mounted) return;

      setState(() {
        _saveSuccessResult = result;
        _isSaving = false;
        _protocolIdLocked = true;
        _draft = _draft.copyWith(published: false);
      });

      await _showSaveSuccessDialog(result);
    } on ProtocolBuilderException catch (error) {
      if (!mounted) return;

      setState(() {
        _validationMessages = [error.message];
        _isSaving = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[ProtocolBuilder] save failed: $error');
      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        _saveErrorMessage =
            'We could not save your protocol right now. Please try again.';
        _isSaving = false;
      });
    }
  }

  void _publishDraft() async {
    if (_isBusy) return;

    setState(() {
      _isPublishing = true;
      _validationMessages = [];
      _saveSuccessResult = null;
      _saveErrorMessage = null;
    });

    try {
      final result = await _builderService.publishDraft(_draft);

      if (!mounted) return;

      setState(() {
        _saveSuccessResult = result;
        _isPublishing = false;
        _protocolIdLocked = true;
        _draft = _draft.copyWith(published: true);
      });

      await _showPublishSuccessDialog(result);
    } on ProtocolBuilderException catch (error) {
      if (!mounted) return;

      setState(() {
        _validationMessages = [error.message];
        _isPublishing = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[ProtocolBuilder] publish failed: $error');
      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        _saveErrorMessage =
            'We could not publish your protocol right now. Please try again.';
        _isPublishing = false;
      });
    }
  }

  void _savePublishedChanges() async {
    if (_isBusy) return;

    setState(() {
      _isSaving = true;
      _validationMessages = [];
      _saveSuccessResult = null;
      _saveErrorMessage = null;
    });

    try {
      final result =
          await _builderService.savePublishedChanges(_draft);

      if (!mounted) return;

      setState(() {
        _saveSuccessResult = result;
        _isSaving = false;
        _protocolIdLocked = true;
        _draft = _draft.copyWith(published: true);
      });

      await _showSavedChangesDialog(result);
    } on ProtocolBuilderException catch (error) {
      if (!mounted) return;

      setState(() {
        _validationMessages = [error.message];
        _isSaving = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[ProtocolBuilder] save changes failed: $error');
      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        _saveErrorMessage =
            'We could not save your changes right now. Please try again.';
        _isSaving = false;
      });
    }
  }

  void _unpublishDraft() async {
    if (_isBusy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text(
            'Unpublish protocol?',
            style: CohortTextStyles.h2,
          ),
          content: Text(
            'This will remove the protocol from the published list. '
            'Athletes will no longer see it until you publish again.',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'Unpublish',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.danger,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isUnpublishing = true;
      _validationMessages = [];
      _saveSuccessResult = null;
      _saveErrorMessage = null;
    });

    try {
      final result = await _builderService.unpublishDraft(_draft);

      if (!mounted) return;

      setState(() {
        _saveSuccessResult = result;
        _isUnpublishing = false;
        _protocolIdLocked = true;
        _draft = _draft.copyWith(published: false);
      });

      await _showUnpublishSuccessDialog(result);
    } on ProtocolBuilderException catch (error) {
      if (!mounted) return;

      setState(() {
        _validationMessages = [error.message];
        _isUnpublishing = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[ProtocolBuilder] unpublish failed: $error');
      debugPrint(stackTrace.toString());

      if (!mounted) return;

      setState(() {
        _saveErrorMessage =
            'We could not unpublish your protocol right now. Please try again.';
        _isUnpublishing = false;
      });
    }
  }

  Future<void> _showSaveSuccessDialog(ProtocolBuilderSaveResult result) async {
    final startNewDraft = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text(
            'Draft saved',
            style: CohortTextStyles.h2,
          ),
          content: Text(
            '${result.message}\n\nStart a new draft?',
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Keep editing',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                'New draft',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.olive,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (startNewDraft == true && mounted) {
      _clearDraft();
    }
  }

  Future<void> _showPublishSuccessDialog(
    ProtocolBuilderSaveResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text(
            'Protocol published',
            style: CohortTextStyles.h2,
          ),
          content: Text(
            result.message,
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Continue',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.olive,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSavedChangesDialog(
    ProtocolBuilderSaveResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text(
            'Changes saved',
            style: CohortTextStyles.h2,
          ),
          content: Text(
            result.message,
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Continue',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.olive,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showUnpublishSuccessDialog(
    ProtocolBuilderSaveResult result,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: CohortColors.surface,
          title: Text(
            'Protocol unpublished',
            style: CohortTextStyles.h2,
          ),
          content: Text(
            result.message,
            style: CohortTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Continue',
                style: CohortTextStyles.body.copyWith(
                  color: CohortColors.olive,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearDraft() {
    setState(() {
      _draft = const ProtocolDraft(
        protocolId: '',
        name: '',
        steps: [],
        contentKind: TrainingContentKind.cohortProtocol,
        authoringScope: TrainingAuthoringScope.cohortGlobal,
        endorsementStatus: TrainingEndorsementStatus.cohortEndorsed,
      );
      _protocolIdLocked = false;
      _validationMessages = [];
      _saveSuccessResult = null;
      _saveErrorMessage = null;
    });
  }

  void _previewDraft() {
    if (_isBusy) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionPreviewScreen(draft: _draft),
      ),
    );
  }

  String _successEyebrow(ProtocolBuilderSaveResult result) {
    if (result.message.startsWith('Unpublished')) {
      return 'Unpublished';
    }

    if (result.message.startsWith('Saved changes')) {
      return 'Changes saved';
    }

    if (result.published) {
      return 'Published';
    }

    return 'Draft saved';
  }

  @override
  Widget build(BuildContext context) {
    final displayContext = SessionBuilderDisplayContext.cohortProtocolAdmin(
      subtitle:
          'Create structured sessions with metadata and ordered steps. '
          'Save keeps unpublished drafts; publish makes them live. '
          'Preview shows the athlete session without saving.',
    );

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<Exercise>>(
          future: _bootstrapFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  widget.protocolId != null
                      ? 'Loading draft...'
                      : 'Loading exercises...',
                  style: CohortTextStyles.body,
                ),
              );
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('← Back'),
                    ),
                    const SizedBox(height: CohortSpacing.md),
                    Text(
                      snapshot.error is ProtocolBuilderException
                          ? (snapshot.error! as ProtocolBuilderException)
                              .message
                          : 'We could not open this draft right now.',
                      style: CohortTextStyles.body,
                    ),
                  ],
                ),
              );
            }

            final exercises = snapshot.data ?? [];

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
                  const SectionTitle('Coach Studio'),
                  const SizedBox(height: CohortSpacing.md),
                  Text(
                    displayContext.title,
                    style: CohortTextStyles.h1,
                  ),
                  if (displayContext.subtitle != null) ...[
                    const SizedBox(height: CohortSpacing.sm),
                    Text(
                      displayContext.subtitle!,
                      style: CohortTextStyles.body,
                    ),
                  ],
                  const SizedBox(height: CohortSpacing.xl),
                  SessionBuilderView(
                    key: ValueKey(_draft.protocolId),
                    draft: _draft,
                    exercises: exercises,
                    displayContext: displayContext,
                    capabilities: SessionBuilderCapabilities.cohortProtocolAdmin(
                      protocolIdLocked: _protocolIdLocked,
                    ),
                    onDraftChanged: _onDraftChanged,
                    validationMessages: _validationMessages,
                    protocolIdLocked: _protocolIdLocked,
                  ),
                  const SizedBox(height: CohortSpacing.xl),
                  if (_saveSuccessResult != null) ...[
                    CohortCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _successEyebrow(_saveSuccessResult!),
                            style: CohortTextStyles.eyebrow.copyWith(
                              color: CohortColors.success,
                            ),
                          ),
                          const SizedBox(height: CohortSpacing.sm),
                          Text(
                            _saveSuccessResult!.message,
                            style: CohortTextStyles.body,
                          ),
                          const SizedBox(height: CohortSpacing.xs),
                          Text(
                            'Protocol ID: ${_saveSuccessResult!.protocolId}',
                            style: CohortTextStyles.small,
                          ),
                          Text(
                            'Steps saved: ${_saveSuccessResult!.stepCount}',
                            style: CohortTextStyles.small,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CohortSpacing.lg),
                  ],
                  if (_saveErrorMessage != null) ...[
                    CohortCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Save failed',
                            style: CohortTextStyles.eyebrow.copyWith(
                              color: CohortColors.danger,
                            ),
                          ),
                          const SizedBox(height: CohortSpacing.sm),
                          Text(
                            _saveErrorMessage!,
                            style: CohortTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CohortSpacing.lg),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CohortButton(
                              label: _isSaving
                                  ? 'Saving...'
                                  : _isPublished
                                      ? 'Save Changes'
                                      : 'Save Draft',
                              onPressed: _isBusy
                                  ? () {}
                                  : _isPublished
                                      ? _savePublishedChanges
                                      : _saveDraft,
                            ),
                            if (_isSaving)
                              const Positioned(
                                right: CohortSpacing.lg,
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: CohortColors.background,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: CohortSpacing.md),
                      Expanded(
                        child: CohortButton(
                          label: 'Preview',
                          onPressed: _isBusy ? () {} : _previewDraft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: CohortSpacing.md),
                  if (_isPublished)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CohortButton(
                          label: _isUnpublishing
                              ? 'Unpublishing...'
                              : 'Unpublish',
                          onPressed: _isBusy ? () {} : _unpublishDraft,
                        ),
                        if (_isUnpublishing)
                          const Positioned(
                            right: CohortSpacing.lg,
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CohortColors.background,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CohortButton(
                          label: _isPublishing ? 'Publishing...' : 'Publish',
                          onPressed: _isBusy ? () {} : _publishDraft,
                        ),
                        if (_isPublishing)
                          const Positioned(
                            right: CohortSpacing.lg,
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CohortColors.background,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
