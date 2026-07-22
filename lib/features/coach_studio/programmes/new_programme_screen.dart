import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/authenticated_identity.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/section_title.dart';
import '../../../models/programme_vocabulary.dart';
import '../../programme_builder/models/programme_seed_template.dart';
import '../../programme_builder/models/programme_version_draft_metadata.dart';
import 'controllers/programme_catalogue_controller.dart';
import 'programme_editor_screen.dart';
import 'utils/programme_lineage_code_suggester.dart';

class NewProgrammeScreen extends StatefulWidget {
  const NewProgrammeScreen({
    super.key,
    required this.controller,
  });

  final ProgrammeCatalogueController controller;

  @override
  State<NewProgrammeScreen> createState() => _NewProgrammeScreenState();
}

class _NewProgrammeScreenState extends State<NewProgrammeScreen> {
  final _nameController = TextEditingController();
  final _lineageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _goalController = TextEditingController();

  ProgrammeLibraryScope _libraryScope = ProgrammeLibraryScope.coachPrivate;
  ProgrammeSeedTemplate _seedTemplate = ProgrammeSeedTemplate.empty;
  bool _submitting = false;
  String? _errorMessage;
  String? _debugDetail;

  @override
  void dispose() {
    _nameController.dispose();
    _lineageController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (_lineageController.text.trim().isEmpty) {
      _lineageController.text = suggestLineageCode(value);
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final lineageCode = _lineageController.text.trim();

    if (name.isEmpty || lineageCode.isEmpty) {
      setState(() => _errorMessage = 'Name and lineage code are required.');
      return;
    }

    debugPrint('[ProgrammeCreate] submit tapped');
    debugPrint('[ProgrammeCreate] name=$name');
    debugPrint('[ProgrammeCreate] lineage=$lineageCode');
    debugPrint('[ProgrammeCreate] seedTemplate=${_seedTemplate.name}');

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _debugDetail = null;
    });

    final durationWeeks = int.tryParse(_durationController.text.trim());
    final metadata = ProgrammeVersionDraftMetadata(
      lineageCode: lineageCode,
      versionNumber: 1,
      name: name,
      description: _nullable(_descriptionController.text),
      libraryScope: _libraryScope,
      ownerType: ProgrammeOwnerType.coach,
      ownerId: AuthenticatedIdentity.requireCoachId(),
      durationWeeks: durationWeeks,
      primaryGoal: _nullable(_goalController.text),
    );

    final result = await widget.controller.createProgramme(
      metadata: metadata,
      seedTemplate: _seedTemplate,
    );

    debugPrint(
      '[ProgrammeCreate] catalogue result '
      'success=${result.success} '
      'versionId=${result.versionId} '
      'message=${result.message} '
      'warnings=${result.warnings} '
      'debugDetail=${result.debugDetail}',
    );

    if (!mounted) return;

    setState(() => _submitting = false);

    if (!result.success || result.versionId == null) {
      setState(() {
        _errorMessage = result.message ?? 'Could not create programme.';
        _debugDetail = result.debugDetail;
      });

      if (kDebugMode && result.debugDetail != null) {
        _showDebugFailureDetail(
          userMessage: _errorMessage!,
          debugDetail: result.debugDetail!,
        );
      }
      return;
    }

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ProgrammeEditorScreen(
          versionId: result.versionId!,
        ),
      ),
    );
  }

  void _showDebugFailureDetail({
    required String userMessage,
    required String debugDetail,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(userMessage),
              const SizedBox(height: CohortSpacing.sm),
              Text(
                debugDetail,
                style: CohortTextStyles.small.copyWith(
                  color: CohortColors.textPrimary,
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'Details',
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Create programme failed (debug)'),
                  content: SingleChildScrollView(
                    child: SelectableText(debugDetail),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    });
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: const Text('← Back'),
              ),
              const SizedBox(height: CohortSpacing.md),
              const SectionTitle('Coach Studio'),
              const SizedBox(height: CohortSpacing.md),
              const Text('New Programme', style: CohortTextStyles.h1),
              const SizedBox(height: CohortSpacing.xl),
              Expanded(
                child: ListView(
                  children: [
                    _field('Programme name', _nameController, onChanged: _onNameChanged),
                    const SizedBox(height: CohortSpacing.md),
                    _field('Lineage code', _lineageController),
                    const SizedBox(height: CohortSpacing.md),
                    _field('Description (optional)', _descriptionController, maxLines: 3),
                    const SizedBox(height: CohortSpacing.md),
                    DropdownButtonFormField<ProgrammeLibraryScope>(
                      value: _libraryScope,
                      decoration: const InputDecoration(labelText: 'Library scope'),
                      items: ProgrammeLibraryScope.values
                          .map(
                            (scope) => DropdownMenuItem(
                              value: scope,
                              child: Text(scope.displayLabel),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setState(() => _libraryScope = value);
                            },
                    ),
                    const SizedBox(height: CohortSpacing.md),
                    _field('Duration weeks (optional)', _durationController),
                    const SizedBox(height: CohortSpacing.md),
                    _field('Primary goal (optional)', _goalController),
                    const SizedBox(height: CohortSpacing.lg),
                    Text('Starting template', style: CohortTextStyles.body),
                    const SizedBox(height: CohortSpacing.sm),
                    ...ProgrammeSeedTemplate.values.map((template) {
                      return RadioListTile<ProgrammeSeedTemplate>(
                        value: template,
                        groupValue: _seedTemplate,
                        onChanged: _submitting
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _seedTemplate = value);
                              },
                        title: Text(template.label),
                        subtitle: Text(template.description),
                      );
                    }),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: CohortSpacing.md),
                      Text(
                        _errorMessage!,
                        style: CohortTextStyles.body.copyWith(color: CohortColors.danger),
                      ),
                      if (kDebugMode && _debugDetail != null) ...[
                        const SizedBox(height: CohortSpacing.sm),
                        ExpansionTile(
                          title: Text(
                            'Debug error detail',
                            style: CohortTextStyles.small,
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(CohortSpacing.sm),
                              child: SelectableText(
                                _debugDetail!,
                                style: CohortTextStyles.small,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: CohortSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Creating…' : 'Create programme'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enabled: !_submitting,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
}
