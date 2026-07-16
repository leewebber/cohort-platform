import 'package:flutter/material.dart';

enum ProgrammeEditorUnsavedAction {
  saveAndExit,
  discard,
  cancel,
}

Future<ProgrammeEditorUnsavedAction?> showProgrammeEditorUnsavedDialog({
  required BuildContext context,
}) {
  return showDialog<ProgrammeEditorUnsavedAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Unsaved changes'),
      content: const Text(
        'You have unsaved changes. Save before leaving?',
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(context, ProgrammeEditorUnsavedAction.cancel),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, ProgrammeEditorUnsavedAction.discard),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, ProgrammeEditorUnsavedAction.saveAndExit),
          child: const Text('Save and exit'),
        ),
      ],
    ),
  );
}
