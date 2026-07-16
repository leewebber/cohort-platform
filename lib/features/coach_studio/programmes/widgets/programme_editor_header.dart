import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../models/programme_vocabulary.dart';
import '../../../programme_builder/models/programme_builder_document.dart';
import '../controllers/programme_editor_controller.dart';

class ProgrammeEditorHeader extends StatelessWidget {
  const ProgrammeEditorHeader({
    super.key,
    required this.controller,
    required this.onBack,
    required this.onOpenMetadata,
    required this.onSave,
    required this.onValidate,
    required this.onPreview,
    required this.onPublish,
  });

  final ProgrammeEditorController controller;
  final VoidCallback onBack;
  final VoidCallback onOpenMetadata;
  final Future<void> Function() onSave;
  final VoidCallback onValidate;
  final VoidCallback onPreview;
  final Future<void> Function() onPublish;

  @override
  Widget build(BuildContext context) {
    final document = controller.document;
    if (document == null) return const SizedBox.shrink();

    final status = document.metadata.lifecycleStatus;
    final statusLabel = status == ProgrammeLifecycleStatus.draft
        ? 'DRAFT v${document.metadata.versionNumber}'
        : '${status.name.toUpperCase()} v${document.metadata.versionNumber}';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: CohortSpacing.lg,
        vertical: CohortSpacing.md,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CohortColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TextButton(onPressed: onBack, child: const Text('← Catalogue')),
              const SizedBox(width: CohortSpacing.md),
              Expanded(
                child: InkWell(
                  onTap: onOpenMetadata,
                  child: Text(
                    document.metadata.name,
                    style: CohortTextStyles.h2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: CohortSpacing.sm),
              _Badge(label: statusLabel),
              if (controller.hasUnsavedChanges) ...[
                const SizedBox(width: CohortSpacing.sm),
                Text(
                  '● Unsaved',
                  style: CohortTextStyles.small.copyWith(
                    color: CohortColors.warning,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: CohortSpacing.sm),
          Wrap(
            spacing: CohortSpacing.sm,
            runSpacing: CohortSpacing.sm,
            children: [
              OutlinedButton(
                onPressed: controller.canUndo ? controller.undo : null,
                child: const Text('Undo'),
              ),
              OutlinedButton(
                onPressed: controller.canRedo ? controller.redo : null,
                child: const Text('Redo'),
              ),
              FilledButton(
                onPressed: controller.isSaving || controller.isReadOnly
                    ? null
                    : onSave,
                child: Text(controller.isSaving ? 'Saving…' : 'Save'),
              ),
              OutlinedButton(
                onPressed: onValidate,
                child: const Text('Validate'),
              ),
              OutlinedButton(
                onPressed: onPreview,
                child: const Text('Preview'),
              ),
              FilledButton(
                onPressed: controller.canPublish ? onPublish : null,
                child: const Text('Publish'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CohortColors.oliveSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: CohortColors.olive),
      ),
      child: Text(
        label,
        style: CohortTextStyles.small.copyWith(color: CohortColors.olive),
      ),
    );
  }
}
