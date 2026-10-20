import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/theme.dart';
import 'features/programme_studio/apollo_pilot/apollo_pilot.dart';
import 'features/programme_studio/apollo_pilot/apollo_pilot_pin.dart';
import 'features/programme_studio/apollo_pilot/apollo_pilot_screen.dart';

/// Dedicated internal pilot; never imported by the production entry.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(theme: cohortTheme, home: const _LoadPilot()));
}

class _LoadPilot extends StatefulWidget {
  const _LoadPilot();
  @override
  State<_LoadPilot> createState() => _LoadPilotState();
}

class _LoadPilotState extends State<_LoadPilot> {
  ApolloPilotController? _controller;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final files = <String, String>{};
      for (final path in ApolloPilotPin.files.keys) {
        files[path] = await rootBundle.loadString(path);
      }
      final source = ApolloPilotSource.read(files);
      if (mounted) setState(() => _controller = ApolloPilotController(source));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The exact Apollo source/profile is unavailable. No local workspace was installed.',
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _controller == null
      ? Scaffold(
          body: Center(
            child: Text(_error ?? 'Validating retained Apollo source…'),
          ),
        )
      : ApolloPilotScreen(controller: _controller!);
}
