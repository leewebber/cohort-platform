import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/text_styles.dart';
import '../../programme_builder/models/programme_builder_preview.dart';
import 'services/programme_editor_services.dart';
import 'widgets/programme_preview_athlete_card.dart';
import 'widgets/programme_preview_structure_view.dart';

class ProgrammeCataloguePreviewLoader extends StatefulWidget {
  const ProgrammeCataloguePreviewLoader({
    super.key,
    required this.versionId,
  });

  final String versionId;

  @override
  State<ProgrammeCataloguePreviewLoader> createState() =>
      _ProgrammeCataloguePreviewLoaderState();
}

class _ProgrammeCataloguePreviewLoaderState
    extends State<ProgrammeCataloguePreviewLoader> {
  ProgrammeBuilderPreview? _preview;
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final builder = ProgrammeEditorServices.createBuilderService();
      final previewService = ProgrammeEditorServices.createPreviewService();
      final nameResolver = ProgrammeEditorServices.createProtocolNameResolver();

      final document = await builder.loadDocument(versionId: widget.versionId);
      final names = await nameResolver.resolveNames(
        document.template.allWeeks
            .expand((week) => week.days)
            .expand((day) => day.slots)
            .map((slot) => slot.protocolId.trim())
            .where((id) => id.isNotEmpty)
            .toSet(),
      );
      final preview = await previewService.buildPreview(
        document,
        protocolNamesById: names,
      );

      if (!mounted) return;
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load preview.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_preview == null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CohortSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('← Back'),
                ),
                Text(_errorMessage ?? 'Preview unavailable.',
                    style: CohortTextStyles.body),
              ],
            ),
          ),
        ),
      );
    }

    return ProgrammePreviewScreen(preview: _preview!);
  }
}


class ProgrammePreviewScreen extends StatefulWidget {
  const ProgrammePreviewScreen({
    super.key,
    required this.preview,
    this.hasUnsavedChanges = false,
  });

  final ProgrammeBuilderPreview preview;
  final bool hasUnsavedChanges;

  @override
  State<ProgrammePreviewScreen> createState() => _ProgrammePreviewScreenState();
}

class _ProgrammePreviewScreenState extends State<ProgrammePreviewScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(CohortSpacing.lg),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('← Back'),
                  ),
                  const SizedBox(width: CohortSpacing.md),
                  Text('Programme preview', style: CohortTextStyles.h2),
                ],
              ),
            ),
            if (widget.hasUnsavedChanges)
              Container(
                width: double.infinity,
                color: CohortColors.oliveSoft,
                padding: const EdgeInsets.all(CohortSpacing.sm),
                child: Text(
                  'Preview reflects unsaved changes.',
                  style: CohortTextStyles.small,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CohortSpacing.lg),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Structure')),
                  ButtonSegment(value: 1, label: Text('Athlete view')),
                ],
                selected: {_tabIndex},
                onSelectionChanged: (selection) {
                  setState(() => _tabIndex = selection.first);
                },
              ),
            ),
            const SizedBox(height: CohortSpacing.md),
            Expanded(
              child: _tabIndex == 0
                  ? ProgrammePreviewStructureView(preview: widget.preview)
                  : ProgrammePreviewAthleteCard(preview: widget.preview),
            ),
          ],
        ),
      ),
    );
  }
}
