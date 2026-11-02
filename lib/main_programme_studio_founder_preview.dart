import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'features/programme_studio/composition/programme_first_screen.dart';
import 'features/programme_studio/genuine_authoring/genuine_workspace.dart';
import 'features/programme_studio/genuine_authoring/genuine_workspace_screen.dart';

/// Dedicated local web Studio entry. No Supabase/auth/athlete composition.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(theme: cohortTheme, home: const _FounderStudio()));
}

class _FounderStudio extends StatefulWidget {
  const _FounderStudio();
  @override
  State<_FounderStudio> createState() => _FounderStudioState();
}

class _FounderStudioState extends State<_FounderStudio> {
  GenuineWorkspace? workspace;
  Object? error;
  @override
  void initState() {
    super.initState();
    GenuineWorkspace.load().then(
      (value) {
        if (mounted) {
          setState(() => workspace = value);
        } else {
          value.dispose();
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => error = e);
      },
    );
  }

  @override
  Widget build(BuildContext context) => workspace == null
      ? Scaffold(
          body: Center(
            child: Text(
              error == null
                  ? 'Opening genuine selected source…'
                  : 'Cannot open selected source: $error',
            ),
          ),
        )
      : ProgrammeFirstScreen.sourcePolicy(
          workspace: GenuineWorkspaceScreen(
            key: ObjectKey(workspace),
            controller: workspace!,
            replace: (candidate) {
              final old = workspace!;
              setState(() => workspace = candidate);
              old.dispose();
            },
          ),
        );
  @override
  void dispose() {
    workspace?.dispose();
    super.dispose();
  }
}
