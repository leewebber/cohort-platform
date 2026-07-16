import 'package:flutter/material.dart';

import '../../../../core/theme/colors.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../programme_builder/models/programme_validation_result.dart';
import '../controllers/programme_editor_controller.dart';

Future<void> showProgrammeEditorValidationSheet({
  required BuildContext context,
  required ProgrammeEditorController controller,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) =>
        ProgrammeEditorValidationSheet(controller: controller),
  );
}

class ProgrammeEditorValidationSheet extends StatelessWidget {
  const ProgrammeEditorValidationSheet({
    super.key,
    required this.controller,
  });

  final ProgrammeEditorController controller;

  @override
  Widget build(BuildContext context) {
    final issues = controller.validation?.issues ?? const [];

    final errors = issues
        .where((issue) => issue.severity == ProgrammeValidationSeverity.error)
        .toList();
    final warnings = issues
        .where((issue) => issue.severity == ProgrammeValidationSeverity.warning)
        .toList();
    final info = issues
        .where((issue) => issue.severity == ProgrammeValidationSeverity.info)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(CohortSpacing.lg),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Validation', style: CohortTextStyles.h2),
          const SizedBox(height: CohortSpacing.md),
          if (issues.isEmpty)
            Text('No issues found.', style: CohortTextStyles.body)
          else ...[
            if (errors.isNotEmpty) ...[
              Text('Errors', style: CohortTextStyles.cardTitle),
              ...errors.map((issue) => _IssueTile(
                    issue: issue,
                    color: CohortColors.danger,
                    onTap: issue.path == null
                        ? null
                        : () {
                            controller.selectPath(issue.path!);
                            Navigator.pop(context);
                          },
                  )),
            ],
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.md),
              Text('Warnings', style: CohortTextStyles.cardTitle),
              ...warnings.map((issue) => _IssueTile(
                    issue: issue,
                    color: CohortColors.warning,
                    onTap: issue.path == null
                        ? null
                        : () {
                            controller.selectPath(issue.path!);
                            Navigator.pop(context);
                          },
                  )),
            ],
            if (info.isNotEmpty) ...[
              const SizedBox(height: CohortSpacing.md),
              Text('Info', style: CohortTextStyles.cardTitle),
              ...info.map((issue) => _IssueTile(
                    issue: issue,
                    color: CohortColors.textMuted,
                    onTap: issue.path == null
                        ? null
                        : () {
                            controller.selectPath(issue.path!);
                            Navigator.pop(context);
                          },
                  )),
            ],
          ],
        ],
      ),
    );
  }
}

class _IssueTile extends StatelessWidget {
  const _IssueTile({
    required this.issue,
    required this.color,
    this.onTap,
  });

  final ProgrammeValidationIssue issue;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.circle, size: 10, color: color),
      title: Text(issue.message, style: CohortTextStyles.body),
      subtitle: Text(issue.code.name, style: CohortTextStyles.small),
      onTap: onTap,
    );
  }
}
