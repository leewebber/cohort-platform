import 'package:flutter/material.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../features/auth/screens/auth_gate.dart';
import 'configuration_error_screen.dart';
import 'theme.dart';

class CohortPlatformApp extends StatefulWidget {
  const CohortPlatformApp({
    super.key,
    this.configurationError,
    this.authController,
  });

  final String? configurationError;
  final AuthController? authController;

  @override
  State<CohortPlatformApp> createState() => _CohortPlatformAppState();
}

class _CohortPlatformAppState extends State<CohortPlatformApp> {
  AuthController? _authController;

  @override
  void initState() {
    super.initState();
    if (widget.configurationError == null) {
      _authController = widget.authController ?? AuthController();
    }
  }

  @override
  void dispose() {
    _authController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cohort Platform',
      debugShowCheckedModeBanner: false,
      theme: cohortTheme,
      home: widget.configurationError == null
          ? AuthGate(controller: _authController!)
          : ConfigurationErrorScreen(message: widget.configurationError!),
    );
  }
}
